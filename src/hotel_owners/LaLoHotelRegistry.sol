// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol"; // Import the interface
import {LaLoUnderwriterSystem} from "../underwriter/LaLoUnderwriterSystem.sol";
import {LaLoHotelAVS} from "../avs/LaLoHotelAVS.sol";

contract LaLoHotelRegistry is IHotelRegistry {
    IERC20 public usdcToken;
    LaLoTokenFactory public tokenFactory;
    LaLoUnderwriterSystem public underwriterSystem;
    address public admin;

    // Mapping of hotel ID to Hotel data
    mapping(uint256 => Hotel) public hotels;

    // Mapping to track whether a hotel ID is a registered hotel
    mapping(uint256 => bool) public isRegisteredHotel;

    //Mapping to track hotel AVS addresses
    mapping(uint256 => address) public hotelAVS;

    // Counter for hotel IDs
    uint256 public nextHotelId;

    // Events
    event HotelAVSCreated(uint256 indexed hotelId, address avsAddress);
    event underwriterSystemUpdated(address oldAddress, address newAddress);

    // Constructor that accepts the LaLoTokenFactory address
    constructor(address _usdcToken, address _tokenFactory) {
        usdcToken = IERC20(_usdcToken);
        tokenFactory = LaLoTokenFactory(_tokenFactory);
        admin = msg.sender;
    }

    // Modifier to check if sender is admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    // Set the underwriter system address
    function setUnderwriterSystem(address _underwriterSystem) external onlyAdmin {
        address oldAddress = address(underwriterSystem);
        underwriterSystem = LaLoUnderwriterSystem(_underwriterSystem);
        emit underwriterSystemUpdated(oldAddress, _underwriterSystem);
    }

    // Implementing the interface function to check if a hotel is registered by hotelId
    function isHotelRegistered(uint256 _hotelId) external view returns (bool) {
        return isRegisteredHotel[_hotelId];
    }

    // Function to register a hotel
    function registerHotel(
        string memory _name,
        uint256 _tokenAmount,
        uint256 _usdcPrice,
        uint256 _totalMonth,
        uint256 _auctionDuration
    ) public returns (uint256 hotelId) {
        // Ignore if either tokenAmount or usdcPrice is zero
        if (_tokenAmount == 0 || _usdcPrice == 0) revert ZeroAmount();

        // Check if the rate is valid
        uint256 ratio = 1e18;
        uint256 rate = _tokenAmount * ratio / _usdcPrice;
        if (_usdcPrice > _tokenAmount) revert InvalidSellingRate(_tokenAmount, _usdcPrice);

        // Ensure underwriter system is set
        require(address(underwriterSystem) != address(0), "Underwriter system not set");

        // Deploy a new LaLoVault for this hotel
        address vaultAddress = address(
            new LaLoVault(
                address(usdcToken),
                tokenFactory,
                _tokenAmount,
                msg.sender,
                rate,
                ratio,
                _totalMonth,
                _tokenAmount,
                _auctionDuration
            )
        );

        // Create a new hotel entry
        hotelId = nextHotelId;
        hotels[hotelId] = Hotel({owner: msg.sender, name: _name, vaultAddress: vaultAddress});



        // Mark the hotel as registered
        isRegisteredHotel[hotelId] = true;

        // Create a dedicated AVS for this hotel
        LaLoHotelAVS avs = new LaLoHotelAVS(
            address(usdcToken),
            hotelId,
            address(this),   
            address(underwriterSystem),
            _tokenAmount / _totalMonth,
            msg.sender
        );

        // Store the AVS address in the mapping
        hotelAVS[hotelId] = address(avs);

        // Emit the HotelRegistered event
        emit HotelRegistered(hotelId, _name, vaultAddress);
        emit HotelAVSCreated(hotelId, address(avs));

        // Increment the hotel ID for the next hotel
        nextHotelId++;

        return hotelId;
    }

    // Function to get hotel address
    function getVaultAddress(uint256 _hotelId) external view returns (address) {
        return hotels[_hotelId].vaultAddress;
    }

    // Function to get hotel AVS
    function getHotelAVS(uint256 _hotelId) external view returns (address) {
        return hotelAVS[_hotelId];
    }

    // Function to get hotel owner
    function getHotelOwner(uint256 _hotelId) external view returns (address) {
        return hotels[_hotelId].owner;
    }
}
