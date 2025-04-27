// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelRegistry {
    error InvalidSellingRate(
        uint256 tokenAmount,
        uint256 usdcPrice
    );
    error HotelNotRegistered();
    error UnauthorizedHotelOwner();

    event HotelRegistered(uint256 hotelId, string name, string location, address tokenAddress);

    struct Hotel {
        address owner;
        string name;
        string location;
        address tokenAddress;
        address vaultAddress;
        uint256 registrationDate;
    }
}
