// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ComplianceEngine
 * @notice Programmable KYC/AML/Sanctions compliance for institutional payments
 * @dev Implements tiered verification with real-time sanctions checking
 * 
 * KEY FEATURES:
 * - Multi-tier KYC levels (None → Institutional)
 * - OFAC/EU/UN sanctions list checking
 * - Travel Rule compliance for >$3000 transfers
 * - Jurisdiction-based restrictions
 * - Automated compliance reporting
 */
contract ComplianceEngine is AccessControl, ReentrancyGuard {
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");
    bytes32 public constant KYC_VERIFIER = keccak256("KYC_VERIFIER");
    bytes32 public constant SANCTIONS_UPDATER = keccak256("SANCTIONS_UPDATER");

    // Compliance tiers (matches PayFlowCore)
    enum ComplianceTier {
        NONE,           // Unverified
        BASIC,          // Email + phone verified
        STANDARD,       // ID document verified
        ENHANCED,       // Enhanced due diligence
        INSTITUTIONAL   // Full institutional verification
    }

    struct EntityProfile {
        address entity;
        ComplianceTier tier;
        bool isVerified;
        bool isSanctioned;
        
        // Identity
        bytes32 identityHash;       // Hash of identity documents
        string jurisdiction;        // ISO country code
        bool isPEP;                 // Politically Exposed Person
        
        // Limits
        uint256 dailyLimit;
        uint256 monthlyLimit;
        uint256 singleTxLimit;
        
        // Usage tracking
        uint256 dailyVolume;
        uint256 monthlyVolume;
        uint256 lastDayReset;
        uint256 lastMonthReset;
        
        // Verification
        uint256 verifiedAt;
        uint256 expiresAt;
        address verifiedBy;
        
        // Risk
        uint8 riskScore;            // 0-100
        bool underReview;
    }

    struct TransactionCheck {
        bool passed;
        string reason;
        bool requiresTravelRule;
        bool requiresEnhancedDD;
        uint256 timestamp;
    }

    // State
    mapping(address => EntityProfile) public profiles;
    mapping(bytes32 => bool) public sanctionsList;      // Hash of sanctioned entity
    mapping(string => bool) public restrictedJurisdictions;
    
    // Travel Rule threshold ($3000 equivalent)
    uint256 public travelRuleThreshold = 3000 * 1e18;
    
    // Tier limits in USD value (scaled by 1e18)
    mapping(ComplianceTier => uint256) public tierDailyLimits;
    mapping(ComplianceTier => uint256) public tierMonthlyLimits;
    mapping(ComplianceTier => uint256) public tierSingleTxLimits;

    // Statistics
    uint256 public totalVerifications;
    uint256 public totalChecks;
    uint256 public totalRejections;
    uint256 public sanctionsListSize;

    // Events
    event EntityVerified(
        address indexed entity,
        ComplianceTier tier,
        address verifiedBy
    );
    
    event EntitySanctioned(
        address indexed entity,
        string reason
    );
    
    event EntityCleared(
        address indexed entity
    );
    
    event TransactionChecked(
        bytes32 indexed paymentId,
        address indexed sender,
        address indexed recipient,
        bool passed,
        string reason
    );
    
    event SanctionsListUpdated(
        bytes32 indexed entityHash,
        bool sanctioned
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER, msg.sender);
        _grantRole(KYC_VERIFIER, msg.sender);
        _grantRole(SANCTIONS_UPDATER, msg.sender);
        
        // Initialize tier limits
        tierDailyLimits[ComplianceTier.NONE] = 1000 * 1e18;
        tierDailyLimits[ComplianceTier.BASIC] = 10000 * 1e18;
        tierDailyLimits[ComplianceTier.STANDARD] = 50000 * 1e18;
        tierDailyLimits[ComplianceTier.ENHANCED] = 500000 * 1e18;
        tierDailyLimits[ComplianceTier.INSTITUTIONAL] = type(uint256).max;
        
        tierMonthlyLimits[ComplianceTier.NONE] = 5000 * 1e18;
        tierMonthlyLimits[ComplianceTier.BASIC] = 50000 * 1e18;
        tierMonthlyLimits[ComplianceTier.STANDARD] = 250000 * 1e18;
        tierMonthlyLimits[ComplianceTier.ENHANCED] = 2500000 * 1e18;
        tierMonthlyLimits[ComplianceTier.INSTITUTIONAL] = type(uint256).max;
        
        tierSingleTxLimits[ComplianceTier.NONE] = 500 * 1e18;
        tierSingleTxLimits[ComplianceTier.BASIC] = 5000 * 1e18;
        tierSingleTxLimits[ComplianceTier.STANDARD] = 25000 * 1e18;
        tierSingleTxLimits[ComplianceTier.ENHANCED] = 100000 * 1e18;
        tierSingleTxLimits[ComplianceTier.INSTITUTIONAL] = type(uint256).max;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         KYC VERIFICATION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Verify an entity at a specific compliance tier
     */
    function verifyEntity(
        address entity,
        ComplianceTier tier,
        bytes32 identityHash,
        string calldata jurisdiction,
        bool isPEP,
        uint8 riskScore,
        uint256 validityPeriod
    ) external onlyRole(KYC_VERIFIER) {
        require(entity != address(0), "Invalid entity");
        require(!restrictedJurisdictions[jurisdiction], "Restricted jurisdiction");
        
        EntityProfile storage profile = profiles[entity];
        
        profile.entity = entity;
        profile.tier = tier;
        profile.isVerified = true;
        profile.identityHash = identityHash;
        profile.jurisdiction = jurisdiction;
        profile.isPEP = isPEP;
        profile.riskScore = riskScore;
        profile.verifiedAt = block.timestamp;
        profile.expiresAt = block.timestamp + validityPeriod;
        profile.verifiedBy = msg.sender;
        
        // Set limits based on tier
        profile.dailyLimit = tierDailyLimits[tier];
        profile.monthlyLimit = tierMonthlyLimits[tier];
        profile.singleTxLimit = tierSingleTxLimits[tier];
        
        totalVerifications++;
        
        emit EntityVerified(entity, tier, msg.sender);
    }

    /**
     * @notice Upgrade entity to higher tier
     */
    function upgradeEntity(
        address entity,
        ComplianceTier newTier,
        bytes32 additionalDocs
    ) external onlyRole(KYC_VERIFIER) {
        EntityProfile storage profile = profiles[entity];
        require(profile.isVerified, "Not verified");
        require(newTier > profile.tier, "Must be higher tier");
        
        profile.tier = newTier;
        profile.dailyLimit = tierDailyLimits[newTier];
        profile.monthlyLimit = tierMonthlyLimits[newTier];
        profile.singleTxLimit = tierSingleTxLimits[newTier];
        
        emit EntityVerified(entity, newTier, msg.sender);
    }

    /**
     * @notice Mark entity as sanctioned
     */
    function sanctionEntity(
        address entity,
        string calldata reason
    ) external onlyRole(COMPLIANCE_OFFICER) {
        profiles[entity].isSanctioned = true;
        profiles[entity].underReview = true;
        
        emit EntitySanctioned(entity, reason);
    }

    /**
     * @notice Remove entity from sanctions
     */
    function clearEntity(address entity) external onlyRole(COMPLIANCE_OFFICER) {
        profiles[entity].isSanctioned = false;
        profiles[entity].underReview = false;
        
        emit EntityCleared(entity);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         TRANSACTION COMPLIANCE
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Check if a payment is compliant
     * @param paymentId Unique payment identifier
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Payment amount in USD value
     * @param requireSanctionsCheck Whether to check sanctions
     * @param requiredSenderTier Minimum sender tier required
     * @param requiredRecipientTier Minimum recipient tier required
     */
    function checkPaymentCompliance(
        bytes32 paymentId,
        address sender,
        address recipient,
        uint256 amount,
        bool requireSanctionsCheck,
        ComplianceTier requiredSenderTier,
        ComplianceTier requiredRecipientTier
    ) external returns (TransactionCheck memory check) {
        totalChecks++;
        
        EntityProfile storage senderProfile = profiles[sender];
        EntityProfile storage recipientProfile = profiles[recipient];
        
        // Sanctions check
        if (requireSanctionsCheck) {
            if (senderProfile.isSanctioned) {
                check = _reject(paymentId, sender, recipient, "Sender is sanctioned");
                return check;
            }
            if (recipientProfile.isSanctioned) {
                check = _reject(paymentId, sender, recipient, "Recipient is sanctioned");
                return check;
            }
        }
        
        // Tier verification
        if (senderProfile.tier < requiredSenderTier) {
            check = _reject(paymentId, sender, recipient, "Sender tier insufficient");
            return check;
        }
        if (recipientProfile.tier < requiredRecipientTier) {
            check = _reject(paymentId, sender, recipient, "Recipient tier insufficient");
            return check;
        }
        
        // Verification expiry
        if (senderProfile.isVerified && senderProfile.expiresAt < block.timestamp) {
            check = _reject(paymentId, sender, recipient, "Sender verification expired");
            return check;
        }
        
        // Limit checks
        _resetLimitsIfNeeded(senderProfile);
        
        if (amount > senderProfile.singleTxLimit) {
            check = _reject(paymentId, sender, recipient, "Exceeds single transaction limit");
            return check;
        }
        
        if (senderProfile.dailyVolume + amount > senderProfile.dailyLimit) {
            check = _reject(paymentId, sender, recipient, "Exceeds daily limit");
            return check;
        }
        
        if (senderProfile.monthlyVolume + amount > senderProfile.monthlyLimit) {
            check = _reject(paymentId, sender, recipient, "Exceeds monthly limit");
            return check;
        }
        
        // Update volume tracking
        senderProfile.dailyVolume += amount;
        senderProfile.monthlyVolume += amount;
        
        // Travel rule check
        bool requiresTravelRule = amount >= travelRuleThreshold;
        
        // Enhanced due diligence for high risk
        bool requiresEnhancedDD = senderProfile.riskScore > 70 || 
                                  recipientProfile.riskScore > 70 ||
                                  senderProfile.isPEP ||
                                  recipientProfile.isPEP;
        
        check = TransactionCheck({
            passed: true,
            reason: "Compliance check passed",
            requiresTravelRule: requiresTravelRule,
            requiresEnhancedDD: requiresEnhancedDD,
            timestamp: block.timestamp
        });
        
        emit TransactionChecked(paymentId, sender, recipient, true, "Passed");
        
        return check;
    }

    function _reject(
        bytes32 paymentId,
        address sender,
        address recipient,
        string memory reason
    ) internal returns (TransactionCheck memory) {
        totalRejections++;
        emit TransactionChecked(paymentId, sender, recipient, false, reason);
        
        return TransactionCheck({
            passed: false,
            reason: reason,
            requiresTravelRule: false,
            requiresEnhancedDD: false,
            timestamp: block.timestamp
        });
    }

    function _resetLimitsIfNeeded(EntityProfile storage profile) internal {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 currentMonth = block.timestamp / 30 days;
        
        if (profile.lastDayReset < currentDay) {
            profile.dailyVolume = 0;
            profile.lastDayReset = currentDay;
        }
        
        if (profile.lastMonthReset < currentMonth) {
            profile.monthlyVolume = 0;
            profile.lastMonthReset = currentMonth;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         SANCTIONS LIST
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Add entity hash to sanctions list
     */
    function addToSanctionsList(bytes32 entityHash) external onlyRole(SANCTIONS_UPDATER) {
        if (!sanctionsList[entityHash]) {
            sanctionsList[entityHash] = true;
            sanctionsListSize++;
            emit SanctionsListUpdated(entityHash, true);
        }
    }

    /**
     * @notice Bulk add to sanctions list
     */
    function bulkAddToSanctionsList(bytes32[] calldata entityHashes) external onlyRole(SANCTIONS_UPDATER) {
        for (uint256 i = 0; i < entityHashes.length; i++) {
            if (!sanctionsList[entityHashes[i]]) {
                sanctionsList[entityHashes[i]] = true;
                sanctionsListSize++;
            }
        }
    }

    /**
     * @notice Remove from sanctions list
     */
    function removeFromSanctionsList(bytes32 entityHash) external onlyRole(SANCTIONS_UPDATER) {
        if (sanctionsList[entityHash]) {
            sanctionsList[entityHash] = false;
            sanctionsListSize--;
            emit SanctionsListUpdated(entityHash, false);
        }
    }

    /**
     * @notice Check if entity hash is sanctioned
     */
    function isSanctioned(bytes32 entityHash) external view returns (bool) {
        return sanctionsList[entityHash];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         JURISDICTION MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    function addRestrictedJurisdiction(string calldata jurisdiction) external onlyRole(COMPLIANCE_OFFICER) {
        restrictedJurisdictions[jurisdiction] = true;
    }

    function removeRestrictedJurisdiction(string calldata jurisdiction) external onlyRole(COMPLIANCE_OFFICER) {
        restrictedJurisdictions[jurisdiction] = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    function getEntityProfile(address entity) external view returns (
        ComplianceTier tier,
        bool isVerified,
        bool sanctioned,
        string memory jurisdiction,
        uint8 riskScore,
        uint256 dailyRemaining,
        uint256 monthlyRemaining
    ) {
        EntityProfile storage p = profiles[entity];
        
        uint256 dailyUsed = p.lastDayReset == block.timestamp / 1 days ? p.dailyVolume : 0;
        uint256 monthlyUsed = p.lastMonthReset == block.timestamp / 30 days ? p.monthlyVolume : 0;
        
        return (
            p.tier,
            p.isVerified,
            p.isSanctioned,
            p.jurisdiction,
            p.riskScore,
            p.dailyLimit > dailyUsed ? p.dailyLimit - dailyUsed : 0,
            p.monthlyLimit > monthlyUsed ? p.monthlyLimit - monthlyUsed : 0
        );
    }

    function getComplianceStats() external view returns (
        uint256 verifications,
        uint256 checks,
        uint256 rejections,
        uint256 sanctions
    ) {
        return (totalVerifications, totalChecks, totalRejections, sanctionsListSize);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    function setTravelRuleThreshold(uint256 threshold) external onlyRole(COMPLIANCE_OFFICER) {
        travelRuleThreshold = threshold;
    }

    function setTierLimits(
        ComplianceTier tier,
        uint256 daily,
        uint256 monthly,
        uint256 singleTx
    ) external onlyRole(COMPLIANCE_OFFICER) {
        tierDailyLimits[tier] = daily;
        tierMonthlyLimits[tier] = monthly;
        tierSingleTxLimits[tier] = singleTx;
    }
}
