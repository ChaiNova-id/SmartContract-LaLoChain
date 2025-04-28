// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelTokenization {
    error LLOTTransferFailed();
    error HotelNotRegistered();
    error InsufficientSharesToWithdraw();

    event TokensBought(uint256 indexed hotelId, address indexed buyer, uint256 amount);
    event USDCWithdrawn(uint256 indexed hotelId, address indexed user, uint256 shares);
    event USDCDeposit(uint256 indexed hotelId, address indexed user, uint256 amount);
}
