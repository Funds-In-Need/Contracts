// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IChronicle {
    function read() external view returns (uint256 value);
    function readWithAge() external view returns (uint256 value, uint256 age);
}

interface IERC1155Burnable is IERC1155 {
    function burn(address account, uint256 id, uint256 value) external;
}

interface ISelfKisser {
    function selfKiss(address oracle) external;
}

contract CreditBorrowing {

    ERC1155Burnable public creditNFT;
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
        address _creditNFT,
        address _chronicle,
        address _selfKisser
    ) {
        creditNFT = ERC1155Burnable(_creditNFT);
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
        if (creditNFT.balanceOf(msg.sender, GOLD) > 0) {
            tier = GOLD;
        } else if (creditNFT.balanceOf(msg.sender, SILVER) > 0) {
            tier = SILVER;
        } else if (creditNFT.balanceOf(msg.sender, BRONZE) > 0) {
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

    // Modified repay function to accept a repayment amount
    function repayLoan(uint256 repaymentAmount) public payable {
        BorrowerInfo storage borrower = borrowers[msg.sender];
        require(borrower.hasActiveLoan, "No active loan");
        require(repaymentAmount > 0, "Repayment amount must be greater than 0");
        require(msg.value == repaymentAmount, "Sent ETH amount does not match repayment amount");

        // Ensure repayment is not greater than the borrowed amount
        require(repaymentAmount <= borrower.borrowedAmount, "Repayment exceeds borrowed amount");

        // Reduce the borrowed amount by the repayment amount
        borrower.borrowedAmount -= repaymentAmount;

        // If the loan is fully repaid, clear the loan data and return collateral
        if (borrower.borrowedAmount == 0) {
            uint256 nftTier = borrower.nftTier;
            uint256 collateralToReturn = borrower.collateralAmount;

            // Clear borrower data
            borrower.hasActiveLoan = false;
            borrower.hasCollateral = false;
            borrower.collateralAmount = 0;
            borrower.collateralValueUSD = 0;

            // Burn NFT if user has one
            if (nftTier != 999) {
                uint256 nftBalance = creditNFT.balanceOf(msg.sender, nftTier);
                if (nftBalance > 0) {
                    creditNFT.burn(msg.sender, nftTier, 1);
                }
            }

            // Return collateral
            (bool success, ) = payable(msg.sender).call{value: collateralToReturn}("");
            require(success, "Collateral return failed");

            // Emit full loan repayment event
            emit LoanRepaid(msg.sender, repaymentAmount);
        } else {
            // Emit partial loan repayment event
            emit LoanRepaid(msg.sender, repaymentAmount);
        }
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

    // Function to get maximum borrowable amount for a user
    function getMaxBorrowableAmount(address user) public view returns (uint256 maxBorrowableUSD, uint256 maxBorrowableETH) {
        BorrowerInfo memory borrower = borrowers[user];
        require(borrower.hasCollateral, "No collateral deposited");

        // Get current collateral value in USD
        uint256 currentCollateralUSD = getCurrentCollateralValue(user);
        
        // Determine user's tier
        uint256 tier = 999; // Default to no NFT
        if (creditNFT.balanceOf(user, GOLD) > 0) {
            tier = GOLD;
        } else if (creditNFT.balanceOf(user, SILVER) > 0) {
            tier = SILVER;
        } else if (creditNFT.balanceOf(user, BRONZE) > 0) {
            tier = BRONZE;
        }

        // Calculate ratio based on tier
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

        // Calculate max borrowable amount in USD
        // maxBorrowableUSD = collateralValueUSD * 10000 / ratio
        maxBorrowableUSD = (currentCollateralUSD * 10000) / ratio;

        // Convert USD to ETH
        uint256 ethPrice = getEthPrice();
        maxBorrowableETH = (maxBorrowableUSD * 1e18) / ethPrice;

        // Check if there's enough ETH in the pool
        if (maxBorrowableETH > address(this).balance) {
            maxBorrowableETH = address(this).balance;
            maxBorrowableUSD = calculateUSDValue(maxBorrowableETH);
        }

        return (maxBorrowableUSD, maxBorrowableETH);
    }
}