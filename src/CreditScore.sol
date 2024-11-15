// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CreditScore {
    // Mapping of address to credit score (0-100)
    mapping(address => uint256) public creditScores;
    
    // Maximum possible score
    uint256 public constant MAX_SCORE = 100;
    
    // Events
    event ScoreUpdated(address indexed user, uint256 score);
    
    constructor() {
        // Initialize some test addresses with scores
        creditScores[address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4)] = 85;
        creditScores[address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2)] = 65;
        creditScores[address(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db)] = 45;
    }
    
    // Get credit score for an address
    function getCreditScore(address user) external view returns (uint256) {
        return creditScores[user];
    }
}