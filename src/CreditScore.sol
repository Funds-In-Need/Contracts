// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract setScore {
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
        creditScores[address(0x163ac1ccAa7e63Ed01D1fb90c0cc32FB676ACEDd)] = 70;
    }
    
    // Get credit score for an address
    function getCreditScore(address user) external view returns (uint256) {
        return creditScores[user];
    }
}