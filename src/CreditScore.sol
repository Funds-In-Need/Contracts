// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract setCreditScore {
    // Mapping of address to credit score (0-100)
    mapping(address => uint256) public creditScores;
    
    // Maximum possible score
    uint256 public constant MAX_SCORE = 100;
    
    // Events
    event ScoreUpdated(address indexed user, uint256 score);
    
    constructor() {
        // Initialize some test addresses with scores
        creditScores[address(0xb8D54e83d6ea416AD2600a4010d94B10a6E7Bf3a)] = 85;
        creditScores[address(0x5AFD81FaC3BD2B1BA5C9716a140C6bB1D159b79A)] = 65;
    }
    
    // Get credit score for an address
    function getCreditScore(address user) external view returns (uint256) {
        return creditScores[user];
    }

    // Constants for metric weights
    uint256 constant TRANSACTION_HISTORY_WEIGHT = 30;  // 30%
    uint256 constant LTV_SCORE_WEIGHT = 30;           // 30%
    uint256 constant ACCOUNT_AGE_WEIGHT = 20;         // 20%
    uint256 constant INTERACTION_FREQUENCY_WEIGHT = 20;// 20%

    // Safe LTV threshold
    uint256 constant MAX_SAFE_LTV = 75;

    // Helper function to get log base 10 (used for calculations)
    function logBase10(uint256 x) internal pure returns (uint256) {
        uint256 result = 0;
        while (x >= 10) {
            x /= 10;
            result++;
        }
        return result;
    }

    // Function to calculate transaction history score
    function calculateTransactionHistoryScore(uint256 numTransactions) public pure returns (uint256) {
        if (numTransactions == 0) return 0;
        
        // Create more granular scoring tiers for 30 points
        if (numTransactions <= 5) {
            return (TRANSACTION_HISTORY_WEIGHT * 2) / 10; // 20% = 6 points
        } else if (numTransactions <= 10) {
            return (TRANSACTION_HISTORY_WEIGHT * 4) / 10; // 40% = 12 points
        } else if (numTransactions <= 15) {
            return (TRANSACTION_HISTORY_WEIGHT * 6) / 10; // 60% = 18 points
        } else if (numTransactions <= 20) {
            return (TRANSACTION_HISTORY_WEIGHT * 8) / 10; // 80% = 24 points
        } else {
            return TRANSACTION_HISTORY_WEIGHT; // 100% = 30 points
        }
    }

    // Function to calculate LTV score
    function calculateLTVScore(uint256 borrowAmount, uint256 collateralAmount) public pure returns (uint256) {
        require(collateralAmount > 0, "Collateral amount must be greater than zero.");
        uint256 ltv = (borrowAmount * 10**18) / collateralAmount;
        uint256 maxLTVScaled = (MAX_SAFE_LTV * 10**18) / 100;
        uint256 ltvFactor = (ltv * 10**18) / maxLTVScaled;
        uint256 minFactor = ltvFactor > 10**18 ? 10**18 : ltvFactor;
        uint256 scoreFactor = 10**18 - minFactor;
        return (LTV_SCORE_WEIGHT * scoreFactor) / 10**18; // Scale to 0-30
    }

    // Function to calculate account age score
    function calculateAccountAgeScore(uint256 accountAgeInDays) public pure returns (uint256) {
        uint256 log365 = logBase10(365);
        uint256 logAccountAge = logBase10(accountAgeInDays);
        uint256 ageFactor = (logAccountAge * 10**18) / log365;
        uint256 minFactor = ageFactor > 10**18 ? 10**18 : ageFactor;
        return (ACCOUNT_AGE_WEIGHT * minFactor) / 10**18; // Scale to 0-20
    }

    // Function to calculate frequency of interaction score
    function calculateFrequencyScore(uint256 interactions) public pure returns (uint256) {
        uint256 log12 = logBase10(12);
        uint256 logInteractions = logBase10(interactions);
        uint256 interactionFactor = (logInteractions * 10**18) / log12;
        uint256 minFactor = interactionFactor > 10**18 ? 10**18 : interactionFactor;
        return (INTERACTION_FREQUENCY_WEIGHT * minFactor) / 10**18; // Scale to 0-20
    }

    // Aggregate function to calculate total credit score
    function calculateCreditScore(
        address user,
        uint256 numTransactions,
        uint256 borrowAmount,
        uint256 collateralAmount,
        uint256 accountAgeInDays,
        uint256 interactions
    ) public returns (uint256) {
        require(user != address(0), "Invalid address");

        uint256 transactionScore = calculateTransactionHistoryScore(numTransactions);
        uint256 ltvScore = calculateLTVScore(borrowAmount, collateralAmount);
        uint256 accountAgeScore = calculateAccountAgeScore(accountAgeInDays);
        uint256 interactionScore = calculateFrequencyScore(interactions);

        // Final score is the sum of all weighted scores
        uint256 totalScore = transactionScore + ltvScore + accountAgeScore + interactionScore;
        
        // Store or update the score in mapping
        creditScores[user] = totalScore;
        
        // Emit event for the update
        emit ScoreUpdated(user, totalScore);
        
        return totalScore;
    }
}
