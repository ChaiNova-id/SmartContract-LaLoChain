// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelRegistry {
    // Struct to store hotel information
    struct Hotel {
        string name;
        string location;
        address tokenAddress;
        uint256 registrationDate;
    }

    // Function to check if a hotel is registered based on the hotel owner's address
    function isHotelRegistered(address hotelOwner) external view returns (bool);

    // Optionally, you can add other functions like getting hotel details by ID
    function getHotel(uint256 hotelId) external view returns (Hotel memory);

    // Event to notify when a hotel is registered
    event HotelRegistered(uint256 hotelId, string name, string location, address tokenAddress);
}
