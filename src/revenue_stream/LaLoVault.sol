// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {IVault} from "./IVault.sol";

contract LaLoVault is ERC20, IVault {
    // Currency setup
    IERC20 public immutable usdcToken;
    IERC20 public immutable lloToken;
    uint256 public immutable rate; // already multiplied by ratio
    uint256 public immutable ratio; // e.g. 1e6
    mapping(address => uint256) public claimedRevenuesInLLoT;
    
    // Hotel setup
    uint256 public immutable registrationDate;
    uint256 public immutable totalRevenue;
    uint256 public immutable totalMonth;
    uint256 public testPurposesAddingMonth;
    address public owner;

    constructor(
        address _usdcToken,
        LaLoTokenFactory tokenFactory,
        uint256 tokenAmount,
        address _owner,
        uint256 _rate,
        uint256 _ratio,
        uint256 _totalMonth,
        uint256 _totalRevenue
    )
        ERC20("LaLoVault", "LLOV")
    {
        // Deploy a new LaLoToken for this vault
        address tokenAddress = tokenFactory.deployToken(tokenAmount);

        usdcToken = IERC20(_usdcToken);
        lloToken = IERC20(tokenAddress);
        owner = _owner;
        rate = _rate;
        ratio = _ratio;
        totalMonth = _totalMonth;
        totalRevenue = _totalRevenue;
        registrationDate = block.timestamp;
        testPurposesAddingMonth = 0;
    }

    modifier onlyOwner(address sender) {
        if(sender != owner) revert NotOwner(sender);
        _;
    }

    function getTransferLimit(address sender) external view returns (uint256 transferLimit) {
        // Get the user's existing LLoT
        uint256 userLLoT = lloToken.balanceOf(sender);
        
        // Get the claimed revenue in LLoT of the user
        uint256 currentClaimedRevenueInLLoT = claimedRevenuesInLLoT[sender];

        // Get the time passed
        uint256 monthsPassed = (block.timestamp - registrationDate) / 2_592_000; // 30 days

        // Test purposes
        monthsPassed += testPurposesAddingMonth;

        // Calculate the month ratio
        uint256 monthRatio = 1e6;
        uint256 duration = (monthsPassed * monthRatio) / totalMonth; // Prevent cutting

        // Calculate the shares
        uint256 shares = userLLoT / lloToken.totalSupply();

        // Calculate transfer
        transferLimit = (duration * totalRevenue * shares) - currentClaimedRevenueInLLoT;
    }

    modifier checkTransferLimit(address sender, uint256 amount) {
        // Get the user's existing LLoT
        uint256 userLLoT = lloToken.balanceOf(sender);

        // Get the transfer limit
        uint256 transferLimit = this.getTransferLimit(sender);

        // Check if the transfer limit is not passed
        if (amount > transferLimit) {
            revert InsufficientLaLoToken(
                userLLoT,
                amount
            );
        }

        _;
    }

    // Get available LaLoTokens
    function getAvailableTokens() external view returns (uint256) {
        return lloToken.balanceOf(address(this));
    }

    // Get available revenues
    function getAvailableRevenues() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    // Buying shares (in: x usdc => out; (x * rate) lloToken)
    function buyShares(address sender, uint256 amount) external {
        // Check if the sender has enough usdc
        uint256 userTokens = usdcToken.balanceOf(sender);
        uint256 usdcTokens = usdcToken.balanceOf(address(this));
        if (amount > usdcTokens) {
            revert InsufficientUSDC(
                userTokens,
                amount
            );
        }

        // Calculate LLoT to buy
        uint256 lloT = (amount * rate) / ratio;
        
        // Check if there's still existing LLoT in the Vault
        uint256 vaultTokens = lloToken.balanceOf(address(this));
        if (lloT > vaultTokens) {
            revert InsufficientStock(
                vaultTokens,
                lloT
            );
        }

        // All validation fulfilled
        usdcToken.transferFrom(sender, owner, amount); // Transfer USDC to vault (hotel) owner
        lloToken.transferFrom(address(this), sender, lloT); // Transfer LLoT to buyer
    }

    // User claiming from vault (in: x usdc => out: x usdc)
    function withdraw(address sender, uint256 amount) external checkTransferLimit(sender, amount) {        
        // All validation fulfilled
        claimedRevenuesInLLoT[sender] += amount;  // Update the user's claim value of LLoT
        bool success = usdcToken.transfer(sender, amount); // Transfer USDC to the user
        if(!success) revert TransferFailed();
    }

    // Owner deposit new revenue
    function deposit(address sender, uint256 amount) external onlyOwner(sender) {
        // Check if the transfer succeeds
        bool success = usdcToken.transferFrom(sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    // Test purposes
    function setTestPurposes(address sender, uint256 _amount) external onlyOwner(sender) {
        testPurposesAddingMonth = _amount;
    }

    function getMonths() external view returns (uint256) {
        return totalMonth + testPurposesAddingMonth;
    }
}
