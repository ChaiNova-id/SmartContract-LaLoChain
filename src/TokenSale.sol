// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error InsufficientAmount(uint256 amount);
error TransferFailed(address from, address to, uint256 amount);
event TokenPurchase(address indexed buyer, uint256 usdcAmount, uint256 laloAmount);

contract TokenSale is Ownable {
    IERC20 public laloToken;
    IERC20 public usdcToken;
    uint256 public rate = 10;

    constructor(address _laloToken, address _usdcToken) Ownable(msg.sender) {
        laloToken = IERC20(_laloToken);
        usdcToken = IERC20(_usdcToken);
    }

    function buyTokens(uint256 usdcAmount) external {
        if (usdcAmount == 0) {
            revert InsufficientAmount(usdcAmount);
        }

        uint256 laloAmount = usdcAmount * rate;

        // Use custom error if the transfer fails
        if (!usdcToken.transferFrom(msg.sender, address(this), usdcAmount)) {
            revert TransferFailed(msg.sender, address(this), usdcAmount);
        }

        if (!laloToken.transfer(msg.sender, laloAmount)) {
            revert TransferFailed(address(this), msg.sender, laloAmount);
        }
    }

    function setRate(uint256 newRate) external onlyOwner {
        rate = newRate;
    }

    function withdrawUSDC(address to, uint256 amount) external onlyOwner {
        if (!usdcToken.transfer(to, amount)) {
            revert TransferFailed(address(this), to, amount);
        }
    }

    function withdrawLALO(address to, uint256 amount) external onlyOwner {
        if (!laloToken.transfer(to, amount)) {
            revert TransferFailed(address(this), to, amount);
        }
    }
}
