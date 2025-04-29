// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoToken} from "../token_exchange/LaLoToken.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {IVault} from "./IVault.sol";

contract LaLoVault is ERC20, IVault {
    // Currency setup
    IERC20 public immutable usdcToken;
    LaLoToken public immutable lloToken;
    uint256 public immutable rate; // already multiplied by ratio
    uint256 public immutable ratio; // e.g. 1e6
    uint256 public immutable promisedRevenue;
    uint256 public remainingPromisedRevenue;
    mapping(address => uint256) public claimedRevenuesInLLoT;

    // Hotel setup
    uint256 public immutable registrationDate;
    uint256 public immutable auctionDuration;
    uint256 public immutable totalRevenue;
    uint256 public immutable totalMonth;
    uint256 public testPurposesAddingMonth;
    address public owner;

    constructor(
        address _usdcToken,
        LaLoTokenFactory _tokenFactory,
        uint256 _tokenAmount,
        address _owner,
        uint256 _rate,
        uint256 _ratio,
        uint256 _totalMonth,
        uint256 _totalRevenue,
        uint256 _auctionDuration
    ) ERC20("LaLoVault", "LLOV") {
        // Deploy a new LaLoToken for this vault
        address tokenAddress = _tokenFactory.deployToken(_tokenAmount);

        usdcToken = IERC20(_usdcToken);
        lloToken = LaLoToken(tokenAddress);
        owner = _owner;
        rate = _rate;
        ratio = _ratio;
        totalMonth = _totalMonth;
        totalRevenue = _totalRevenue;
        registrationDate = block.timestamp;
        promisedRevenue = _tokenAmount;
        remainingPromisedRevenue = _tokenAmount;
        auctionDuration = _auctionDuration;

        // Test only
        testPurposesAddingMonth = 0;
    }

    modifier onlyOwner(address _sender) {
        if (_sender != owner) revert NotOwner(_sender);
        _;
    }

    function getTransferLimit(address _sender) external view returns (uint256 transferLimit) {
        // Get the user's existing LLoT
        uint256 userLLoT = lloToken.balanceOf(_sender);

        // Get the claimed revenue in LLoT of the user
        uint256 currentClaimedRevenueInLLoT = claimedRevenuesInLLoT[_sender];

        // Get the time passed
        uint256 monthsPassed = (block.timestamp - registrationDate) / 2_592_000; // 30 days

        // Test purposes
        monthsPassed += testPurposesAddingMonth;

        // Max month if monthsPassed is more than totalMonth
        if (monthsPassed > totalMonth) monthsPassed = totalMonth;

        // Calculate the month ratio
        uint256 calcRatio = 1e18;
        uint256 decalcRatio = 1e36;
        uint256 duration = (monthsPassed * calcRatio) / totalMonth; // Prevent cutting

        // Calculate the shares
        uint256 shares = userLLoT * calcRatio / lloToken.totalSupply();

        // Calculate transfer
        transferLimit = (duration * totalRevenue * shares) / decalcRatio - currentClaimedRevenueInLLoT;
    }

    modifier checkTransferLimit(address _sender, uint256 _amount) {
        // Get the user's existing LLoT
        uint256 userLLoT = lloToken.balanceOf(_sender);

        // Get the transfer limit
        uint256 transferLimit = this.getTransferLimit(_sender);

        // Check if the transfer limit is not passed
        if (_amount > transferLimit) {
            revert InsufficientQuota(transferLimit, _amount);
        }

        _;
    }

    modifier notZero(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    // Get token
    function getToken() external view returns (LaLoToken token) {
        return LaLoToken(address(lloToken));
    }

    // Buying shares (in: x usdc => out; (x * rate) lloToken)
    function buyShares(address _sender, uint256 _amount) external notZero(_amount) {
        // Reject if auction duration has passed
        uint256 auctionEnd = registrationDate + auctionDuration;
        if (auctionEnd < block.timestamp) revert ExceedingAuctionDuration(auctionEnd, block.timestamp);

        // Check if the sender has enough usdc
        uint256 laloTokens = lloToken.balanceOf(address(this));
        if (_amount > laloTokens) {
            revert InsufficientStock(laloTokens, _amount);
        }

        // Calculate LLoT to buy
        uint256 lloT = (_amount * rate) / ratio;

        // Check if there's still existing LLoT in the Vault
        uint256 vaultTokens = lloToken.balanceOf(address(this));
        if (lloT > vaultTokens) {
            revert InsufficientStock(vaultTokens, lloT);
        }

        // All validation fulfilled
        bool transferSuccess = usdcToken.transferFrom(_sender, owner, _amount); // Transfer USDC to vault (hotel) owner
        if (!transferSuccess) revert TransferFailed();
        transferSuccess = lloToken.transfer(_sender, lloT); // Transfer LLoT to buyer
        if (!transferSuccess) revert TransferFailed();
    }

    // User claiming from vault (in: x usdc => out: x usdc)
    function withdraw(address _sender, uint256 _amount)
        external
        notZero(_amount)
        checkTransferLimit(_sender, _amount)
    {
        // All validation fulfilled
        claimedRevenuesInLLoT[_sender] += _amount; // Update the user's claim value of LLoT
        bool success = usdcToken.transfer(_sender, _amount); // Transfer USDC to the user
        if (!success) revert TransferFailed();
    }

    // Owner deposit new revenue
    function deposit(address _sender, uint256 _amount) external onlyOwner(_sender) notZero(_amount) {
        // Ensure that the transaction doesn't exceed the remainingPromisedRevenue
        if (_amount > remainingPromisedRevenue) revert ExceedingDeposit(remainingPromisedRevenue, _amount);

        // Check if the transfer succeeds
        bool success = usdcToken.transferFrom(_sender, address(this), _amount);
        if (!success) revert TransferFailed();

        // Reduce remainingPromisedRevenue
        remainingPromisedRevenue -= _amount;
    }

    // Get user balance in llotoken
    function checkBalance(address _sender) external view returns (uint256 llotBalance) {
        return lloToken.balanceOf(_sender);
    }

    // Get available LaLoTokens
    function getAvailableTokens() external view returns (uint256 llotBalance) {
        return lloToken.balanceOf(address(this));
    }

    // Get available revenues
    function getAvailableRevenues() external view returns (uint256 usdcBalance) {
        return usdcToken.balanceOf(address(this));
    }

    // Get promised revenues
    function getPromisedRevenues() external view returns (uint256 promisedRev) {
        return promisedRevenue;
    }

    // Get promised revenues
    function getRemainingPromisedRevenues() external view returns (uint256 remPromisedRev) {
        return remainingPromisedRevenue;
    }

    // Get claimed revenues
    function getClaimedRevenues(address _sender) external view returns (uint256 claimedRev) {
        return claimedRevenuesInLLoT[_sender];
    }

    // Test purposes
    function setTestPurposes(address _sender, uint256 _amount) external onlyOwner(_sender) {
        // Check if the transaction doesn't exceed the total month of current test purposes
        if (_amount > totalMonth) revert ExceedingMonths(totalMonth, _amount);
        testPurposesAddingMonth = _amount;
    }

    function getMonths() external view returns (uint256 month) {
        return testPurposesAddingMonth;
    }
}
