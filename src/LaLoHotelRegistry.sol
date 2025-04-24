// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LaLoTokenFactory} from "./LaLoTokenFactory.sol";
import {LaLoToken} from "./LaLoToken.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol"; // Import the interface

contract LaLoHotelRegistry is IHotelRegistry {

    LaLoTokenFactory public tokenFactory;

    // Mapping of hotel ID to Hotel data
    mapping(uint256 => Hotel) public hotels;
    
    // Mapping to track whether an address is a registered hotel owner
    mapping(address => bool) public isRegisteredHotelOwner; 

    // Counter for hotel IDs
    uint256 public nextHotelId;

    // Constructor that accepts the LaLoTokenFactory address
    constructor(address _tokenFactory) {
        tokenFactory = LaLoTokenFactory(_tokenFactory);
    }

    // Implementing the interface function to check if hotel is registered
    function isHotelRegistered(address hotelOwner) external view override returns (bool) {
        return isRegisteredHotelOwner[hotelOwner];
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

        // Mark the sender's address as a registered hotel owner
        isRegisteredHotelOwner[msg.sender] = true;

        // Emit the HotelRegistered event
        emit HotelRegistered(nextHotelId, name, location, tokenAddress);

        // Increment the hotel ID for the next hotel
        nextHotelId++;
    }

    // Function to get hotel details by hotel ID
    function getHotel(uint256 hotelId) external view returns (Hotel memory) {
        return hotels[hotelId];
    }
}
