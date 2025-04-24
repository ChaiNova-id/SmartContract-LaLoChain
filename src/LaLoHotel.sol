// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LaLoTokenFactory} from "./LaLoTokenFactory.sol";
import {LaLoToken} from "./LaLoToken.sol";

contract LaLoHotel {

    LaLoTokenFactory public tokenFactory;
    
    // Struct to store hotel information
    struct Hotel {
        string name;
        string location;
        address tokenAddress;
        uint256 registrationDate;
    }

    // Mapping of hotel ID to Hotel data
    mapping(uint256 => Hotel) public hotels;

    // Event to emit when a hotel is registered
    event HotelRegistered(uint256 hotelId, string name, string location, address tokenAddress);

    // Counter for hotel IDs
    uint256 public nextHotelId;

    // Constructor that accepts the LaLoTokenFactory address
    constructor(address _tokenFactory) {
        tokenFactory = LaLoTokenFactory(_tokenFactory);
    }

    // Function to register a hotel
    function registerHotel(string memory name, string memory location, uint256 tokenAmount) public {
        // Deploy a new LaLoToken for this hotel
        address tokenAddress = tokenFactory.deployToken(tokenAmount);

        // Create a new hotel entry
        hotels[nextHotelId] = Hotel({
            name: name,
            location: location,
            tokenAddress: tokenAddress,
            registrationDate: block.timestamp
        });

        // Emit the HotelRegistered event
        emit HotelRegistered(nextHotelId, name, location, tokenAddress);

        // Increment the hotel ID for the next hotel
        nextHotelId++;
    }

    // Function to get hotel details by hotel ID
    function getHotel(uint256 hotelId) public view returns (Hotel memory) {
        return hotels[hotelId];
    }
}
