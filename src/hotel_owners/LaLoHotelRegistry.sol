// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol"; // Import the interface

contract LaLoHotelRegistry is IHotelRegistry {
    IERC20 public usdcToken;
    LaLoTokenFactory public tokenFactory;

    // Mapping of hotel ID to Hotel data
    mapping(uint256 => Hotel) public hotels;
    
    // Mapping to track whether a hotel ID is a registered hotel
    mapping(uint256 => bool) public isRegisteredHotel; 

    // Counter for hotel IDs
    uint256 public nextHotelId;

    // Constructor that accepts the LaLoTokenFactory address
    constructor(address _usdcToken, address _tokenFactory) {
        usdcToken = IERC20(_usdcToken);
        tokenFactory = LaLoTokenFactory(_tokenFactory);
    }

    // Implementing the interface function to check if a hotel is registered by hotelId
    function isHotelRegistered(uint256 _hotelId) external view returns (bool) {
        return isRegisteredHotel[_hotelId];
    }

    // Function to register a hotel
    function registerHotel(
        string memory _name,
        string memory _location,
        uint256 _tokenAmount,
        uint256 _usdcPrice,
        uint256 _totalMonth
    ) public {
        // Ignore if either tokenAmount or usdcPrice is zero
        if (_tokenAmount == 0 || _usdcPrice == 0) revert ZeroAmount();

        // Check if the rate is valid
        uint256 ratio = 1e6;
        uint256 rate = _tokenAmount * ratio / _usdcPrice;
        if (rate < ratio) revert InvalidSellingRate(
            _tokenAmount,
            _usdcPrice
        );

        // Deploy a new LaLoVault for this hotel
        address vaultAddress = address(new LaLoVault(
            address(usdcToken),
            tokenFactory,
            _tokenAmount,
            msg.sender,
            rate,
            ratio,
            _totalMonth,
            _tokenAmount
        ));

        // Create a new hotel entry
        hotels[nextHotelId] = Hotel({
            owner: msg.sender,
            name: _name,
            location: _location,
            vaultAddress: vaultAddress,
            registrationDate: block.timestamp
        });

        // Mark the hotel as registered
        isRegisteredHotel[nextHotelId] = true;

        // Emit the HotelRegistered event
        emit HotelRegistered(nextHotelId, _name, _location, vaultAddress);

        // Increment the hotel ID for the next hotel
        nextHotelId++;
    }

    // Function to get hotel address
    function getVaultAddress(uint256 _hotelId) external view returns (address) {
        return hotels[_hotelId].vaultAddress;
    }
}
