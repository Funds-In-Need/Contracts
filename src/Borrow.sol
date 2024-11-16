// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IChronicle {
    function read() external view returns (uint256 value);
    function readWithAge() external view returns (uint256 value, uint256 age);
}

interface ISelfKisser {
    function selfKiss(address oracle) external;
}

contract CreditBorrowing {
    // Credit NFT contract reference
    IERC1155 public finToken;
    IChronicle public chronicle;
    ISelfKisser public selfKisser;

    // Constants for token IDs
    uint256 public constant BRONZE = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant GOLD = 2;

    // Collateral ratios in basis points
    uint256 public constant GOLD_RATIO = 5000;    // 50%
    uint256 public constant SILVER_RATIO = 8000;  // 80%
    uint256 public constant BRONZE_RATIO = 10000; // 100%
    uint256 public constant NO_NFT_RATIO = 15000; // 150%

    struct BorrowerInfo {
        uint256 borrowedAmount;
        uint256 collateralAmount;
        uint256 collateralValueUSD;  // Added to track USD value
        uint256 nftTier;
        bool hasActiveLoan;
        bool hasCollateral;          // Added to track if user has collateral
    }

    mapping(address => BorrowerInfo) public borrowers;

    // Events
    event Deposited(address indexed depositor, uint256 amount);
    event Withdrawn(address indexed withdrawer, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount, uint256 collateral, uint256 tier);
    event LoanRepaid(address indexed borrower, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount, uint256 valueUSD);

    constructor(
        address _finToken,
        address _chronicle,
        address _selfKisser
    ) {
        finToken = IERC1155(_finToken);
        chronicle = IChronicle(_chronicle);
        selfKisser = ISelfKisser(_selfKisser);
        selfKisser.selfKiss(address(chronicle));
    }

    // Get current ETH price in USD (18 decimals)
    function getEthPrice() public view returns (uint256) {
        (uint256 price, ) = chronicle.readWithAge();
        return price;
    }

    // Calculate USD value of ETH amount
    function calculateUSDValue(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getEthPrice();
        return (ethAmount * ethPrice) / 1e18;
    }

    // Function to deposit or add more collateral
    function depositCollateral() public payable {
        require(msg.value > 0, "Must deposit some ETH");

        uint256 newCollateralValueUSD = calculateUSDValue(msg.value);
        
        // Add to existing collateral if any
        borrowers[msg.sender].collateralAmount += msg.value;
        borrowers[msg.sender].collateralValueUSD += newCollateralValueUSD;
        borrowers[msg.sender].hasCollateral = true;

        emit CollateralDeposited(msg.sender, msg.value, newCollateralValueUSD);
    }

    // Get current collateral value in USD
    function getCurrentCollateralValue(address user) public view returns (uint256) {
        BorrowerInfo memory borrower = borrowers[user];
        if (!borrower.hasCollateral) return 0;
        return calculateUSDValue(borrower.collateralAmount);
    }

    // Modified borrow function to use deposited collateral
    function borrow(uint256 borrowAmount) public {
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        require(borrowAmount <= address(this).balance, "Insufficient pool balance");
        require(!borrowers[msg.sender].hasActiveLoan, "Already has active loan");
        require(borrowers[msg.sender].hasCollateral, "No collateral deposited");

        // Check if user has any credit NFTs
        uint256 tier = 999; // Default to no NFT
        if (finToken.balanceOf(msg.sender, GOLD) > 0) {
            tier = GOLD;
        } else if (finToken.balanceOf(msg.sender, SILVER) > 0) {
            tier = SILVER;
        } else if (finToken.balanceOf(msg.sender, BRONZE) > 0) {
            tier = BRONZE;
        }

        // Calculate required collateral in USD
        uint256 borrowValueUSD = calculateUSDValue(borrowAmount);
        uint256 requiredCollateralUSD = getRequiredCollateral(borrowValueUSD, tier);
        uint256 currentCollateralUSD = getCurrentCollateralValue(msg.sender);

        require(currentCollateralUSD >= requiredCollateralUSD, "Insufficient collateral value");

        // Update borrower info
        borrowers[msg.sender].borrowedAmount = borrowAmount;
        borrowers[msg.sender].nftTier = tier;
        borrowers[msg.sender].hasActiveLoan = true;

        // Transfer borrowed amount
        (bool success, ) = payable(msg.sender).call{value: borrowAmount}("");
        require(success, "Transfer failed");

        emit Borrowed(msg.sender, borrowAmount, borrowers[msg.sender].collateralAmount, tier);
    }

    // Modified repay function
    function repayLoan() public payable {
        BorrowerInfo storage borrower = borrowers[msg.sender];
        require(borrower.hasActiveLoan, "No active loan");
        require(msg.value <= borrower.borrowedAmount, "Overpay");

        // Return collateral
        uint256 collateralToReturn = borrower.collateralAmount;
        
        // Clear borrower data
        borrower.borrowedAmount = 0;
        borrower.hasActiveLoan = false;
        borrower.hasCollateral = false;
        borrower.collateralAmount = 0;
        borrower.collateralValueUSD = 0;

        // Return collateral
        (bool success, ) = payable(msg.sender).call{value: collateralToReturn}("");
        require(success, "Collateral return failed");

        emit LoanRepaid(msg.sender, msg.value);
    }

    // Rest of the functions remain the same...
    function deposit() public payable {
        require(msg.value > 0, "Must deposit some ETH");
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function getRequiredCollateral(uint256 borrowAmount, uint256 tier) public pure returns (uint256) {
        uint256 ratio;
        if (tier == GOLD) {
            ratio = GOLD_RATIO;
        } else if (tier == SILVER) {
            ratio = SILVER_RATIO;
        } else if (tier == BRONZE) {
            ratio = BRONZE_RATIO;
        } else {
            ratio = NO_NFT_RATIO;
        }
        return (borrowAmount * ratio) / 10000;
    }

    receive() external payable {}
}