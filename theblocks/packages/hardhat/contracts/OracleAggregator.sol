// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OracleAggregator
 * @notice Multi-source FX rate aggregation with TWAP and circuit breakers
 * @dev Aggregates rates from multiple oracles for institutional-grade accuracy
 * 
 * KEY FEATURES:
 * - Multi-oracle price feeds with weighted averages
 * - Time-weighted average price (TWAP) calculation
 * - Circuit breakers for extreme volatility
 * - Staleness detection and fallback
 * - Rate caching for gas optimization
 */
contract OracleAggregator is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ADMIN = keccak256("ORACLE_ADMIN");
    bytes32 public constant PRICE_UPDATER = keccak256("PRICE_UPDATER");

    struct PriceData {
        uint256 rate;               // Rate scaled to 18 decimals
        uint256 timestamp;          // Last update time
        uint256 confidence;         // Confidence level 0-100
        bool isActive;
    }

    struct OracleSource {
        address oracle;
        string name;
        uint256 weight;             // Weight in aggregation (sum = 10000)
        bool isActive;
        uint256 lastUpdate;
        uint256 totalUpdates;
    }

    struct CurrencyPair {
        string base;                // e.g., "USD"
        string quote;               // e.g., "EUR"
        bytes32 pairId;
        bool isActive;
        
        // Current rate
        uint256 currentRate;
        uint256 lastUpdate;
        
        // TWAP data
        uint256[] rateHistory;
        uint256[] timestamps;
        uint256 twapPeriod;         // TWAP calculation period
        
        // Circuit breaker
        uint256 maxDeviation;       // Max allowed deviation in bps
        bool circuitBreakerTripped;
    }

    struct RateResponse {
        uint256 spotRate;
        uint256 twapRate;
        uint256 confidence;
        uint256 timestamp;
        bool isStale;
        bool circuitBreakerActive;
    }

    // State
    mapping(bytes32 => CurrencyPair) public pairs;
    mapping(bytes32 => mapping(address => PriceData)) public oraclePrices;
    mapping(address => OracleSource) public oracleSources;
    
    bytes32[] public activePairs;
    address[] public activeOracles;
    
    // Settings
    uint256 public stalenessThreshold = 1 hours;
    uint256 public defaultTwapPeriod = 15 minutes;
    uint256 public defaultMaxDeviation = 500; // 5%
    uint256 public minOracleCount = 2;

    // Statistics
    uint256 public totalPriceUpdates;
    uint256 public totalQueries;
    uint256 public circuitBreakerTriggers;

    // Events
    event PriceUpdated(
        bytes32 indexed pairId,
        address indexed oracle,
        uint256 rate,
        uint256 timestamp
    );
    
    event PairAdded(
        bytes32 indexed pairId,
        string base,
        string quote
    );
    
    event OracleAdded(
        address indexed oracle,
        string name,
        uint256 weight
    );
    
    event CircuitBreakerTripped(
        bytes32 indexed pairId,
        uint256 expectedRate,
        uint256 actualRate,
        uint256 deviation
    );
    
    event CircuitBreakerReset(bytes32 indexed pairId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ADMIN, msg.sender);
        _grantRole(PRICE_UPDATER, msg.sender);
        
        // Initialize common FX pairs
        _addPair("USD", "EUR");
        _addPair("USD", "GBP");
        _addPair("USD", "JPY");
        _addPair("EUR", "GBP");
        _addPair("USD", "USDC");
        _addPair("USD", "USDT");
        _addPair("ETH", "USD");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PAIR MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    function addPair(
        string calldata base,
        string calldata quote
    ) external onlyRole(ORACLE_ADMIN) returns (bytes32 pairId) {
        return _addPair(base, quote);
    }

    function _addPair(
        string memory base,
        string memory quote
    ) internal returns (bytes32 pairId) {
        pairId = keccak256(abi.encodePacked(base, "/", quote));
        require(!pairs[pairId].isActive, "Pair exists");
        
        CurrencyPair storage pair = pairs[pairId];
        pair.base = base;
        pair.quote = quote;
        pair.pairId = pairId;
        pair.isActive = true;
        pair.twapPeriod = defaultTwapPeriod;
        pair.maxDeviation = defaultMaxDeviation;
        
        activePairs.push(pairId);
        
        emit PairAdded(pairId, base, quote);
        
        return pairId;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         ORACLE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════

    function addOracle(
        address oracle,
        string calldata name,
        uint256 weight
    ) external onlyRole(ORACLE_ADMIN) {
        require(oracle != address(0), "Invalid oracle");
        require(!oracleSources[oracle].isActive, "Oracle exists");
        
        oracleSources[oracle] = OracleSource({
            oracle: oracle,
            name: name,
            weight: weight,
            isActive: true,
            lastUpdate: 0,
            totalUpdates: 0
        });
        
        activeOracles.push(oracle);
        
        emit OracleAdded(oracle, name, weight);
    }

    function updateOracleWeight(
        address oracle,
        uint256 weight
    ) external onlyRole(ORACLE_ADMIN) {
        require(oracleSources[oracle].isActive, "Oracle not found");
        oracleSources[oracle].weight = weight;
    }

    function deactivateOracle(address oracle) external onlyRole(ORACLE_ADMIN) {
        oracleSources[oracle].isActive = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         PRICE UPDATES
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Update price for a currency pair
     */
    function updatePrice(
        bytes32 pairId,
        uint256 rate,
        uint256 confidence
    ) external onlyRole(PRICE_UPDATER) {
        require(pairs[pairId].isActive, "Pair not active");
        require(rate > 0, "Invalid rate");
        require(confidence <= 100, "Invalid confidence");
        
        CurrencyPair storage pair = pairs[pairId];
        
        // Circuit breaker check
        if (pair.currentRate > 0) {
            uint256 deviation = _calculateDeviation(pair.currentRate, rate);
            if (deviation > pair.maxDeviation) {
                pair.circuitBreakerTripped = true;
                circuitBreakerTriggers++;
                emit CircuitBreakerTripped(pairId, pair.currentRate, rate, deviation);
                return;
            }
        }
        
        // Update oracle-specific price
        oraclePrices[pairId][msg.sender] = PriceData({
            rate: rate,
            timestamp: block.timestamp,
            confidence: confidence,
            isActive: true
        });
        
        oracleSources[msg.sender].lastUpdate = block.timestamp;
        oracleSources[msg.sender].totalUpdates++;
        
        // Calculate aggregated rate
        uint256 aggregatedRate = _calculateAggregatedRate(pairId);
        
        // Update pair data
        pair.currentRate = aggregatedRate;
        pair.lastUpdate = block.timestamp;
        
        // Add to history for TWAP
        pair.rateHistory.push(aggregatedRate);
        pair.timestamps.push(block.timestamp);
        
        // Trim history to keep only relevant period
        _trimHistory(pair);
        
        totalPriceUpdates++;
        
        emit PriceUpdated(pairId, msg.sender, rate, block.timestamp);
    }

    /**
     * @notice Batch update multiple prices
     */
    function batchUpdatePrices(
        bytes32[] calldata pairIds,
        uint256[] calldata rates,
        uint256[] calldata confidences
    ) external onlyRole(PRICE_UPDATER) {
        require(pairIds.length == rates.length, "Length mismatch");
        require(pairIds.length == confidences.length, "Length mismatch");
        
        for (uint256 i = 0; i < pairIds.length; i++) {
            if (pairs[pairIds[i]].isActive && rates[i] > 0) {
                oraclePrices[pairIds[i]][msg.sender] = PriceData({
                    rate: rates[i],
                    timestamp: block.timestamp,
                    confidence: confidences[i],
                    isActive: true
                });
                
                pairs[pairIds[i]].currentRate = rates[i];
                pairs[pairIds[i]].lastUpdate = block.timestamp;
            }
        }
        
        totalPriceUpdates += pairIds.length;
    }

    function _calculateAggregatedRate(bytes32 pairId) internal view returns (uint256) {
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;
        uint256 validOracles = 0;
        
        for (uint256 i = 0; i < activeOracles.length; i++) {
            address oracle = activeOracles[i];
            if (!oracleSources[oracle].isActive) continue;
            
            PriceData storage price = oraclePrices[pairId][oracle];
            if (!price.isActive) continue;
            if (block.timestamp - price.timestamp > stalenessThreshold) continue;
            
            uint256 weight = oracleSources[oracle].weight;
            weightedSum += price.rate * weight;
            totalWeight += weight;
            validOracles++;
        }
        
        if (totalWeight == 0 || validOracles < minOracleCount) {
            return pairs[pairId].currentRate; // Fall back to last known rate
        }
        
        return weightedSum / totalWeight;
    }

    function _calculateDeviation(uint256 oldRate, uint256 newRate) internal pure returns (uint256) {
        if (oldRate == 0) return 0;
        uint256 diff = oldRate > newRate ? oldRate - newRate : newRate - oldRate;
        return (diff * 10000) / oldRate;
    }

    function _trimHistory(CurrencyPair storage pair) internal {
        uint256 cutoff = block.timestamp - pair.twapPeriod;
        uint256 i = 0;
        
        // Find first timestamp within period
        while (i < pair.timestamps.length && pair.timestamps[i] < cutoff) {
            i++;
        }
        
        if (i > 0 && pair.rateHistory.length > 100) {
            // Shift arrays (gas expensive, only do when necessary)
            uint256 newLength = pair.rateHistory.length - i;
            for (uint256 j = 0; j < newLength; j++) {
                pair.rateHistory[j] = pair.rateHistory[j + i];
                pair.timestamps[j] = pair.timestamps[j + i];
            }
            for (uint256 j = 0; j < i; j++) {
                pair.rateHistory.pop();
                pair.timestamps.pop();
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         RATE QUERIES
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Get current rate for a currency pair
     */
    function getRate(bytes32 pairId) external view returns (RateResponse memory) {
        return _getRate(pairId);
    }

    /**
     * @notice Get rate for base/quote strings
     */
    function getRateBySymbols(
        string calldata base,
        string calldata quote
    ) external view returns (RateResponse memory) {
        bytes32 pairId = keccak256(abi.encodePacked(base, "/", quote));
        return _getRate(pairId);
    }

    function _getRate(bytes32 pairId) internal view returns (RateResponse memory) {
        CurrencyPair storage pair = pairs[pairId];
        
        bool isStale = block.timestamp - pair.lastUpdate > stalenessThreshold;
        uint256 twapRate = _calculateTWAP(pair);
        
        // Calculate confidence based on oracle agreement
        uint256 confidence = _calculateConfidence(pairId);
        
        return RateResponse({
            spotRate: pair.currentRate,
            twapRate: twapRate,
            confidence: confidence,
            timestamp: pair.lastUpdate,
            isStale: isStale,
            circuitBreakerActive: pair.circuitBreakerTripped
        });
    }

    function _calculateTWAP(CurrencyPair storage pair) internal view returns (uint256) {
        if (pair.rateHistory.length == 0) return pair.currentRate;
        if (pair.rateHistory.length == 1) return pair.rateHistory[0];
        
        uint256 cutoff = block.timestamp - pair.twapPeriod;
        uint256 weightedSum = 0;
        uint256 totalTime = 0;
        
        for (uint256 i = 0; i < pair.rateHistory.length; i++) {
            if (pair.timestamps[i] < cutoff) continue;
            
            uint256 timeDelta;
            if (i == pair.rateHistory.length - 1) {
                timeDelta = block.timestamp - pair.timestamps[i];
            } else {
                timeDelta = pair.timestamps[i + 1] - pair.timestamps[i];
            }
            
            weightedSum += pair.rateHistory[i] * timeDelta;
            totalTime += timeDelta;
        }
        
        if (totalTime == 0) return pair.currentRate;
        return weightedSum / totalTime;
    }

    function _calculateConfidence(bytes32 pairId) internal view returns (uint256) {
        uint256 validOracles = 0;
        uint256 totalConfidence = 0;
        
        for (uint256 i = 0; i < activeOracles.length; i++) {
            PriceData storage price = oraclePrices[pairId][activeOracles[i]];
            if (price.isActive && block.timestamp - price.timestamp <= stalenessThreshold) {
                validOracles++;
                totalConfidence += price.confidence;
            }
        }
        
        if (validOracles == 0) return 0;
        return totalConfidence / validOracles;
    }

    /**
     * @notice Convert amount between currencies
     */
    function convert(
        bytes32 pairId,
        uint256 amount,
        bool inverse
    ) external view returns (uint256 convertedAmount, uint256 rateUsed) {
        totalQueries;
        
        CurrencyPair storage pair = pairs[pairId];
        require(pair.isActive, "Pair not active");
        require(!pair.circuitBreakerTripped, "Circuit breaker active");
        
        rateUsed = pair.currentRate;
        
        if (inverse) {
            // Convert from quote to base
            convertedAmount = (amount * 1e18) / rateUsed;
        } else {
            // Convert from base to quote
            convertedAmount = (amount * rateUsed) / 1e18;
        }
        
        return (convertedAmount, rateUsed);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         CIRCUIT BREAKER
    // ═══════════════════════════════════════════════════════════════════════════

    function resetCircuitBreaker(bytes32 pairId) external onlyRole(ORACLE_ADMIN) {
        pairs[pairId].circuitBreakerTripped = false;
        emit CircuitBreakerReset(pairId);
    }

    function setMaxDeviation(bytes32 pairId, uint256 maxDeviation) external onlyRole(ORACLE_ADMIN) {
        pairs[pairId].maxDeviation = maxDeviation;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    function getPairInfo(bytes32 pairId) external view returns (
        string memory base,
        string memory quote,
        uint256 currentRate,
        uint256 lastUpdate,
        bool circuitBreakerTripped
    ) {
        CurrencyPair storage pair = pairs[pairId];
        return (
            pair.base,
            pair.quote,
            pair.currentRate,
            pair.lastUpdate,
            pair.circuitBreakerTripped
        );
    }

    function getAllPairs() external view returns (bytes32[] memory) {
        return activePairs;
    }

    function getOracleStats() external view returns (
        uint256 updates,
        uint256 queries,
        uint256 circuitBreakers,
        uint256 oracleCount
    ) {
        return (totalPriceUpdates, totalQueries, circuitBreakerTriggers, activeOracles.length);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //                         ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    function setStalenessThreshold(uint256 threshold) external onlyRole(ORACLE_ADMIN) {
        stalenessThreshold = threshold;
    }

    function setMinOracleCount(uint256 count) external onlyRole(ORACLE_ADMIN) {
        minOracleCount = count;
    }

    function setTwapPeriod(bytes32 pairId, uint256 period) external onlyRole(ORACLE_ADMIN) {
        pairs[pairId].twapPeriod = period;
    }
}
