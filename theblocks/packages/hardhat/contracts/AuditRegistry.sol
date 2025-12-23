// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AuditRegistry
 * @notice Immutable regulatory audit trail for institutional payments
 * @dev Creates tamper-proof records for regulatory compliance and reporting
 * 
 * KEY FEATURES:
 * - Immutable event logging
 * - Regulatory-grade audit trails
 * - Travel Rule compliance records
 * - Multi-jurisdictional reporting
 * - Batch querying for compliance reports
 */
contract AuditRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant LOGGER_ROLE = keccak256("LOGGER_ROLE");

    enum EventType {
        PAYMENT_CREATED,
        PAYMENT_APPROVED,
        PAYMENT_EXECUTED,
        PAYMENT_FAILED,
        PAYMENT_CANCELLED,
        PAYMENT_DISPUTED,
        COMPLIANCE_CHECK,
        SANCTIONS_CHECK,
        KYC_VERIFICATION,
        ESCROW_CREATED,
        ESCROW_RELEASED,
        ESCROW_DISPUTED,
        FX_CONVERSION,
        MULTI_SIG_APPROVAL,
        ALERT_RAISED,
        SYSTEM_EVENT
    }

    enum Severity {
        INFO,
        WARNING,
        CRITICAL,
        ALERT
    }

    struct AuditEntry {
        bytes32 entryId;
        bytes32 paymentId;          // Related payment (if applicable)
        EventType eventType;
        Severity severity;
        
        address actor;              // Who triggered the event
        address subject;            // Who the event is about
        
        // Event data
        bytes32 dataHash;           // Hash of detailed data
        string description;
        
        // Amounts
        uint256 amount;
        address token;
        
        // Compliance
        bool travelRuleApplied;
        bytes32 travelRuleDataHash;
        
        // Metadata
        uint256 timestamp;
        uint256 blockNumber;
        string jurisdiction;
    }

    struct AuditQuery {
        bytes32 paymentId;
        address actor;
        EventType eventType;
        uint256 fromTimestamp;
        uint256 toTimestamp;
        string jurisdiction;
    }

    // State
    mapping(bytes32 => AuditEntry) public entries;
    bytes32[] public allEntries;
    
    mapping(bytes32 => bytes32[]) public paymentAuditTrail;  // paymentId => entryIds
    mapping(address => bytes32[]) public actorAuditTrail;    // actor => entryIds
    mapping(EventType => bytes32[]) public typeAuditTrail;   // eventType => entryIds
    mapping(string => bytes32[]) public jurisdictionTrail;    // jurisdiction => entryIds
    
    // Statistics
    uint256 public totalEntries;
    mapping(EventType => uint256) public entriesByType;
    mapping(Severity => uint256) public entriesBySeverity;

    // Authorized loggers (PayFlowCore, ComplianceEngine, etc.)
    mapping(address => bool) public authorizedLoggers;

    // Events
    event AuditLogged(
        bytes32 indexed entryId,
        bytes32 indexed paymentId,
        EventType eventType,
        address indexed actor,
        uint256 timestamp
    );
    
    event AlertRaised(
        bytes32 indexed entryId,
        bytes32 indexed paymentId,
        Severity severity,
        string description
    );
    
    event TravelRuleRecorded(
        bytes32 indexed paymentId,
        bytes32 dataHash,
        string jurisdiction
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
        _grantRole(LOGGER_ROLE, msg.sender);
        authorizedLoggers[msg.sender] = true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         LOGGING
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Log an audit entry
     */
    function logEntry(
        bytes32 paymentId,
        EventType eventType,
        Severity severity,
        address actor,
        address subject,
        bytes32 dataHash,
        string calldata description,
        uint256 amount,
        address token,
        string calldata jurisdiction
    ) external onlyRole(LOGGER_ROLE) returns (bytes32 entryId) {
        entryId = keccak256(abi.encodePacked(
            paymentId,
            eventType,
            actor,
            block.timestamp,
            totalEntries
        ));
        
        AuditEntry storage entry = entries[entryId];
        entry.entryId = entryId;
        entry.paymentId = paymentId;
        entry.eventType = eventType;
        entry.severity = severity;
        entry.actor = actor;
        entry.subject = subject;
        entry.dataHash = dataHash;
        entry.description = description;
        entry.amount = amount;
        entry.token = token;
        entry.timestamp = block.timestamp;
        entry.blockNumber = block.number;
        entry.jurisdiction = jurisdiction;
        
        // Index
        allEntries.push(entryId);
        paymentAuditTrail[paymentId].push(entryId);
        actorAuditTrail[actor].push(entryId);
        typeAuditTrail[eventType].push(entryId);
        
        if (bytes(jurisdiction).length > 0) {
            jurisdictionTrail[jurisdiction].push(entryId);
        }
        
        // Stats
        totalEntries++;
        entriesByType[eventType]++;
        entriesBySeverity[severity]++;
        
        emit AuditLogged(entryId, paymentId, eventType, actor, block.timestamp);
        
        if (severity >= Severity.CRITICAL) {
            emit AlertRaised(entryId, paymentId, severity, description);
        }
        
        return entryId;
    }

    /**
     * @notice Log payment creation
     */
    function logPaymentCreated(
        bytes32 paymentId,
        address sender,
        address recipient,
        uint256 amount,
        address token,
        string calldata jurisdiction
    ) external onlyRole(LOGGER_ROLE) returns (bytes32) {
        return _logSimple(
            paymentId,
            EventType.PAYMENT_CREATED,
            Severity.INFO,
            sender,
            recipient,
            amount,
            token,
            "Payment created",
            jurisdiction
        );
    }

    /**
     * @notice Log payment execution
     */
    function logPaymentExecuted(
        bytes32 paymentId,
        address sender,
        address recipient,
        uint256 amount,
        address token,
        uint256 settlementTime,
        string calldata jurisdiction
    ) external onlyRole(LOGGER_ROLE) returns (bytes32) {
        string memory desc = string(abi.encodePacked(
            "Payment executed. Settlement time: ",
            _uint2str(settlementTime),
            " seconds"
        ));
        
        return _logSimple(
            paymentId,
            EventType.PAYMENT_EXECUTED,
            Severity.INFO,
            sender,
            recipient,
            amount,
            token,
            desc,
            jurisdiction
        );
    }

    /**
     * @notice Log compliance check
     */
    function logComplianceCheck(
        bytes32 paymentId,
        address entity,
        bool passed,
        string calldata reason,
        string calldata jurisdiction
    ) external onlyRole(LOGGER_ROLE) returns (bytes32) {
        return _logSimple(
            paymentId,
            EventType.COMPLIANCE_CHECK,
            passed ? Severity.INFO : Severity.WARNING,
            entity,
            entity,
            0,
            address(0),
            reason,
            jurisdiction
        );
    }

    /**
     * @notice Log Travel Rule compliance data
     */
    function logTravelRule(
        bytes32 paymentId,
        bytes32 travelRuleDataHash,
        address sender,
        address recipient,
        uint256 amount,
        string calldata jurisdiction
    ) external onlyRole(LOGGER_ROLE) returns (bytes32 entryId) {
        entryId = keccak256(abi.encodePacked(
            paymentId,
            EventType.COMPLIANCE_CHECK,
            travelRuleDataHash,
            block.timestamp
        ));
        
        AuditEntry storage entry = entries[entryId];
        entry.entryId = entryId;
        entry.paymentId = paymentId;
        entry.eventType = EventType.COMPLIANCE_CHECK;
        entry.severity = Severity.INFO;
        entry.actor = sender;
        entry.subject = recipient;
        entry.amount = amount;
        entry.travelRuleApplied = true;
        entry.travelRuleDataHash = travelRuleDataHash;
        entry.timestamp = block.timestamp;
        entry.blockNumber = block.number;
        entry.jurisdiction = jurisdiction;
        entry.description = "Travel Rule data recorded";
        
        allEntries.push(entryId);
        paymentAuditTrail[paymentId].push(entryId);
        totalEntries++;
        
        emit TravelRuleRecorded(paymentId, travelRuleDataHash, jurisdiction);
        
        return entryId;
    }

    function _logSimple(
        bytes32 paymentId,
        EventType eventType,
        Severity severity,
        address actor,
        address subject,
        uint256 amount,
        address token,
        string memory description,
        string memory jurisdiction
    ) internal returns (bytes32 entryId) {
        entryId = keccak256(abi.encodePacked(
            paymentId,
            eventType,
            actor,
            block.timestamp,
            totalEntries
        ));
        
        AuditEntry storage entry = entries[entryId];
        entry.entryId = entryId;
        entry.paymentId = paymentId;
        entry.eventType = eventType;
        entry.severity = severity;
        entry.actor = actor;
        entry.subject = subject;
        entry.amount = amount;
        entry.token = token;
        entry.description = description;
        entry.timestamp = block.timestamp;
        entry.blockNumber = block.number;
        entry.jurisdiction = jurisdiction;
        
        allEntries.push(entryId);
        paymentAuditTrail[paymentId].push(entryId);
        actorAuditTrail[actor].push(entryId);
        typeAuditTrail[eventType].push(entryId);
        
        totalEntries++;
        entriesByType[eventType]++;
        entriesBySeverity[severity]++;
        
        emit AuditLogged(entryId, paymentId, eventType, actor, block.timestamp);
        
        return entryId;
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         QUERIES
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Get full audit trail for a payment
     */
    function getPaymentAuditTrail(bytes32 paymentId) 
        external 
        view 
        returns (AuditEntry[] memory) 
    {
        bytes32[] storage entryIds = paymentAuditTrail[paymentId];
        AuditEntry[] memory trail = new AuditEntry[](entryIds.length);
        
        for (uint256 i = 0; i < entryIds.length; i++) {
            trail[i] = entries[entryIds[i]];
        }
        
        return trail;
    }

    /**
     * @notice Get audit entries for an actor
     */
    function getActorAuditTrail(
        address actor,
        uint256 limit
    ) external view returns (AuditEntry[] memory) {
        bytes32[] storage entryIds = actorAuditTrail[actor];
        uint256 count = entryIds.length > limit ? limit : entryIds.length;
        AuditEntry[] memory trail = new AuditEntry[](count);
        
        // Return most recent entries
        for (uint256 i = 0; i < count; i++) {
            trail[i] = entries[entryIds[entryIds.length - 1 - i]];
        }
        
        return trail;
    }

    /**
     * @notice Get entries by jurisdiction for regulatory reports
     */
    function getJurisdictionEntries(
        string calldata jurisdiction,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 limit
    ) external view returns (AuditEntry[] memory) {
        bytes32[] storage entryIds = jurisdictionTrail[jurisdiction];
        
        // Count matching entries
        uint256 matchCount = 0;
        for (uint256 i = 0; i < entryIds.length && matchCount < limit; i++) {
            AuditEntry storage entry = entries[entryIds[i]];
            if (entry.timestamp >= fromTimestamp && entry.timestamp <= toTimestamp) {
                matchCount++;
            }
        }
        
        AuditEntry[] memory result = new AuditEntry[](matchCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < entryIds.length && index < matchCount; i++) {
            AuditEntry storage entry = entries[entryIds[i]];
            if (entry.timestamp >= fromTimestamp && entry.timestamp <= toTimestamp) {
                result[index] = entry;
                index++;
            }
        }
        
        return result;
    }

    /**
     * @notice Get entry by ID
     */
    function getEntry(bytes32 entryId) external view returns (AuditEntry memory) {
        return entries[entryId];
    }

    /**
     * @notice Get recent entries
     */
    function getRecentEntries(uint256 count) external view returns (AuditEntry[] memory) {
        uint256 total = allEntries.length;
        uint256 resultCount = count > total ? total : count;
        AuditEntry[] memory result = new AuditEntry[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = entries[allEntries[total - 1 - i]];
        }
        
        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    function getStatistics() external view returns (
        uint256 total,
        uint256 payments,
        uint256 compliance,
        uint256 alerts
    ) {
        return (
            totalEntries,
            entriesByType[EventType.PAYMENT_EXECUTED],
            entriesByType[EventType.COMPLIANCE_CHECK],
            entriesBySeverity[Severity.ALERT]
        );
    }

    function getPaymentTrailLength(bytes32 paymentId) external view returns (uint256) {
        return paymentAuditTrail[paymentId].length;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    function authorizeLogger(address logger) external onlyRole(DEFAULT_ADMIN_ROLE) {
        authorizedLoggers[logger] = true;
        _grantRole(LOGGER_ROLE, logger);
    }

    function revokeLogger(address logger) external onlyRole(DEFAULT_ADMIN_ROLE) {
        authorizedLoggers[logger] = false;
        _revokeRole(LOGGER_ROLE, logger);
    }
}
