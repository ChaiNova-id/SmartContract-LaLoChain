// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHotelRegistry {
    event HotelRegistered(uint256 hotelId, string name, string location, address tokenAddress);

    struct Hotel {
        string name;
        string location;
        address tokenAddress;
        uint256 registrationDate;
    }

    // Change the method signature to accept hotelId
    function isHotelRegistered(uint256 hotelId) external view returns (bool);
    
    function registerHotel(string memory name, string memory location, uint256 tokenAmount) external;
    
    function getHotel(uint256 hotelId) external view returns (Hotel memory);
}
