// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelRegistry {
    error InvalidSellingRate(uint256 tokenAmount, uint256 usdcPrice);
    error HotelNotRegistered();
    error UnauthorizedHotelOwner();
    error ZeroAmount();

    event HotelRegistered(uint256 hotelId, string name, string location, address vaultAddress);

    struct Hotel {
        address owner;
        string name;
        string location;
        address vaultAddress;
        uint256 registrationDate;
    }
}
