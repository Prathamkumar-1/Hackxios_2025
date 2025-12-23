// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                         PAYFLOW PROTOCOL                                       ║
 * ║              Programmable Money Rails for Institutional Payments              ║
 * ╠═══════════════════════════════════════════════════════════════════════════════╣
 * ║  "What if money could carry its own rules?"                                   ║
 * ║                                                                               ║
 * ║  PayFlow transforms institutional payments by embedding programmable          ║
 * ║  conditions directly into payment flows. Every transfer can carry:            ║
 * ║  • Compliance requirements (KYC/AML/Sanctions)                                ║
 * ║  • Time restrictions (business hours, settlement windows)                     ║
 * ║  • Multi-signature approval thresholds                                        ║
 * ║  • Automatic FX conversion at oracle-verified rates                           ║
 * ║  • Escrow conditions with automatic release                                   ║
 * ║  • Immutable audit trails for regulatory compliance                           ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 */

/**
 * @title PayFlowCore
 * @notice The central routing engine for programmable institutional payments
 * @dev Handles payment creation, condition verification, and execution
 */
contract PayFlowCore is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════════════
    //                              ROLES
    // ═══════════════════════════════════════════════════════════════════════════
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // ═══════════════════════════════════════════════════════════════════════════
    //                              TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    enum PaymentStatus {
        CREATED,        // Payment initiated, awaiting conditions
        PENDING,        // Conditions being verified
        APPROVED,       // All conditions met, ready to execute
        EXECUTED,       // Payment completed successfully
        FAILED,         // Payment failed (conditions not met)
        CANCELLED,      // Payment cancelled by sender
        DISPUTED        // Under dispute resolution
    }

    enum ComplianceTier {
        NONE,           // No KYC required (small amounts only)
        BASIC,          // Email + Phone verification
        STANDARD,       // Government ID + Address
        ENHANCED,       // Full KYC + Source of funds
        INSTITUTIONAL   // Corporate KYC + Ultimate beneficial owner
    }

    struct PaymentConditions {
        // Compliance
        ComplianceTier requiredSenderTier;
        ComplianceTier requiredRecipientTier;
        bool requireSanctionsCheck;
        
        // Time restrictions
        uint256 validFrom;          // Earliest execution time
        uint256 validUntil;         // Latest execution time (0 = no expiry)
        bool businessHoursOnly;     // Only execute during business hours
        
        // Amount controls
        uint256 maxSlippage;        // Max FX slippage in basis points
        
        // Multi-sig (0 = no approval required)
        uint256 requiredApprovals;
        address[] approvers;
        
        // Escrow
        bool useEscrow;
        uint256 escrowReleaseTime;  // Auto-release after this time
        bytes32 escrowConditionHash; // Hash of external condition
    }

    struct Payment {
        // Core payment data
        bytes32 paymentId;
        address sender;
        address recipient;
        address token;
        uint256 amount;
        
        // For cross-border
        address targetToken;        // If different from token, triggers FX
        uint256 targetAmount;       // Expected amount after FX (0 = market rate)
        
        // Status
        PaymentStatus status;
        uint256 createdAt;
        uint256 executedAt;
        
        // Conditions
        PaymentConditions conditions;
        
        // Approvals
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        
        // Metadata
        bytes32 referenceId;        // External reference
        string memo;
    }

    struct PaymentView {
        bytes32 paymentId;
        address sender;
        address recipient;
        address token;
        uint256 amount;
        address targetToken;
        uint256 targetAmount;
        PaymentStatus status;
        uint256 createdAt;
        uint256 executedAt;
        uint256 approvalCount;
        uint256 requiredApprovals;
        bytes32 referenceId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                              STATE
    // ═══════════════════════════════════════════════════════════════════════════

    // Payment storage
    mapping(bytes32 => Payment) private payments;
    bytes32[] public paymentIds;
    
    // User payment tracking
    mapping(address => bytes32[]) public userPaymentsSent;
    mapping(address => bytes32[]) public userPaymentsReceived;
    
    // Supported tokens
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    
    // Module addresses
    address public complianceEngine;
    address public oracleAggregator;
    address public escrowVault;
    address public auditRegistry;
    
    // Protocol settings
    uint256 public protocolFeeBps = 10; // 0.1% default fee
    address public feeRecipient;
    uint256 public maxPaymentAmount = 100_000_000 * 1e6; // $100M default max
    
    // Statistics
    uint256 public totalPaymentsCreated;
    uint256 public totalPaymentsExecuted;
    uint256 public totalVolumeProcessed;
    uint256 public averageSettlementTime;

    // ═══════════════════════════════════════════════════════════════════════════
    //                              EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event PaymentCreated(
        bytes32 indexed paymentId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amount,
        bytes32 referenceId
    );
    
    event PaymentApproved(
        bytes32 indexed paymentId,
        address indexed approver,
        uint256 approvalCount,
        uint256 requiredApprovals
    );
    
    event PaymentExecuted(
        bytes32 indexed paymentId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 settlementTime
    );
    
    event PaymentFailed(
        bytes32 indexed paymentId,
        string reason
    );
    
    event PaymentCancelled(
        bytes32 indexed paymentId,
        address indexed cancelledBy
    );
    
    event CrossBorderSettlement(
        bytes32 indexed paymentId,
        address sourceToken,
        address targetToken,
        uint256 sourceAmount,
        uint256 targetAmount,
        uint256 fxRate
    );
    
    event ComplianceVerified(
        bytes32 indexed paymentId,
        address indexed party,
        ComplianceTier tier,
        bool sanctionsCleared
    );

    // ═══════════════════════════════════════════════════════════════════════════
    //                              CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
        feeRecipient = msg.sender;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PAYMENT CREATION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Create a new programmable payment
     * @param recipient The payment recipient
     * @param token The token to send
     * @param amount The amount to send
     * @param conditions The programmable conditions for this payment
     * @param referenceId External reference ID for tracking
     * @param memo Human-readable memo
     * @return paymentId The unique payment identifier
     */
    function createPayment(
        address recipient,
        address token,
        uint256 amount,
        PaymentConditions calldata conditions,
        bytes32 referenceId,
        string calldata memo
    ) external nonReentrant whenNotPaused returns (bytes32 paymentId) {
        require(recipient != address(0), "Invalid recipient");
        require(recipient != msg.sender, "Cannot pay yourself");
        require(amount > 0, "Amount must be positive");
        require(amount <= maxPaymentAmount, "Exceeds max payment");
        require(supportedTokens[token], "Token not supported");
        
        // Generate unique payment ID
        paymentId = keccak256(abi.encodePacked(
            msg.sender,
            recipient,
            token,
            amount,
            block.timestamp,
            totalPaymentsCreated
        ));
        
        // Store payment
        Payment storage payment = payments[paymentId];
        payment.paymentId = paymentId;
        payment.sender = msg.sender;
        payment.recipient = recipient;
        payment.token = token;
        payment.amount = amount;
        payment.targetToken = token; // Same token by default
        payment.status = PaymentStatus.CREATED;
        payment.createdAt = block.timestamp;
        payment.conditions = conditions;
        payment.referenceId = referenceId;
        payment.memo = memo;
        
        // Copy approvers array
        for (uint i = 0; i < conditions.approvers.length; i++) {
            payment.conditions.approvers.push(conditions.approvers[i]);
        }
        
        // Transfer tokens to protocol
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Track
        paymentIds.push(paymentId);
        userPaymentsSent[msg.sender].push(paymentId);
        userPaymentsReceived[recipient].push(paymentId);
        totalPaymentsCreated++;
        
        emit PaymentCreated(paymentId, msg.sender, recipient, token, amount, referenceId);
        
        // Auto-process if no conditions
        if (_canAutoExecute(payment)) {
            _executePayment(paymentId);
        } else {
            payment.status = PaymentStatus.PENDING;
        }
        
        return paymentId;
    }

    /**
     * @notice Create a cross-border payment with FX conversion
     */
    function createCrossBorderPayment(
        address recipient,
        address sourceToken,
        uint256 sourceAmount,
        address targetToken,
        uint256 minTargetAmount,
        PaymentConditions calldata conditions,
        bytes32 referenceId,
        string calldata memo
    ) external nonReentrant whenNotPaused returns (bytes32 paymentId) {
        require(recipient != address(0), "Invalid recipient");
        require(sourceAmount > 0, "Amount must be positive");
        require(supportedTokens[sourceToken], "Source token not supported");
        require(supportedTokens[targetToken], "Target token not supported");
        
        paymentId = keccak256(abi.encodePacked(
            msg.sender,
            recipient,
            sourceToken,
            targetToken,
            sourceAmount,
            block.timestamp,
            totalPaymentsCreated
        ));
        
        Payment storage payment = payments[paymentId];
        payment.paymentId = paymentId;
        payment.sender = msg.sender;
        payment.recipient = recipient;
        payment.token = sourceToken;
        payment.amount = sourceAmount;
        payment.targetToken = targetToken;
        payment.targetAmount = minTargetAmount;
        payment.status = PaymentStatus.PENDING;
        payment.createdAt = block.timestamp;
        payment.conditions = conditions;
        payment.referenceId = referenceId;
        payment.memo = memo;
        
        IERC20(sourceToken).safeTransferFrom(msg.sender, address(this), sourceAmount);
        
        paymentIds.push(paymentId);
        userPaymentsSent[msg.sender].push(paymentId);
        userPaymentsReceived[recipient].push(paymentId);
        totalPaymentsCreated++;
        
        emit PaymentCreated(paymentId, msg.sender, recipient, sourceToken, sourceAmount, referenceId);
        
        return paymentId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PAYMENT APPROVAL
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Approve a payment (for multi-sig payments)
     */
    function approvePayment(bytes32 paymentId) external nonReentrant {
        Payment storage payment = payments[paymentId];
        require(payment.paymentId == paymentId, "Payment not found");
        require(payment.status == PaymentStatus.PENDING, "Not pending approval");
        require(!payment.hasApproved[msg.sender], "Already approved");
        require(_isApprover(payment, msg.sender), "Not an approver");
        
        payment.hasApproved[msg.sender] = true;
        payment.approvalCount++;
        
        emit PaymentApproved(
            paymentId, 
            msg.sender, 
            payment.approvalCount, 
            payment.conditions.requiredApprovals
        );
        
        // Check if ready to execute
        if (_allConditionsMet(payment)) {
            _executePayment(paymentId);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PAYMENT EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Execute a payment that has met all conditions
     */
    function executePayment(bytes32 paymentId) external nonReentrant {
        Payment storage payment = payments[paymentId];
        require(payment.paymentId == paymentId, "Payment not found");
        require(
            payment.status == PaymentStatus.PENDING || 
            payment.status == PaymentStatus.APPROVED,
            "Cannot execute"
        );
        require(_allConditionsMet(payment), "Conditions not met");
        
        _executePayment(paymentId);
    }

    function _executePayment(bytes32 paymentId) internal {
        Payment storage payment = payments[paymentId];
        
        uint256 amountToSend = payment.amount;
        
        // Deduct protocol fee
        if (protocolFeeBps > 0) {
            uint256 fee = (amountToSend * protocolFeeBps) / 10000;
            amountToSend -= fee;
            IERC20(payment.token).safeTransfer(feeRecipient, fee);
        }
        
        // Handle cross-border FX if needed
        if (payment.targetToken != payment.token) {
            // In production, this would call the oracle and DEX
            // For demo, we simulate 1:1 conversion
            amountToSend = _performFXConversion(
                payment.token,
                payment.targetToken,
                amountToSend,
                payment.targetAmount,
                payment.conditions.maxSlippage
            );
            
            emit CrossBorderSettlement(
                paymentId,
                payment.token,
                payment.targetToken,
                payment.amount,
                amountToSend,
                1e18 // Simulated 1:1 rate
            );
        }
        
        // Transfer to recipient
        if (payment.conditions.useEscrow) {
            // Send to escrow vault
            IERC20(payment.targetToken).safeTransfer(escrowVault, amountToSend);
        } else {
            // Direct transfer
            IERC20(payment.targetToken).safeTransfer(payment.recipient, amountToSend);
        }
        
        // Update state
        payment.status = PaymentStatus.EXECUTED;
        payment.executedAt = block.timestamp;
        
        uint256 settlementTime = payment.executedAt - payment.createdAt;
        totalPaymentsExecuted++;
        totalVolumeProcessed += payment.amount;
        
        // Update average settlement time
        averageSettlementTime = (averageSettlementTime * (totalPaymentsExecuted - 1) + settlementTime) / totalPaymentsExecuted;
        
        // Log to audit registry
        if (auditRegistry != address(0)) {
            IAuditRegistry(auditRegistry).logPaymentExecution(
                paymentId,
                payment.sender,
                payment.recipient,
                payment.amount,
                settlementTime
            );
        }
        
        emit PaymentExecuted(
            paymentId,
            payment.sender,
            payment.recipient,
            amountToSend,
            settlementTime
        );
    }

    function _performFXConversion(
        address, // sourceToken
        address targetToken,
        uint256 sourceAmount,
        uint256, // minTargetAmount
        uint256 // maxSlippage
    ) internal view returns (uint256) {
        // In production: Call oracle for rate, execute swap through DEX
        // For hackathon demo: Simulate 1:1 stablecoin conversion
        
        // Verify we have enough target tokens (would come from liquidity pool)
        uint256 balance = IERC20(targetToken).balanceOf(address(this));
        require(balance >= sourceAmount, "Insufficient liquidity");
        
        return sourceAmount;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PAYMENT CANCELLATION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Cancel a pending payment
     */
    function cancelPayment(bytes32 paymentId) external nonReentrant {
        Payment storage payment = payments[paymentId];
        require(payment.paymentId == paymentId, "Payment not found");
        require(payment.sender == msg.sender, "Not the sender");
        require(
            payment.status == PaymentStatus.CREATED || 
            payment.status == PaymentStatus.PENDING,
            "Cannot cancel"
        );
        
        // Refund
        IERC20(payment.token).safeTransfer(payment.sender, payment.amount);
        
        payment.status = PaymentStatus.CANCELLED;
        
        emit PaymentCancelled(paymentId, msg.sender);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         CONDITION CHECKING
    // ═══════════════════════════════════════════════════════════════════════════

    function _canAutoExecute(Payment storage payment) internal view returns (bool) {
        PaymentConditions storage c = payment.conditions;
        
        // No conditions = auto execute
        if (
            c.requiredSenderTier == ComplianceTier.NONE &&
            c.requiredRecipientTier == ComplianceTier.NONE &&
            !c.requireSanctionsCheck &&
            c.validFrom == 0 &&
            c.validUntil == 0 &&
            !c.businessHoursOnly &&
            c.requiredApprovals == 0 &&
            !c.useEscrow
        ) {
            return true;
        }
        return false;
    }

    function _allConditionsMet(Payment storage payment) internal view returns (bool) {
        PaymentConditions storage c = payment.conditions;
        
        // Time checks
        if (c.validFrom > 0 && block.timestamp < c.validFrom) return false;
        if (c.validUntil > 0 && block.timestamp > c.validUntil) return false;
        
        // Approval checks
        if (c.requiredApprovals > 0 && payment.approvalCount < c.requiredApprovals) {
            return false;
        }
        
        // In production: Check compliance engine for KYC/AML status
        // For demo: Always passes
        
        return true;
    }

    function _isApprover(Payment storage payment, address account) internal view returns (bool) {
        for (uint i = 0; i < payment.conditions.approvers.length; i++) {
            if (payment.conditions.approvers[i] == account) return true;
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    function getPayment(bytes32 paymentId) external view returns (PaymentView memory) {
        Payment storage payment = payments[paymentId];
        return PaymentView({
            paymentId: payment.paymentId,
            sender: payment.sender,
            recipient: payment.recipient,
            token: payment.token,
            amount: payment.amount,
            targetToken: payment.targetToken,
            targetAmount: payment.targetAmount,
            status: payment.status,
            createdAt: payment.createdAt,
            executedAt: payment.executedAt,
            approvalCount: payment.approvalCount,
            requiredApprovals: payment.conditions.requiredApprovals,
            referenceId: payment.referenceId
        });
    }

    function getPaymentCount() external view returns (uint256) {
        return paymentIds.length;
    }

    function getProtocolStats() external view returns (
        uint256 created,
        uint256 executed,
        uint256 volume,
        uint256 avgSettlement
    ) {
        return (
            totalPaymentsCreated,
            totalPaymentsExecuted,
            totalVolumeProcessed,
            averageSettlementTime
        );
    }

    function getUserPayments(address user) external view returns (
        bytes32[] memory sent,
        bytes32[] memory received
    ) {
        return (userPaymentsSent[user], userPaymentsReceived[user]);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    function addSupportedToken(address token) external onlyRole(OPERATOR_ROLE) {
        require(!supportedTokens[token], "Already supported");
        supportedTokens[token] = true;
        tokenList.push(token);
    }

    function setModules(
        address _compliance,
        address _oracle,
        address _escrow,
        address _audit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        complianceEngine = _compliance;
        oracleAggregator = _oracle;
        escrowVault = _escrow;
        auditRegistry = _audit;
    }

    function setProtocolFee(uint256 _feeBps) external onlyRole(TREASURY_ROLE) {
        require(_feeBps <= 100, "Fee too high"); // Max 1%
        protocolFeeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyRole(TREASURY_ROLE) {
        require(_recipient != address(0), "Invalid recipient");
        feeRecipient = _recipient;
    }

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//                         INTERFACES
// ═══════════════════════════════════════════════════════════════════════════

interface IAuditRegistry {
    function logPaymentExecution(
        bytes32 paymentId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 settlementTime
    ) external;
}
