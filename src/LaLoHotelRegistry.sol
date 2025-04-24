// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "./LaLoTokenFactory.sol";
import {LaLoToken} from "./LaLoToken.sol";
import {LaLoVault} from "./LaLoVault.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol"; // Import the interface

contract LaLoHotelRegistry is IHotelRegistry {
    error USDCTransferFailed();

    event TokensBought(uint256 indexed hotelId, address indexed buyer, uint256 amount);
    
    IERC20 public usdcToken;
    LaLoTokenFactory public tokenFactory;

    // Mapping of hotel ID to Hotel data
    mapping(uint256 => Hotel) public hotels;
    
    // Mapping to track whether a hotel ID is a registered hotel
    mapping(uint256 => bool) public isRegisteredHotel; 

    // Counter for hotel IDs
    uint256 public nextHotelId;

    // Constructor that accepts the LaLoTokenFactory address
    constructor(address _tokenFactory, address _usdcToken) {
        tokenFactory = LaLoTokenFactory(_tokenFactory);
        usdcToken = IERC20(_usdcToken);
    }

    // Implementing the interface function to check if a hotel is registered by hotelId
    function isHotelRegistered(uint256 hotelId) external view override returns (bool) {
        return isRegisteredHotel[hotelId];
    }

    // Function to register a hotel
    function registerHotel(string memory name, string memory location, uint256 tokenAmount) public {
        // Deploy a new LaLoToken for this hotel
        address tokenAddress = tokenFactory.deployToken(tokenAmount);

        // Deploy a new LaLoVault for this hotel
        address vaultAddress = address(new LaLoVault(
            address(usdcToken),
            tokenAddress
        ));

        // Create a new hotel entry
        hotels[nextHotelId] = Hotel({
            name: name,
            location: location,
            tokenAddress: tokenAddress,
            vaultAddress: vaultAddress,
            registrationDate: block.timestamp
        });

        // Mark the hotel as registered
        isRegisteredHotel[nextHotelId] = true;

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
