// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {
    error InsufficientUSDC(uint256 balance, uint256 amount);
    error InsufficientQuota(uint256 balance, uint256 amount);
    error InsufficientStock(uint256 stock, uint256 amount);
    error ExceedingDeposit(uint256 limit, uint256 deposit);
    error ExceedingMonths(uint256 totalMonth, uint256 amount);
    error TransferFailed();
    error ZeroAmount();
    error NotOwner(address sender);
}