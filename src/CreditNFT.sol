// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";  // Add this import
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./CreditScore.sol";

contract myToken is ERC1155 {
    // Constants for token IDs
    uint256 public constant BRONZE = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant GOLD = 2;

    // Score thresholds
    uint256 public constant BRONZE_THRESHOLD = 30;  // 30-59
    uint256 public constant SILVER_THRESHOLD = 60;  // 60-79
    uint256 public constant GOLD_THRESHOLD = 80;    // 80-100

    setScore public creditScoreContract;

    // Mapping to track if user has minted their tier
    mapping(address => bool) public hasMinted;

    // Events
    event CreditNFTMinted(address indexed user, uint256 tier, uint256 score);

    constructor(address _creditScoreContract) ERC1155("https://ipfs.io/ipfs/QmUhSAKtW9CJELgdCBSP4ayDLvc3NLopRQiyETF8exyyvq/{id}.json") {
        creditScoreContract = setScore(_creditScoreContract);
    }

    // Get eligible tier based on credit score
    function getEligibleTier(uint256 score) public pure returns (uint256) {
        if (score >= GOLD_THRESHOLD) {
            return GOLD;
        } else if (score >= SILVER_THRESHOLD) {
            return SILVER;
        } else if (score >= BRONZE_THRESHOLD) {
            return BRONZE;
        } else {
            revert("Score too low for any tier");
        }
    }

    // Mint NFT based on credit score
    function mintCreditNFT() external {
        require(!hasMinted[msg.sender], "Already minted NFT");
        
        // Get user's credit score directly from CreditScore contract
        uint256 score = creditScoreContract.creditScores(msg.sender);
        require(score >= BRONZE_THRESHOLD, "Score too low to mint");

        // Determine tier
        uint256 tier = getEligibleTier(score);

        // Mint NFT
        _mint(msg.sender, tier, 1, "");
        hasMinted[msg.sender] = true;

        emit CreditNFTMinted(msg.sender, tier, score);
    }

    // Allow users to burn their NFT if they want to mint a new one
    function burnNFT(uint256 tier) external {
        require(balanceOf(msg.sender, tier) > 0, "No NFT to burn");
        _burn(msg.sender, tier, 1);
        hasMinted[msg.sender] = false;
    }

    function uri(uint256 tokenId) public pure override returns (string memory) {
        return string(abi.encodePacked("https://ipfs.io/ipfs/QmUhSAKtW9CJELgdCBSP4ayDLvc3NLopRQiyETF8exyyvq/", Strings.toString(tokenId), ".json"));
    }

    // View functions
    function checkEligibility(address user) external view returns (uint256) {
        uint256 score = creditScoreContract.creditScores(user);
        return getEligibleTier(score);
    }

    function hasUserMinted(address user) external view returns (bool) {
        return hasMinted[user];
    }
}