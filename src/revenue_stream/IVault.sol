// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {
    error InsufficientHotelToken();
    error InsufficientShares();
    error TransferFailed();
    error NotBooker(address sender);
}