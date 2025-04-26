// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelBook {
    error RoomNotAvailable();
    error InvalidNights();
    
    struct Booking {
        address guest;
        uint256 nights;
        uint256 totalPaid;
        uint256 timestamp;
    }

    event RoomBooked(uint256 roomId, address guest, uint256 nights, uint256 totalPaid);
}