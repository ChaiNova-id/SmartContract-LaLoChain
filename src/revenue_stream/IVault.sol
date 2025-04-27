// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {
    error InsufficientUSDC(uint256 balance, uint256 amount);
    error InsufficientLaLoToken(uint256 balance, uint256 amount);
    error InsufficientStock(uint256 stock, uint256 amount);
    error TransferFailed();
    error NotOwner(address sender);
}