// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IHotelRegistry} from './IHotelRegistry.sol';
import {LaLoVault} from './LaLoVault.sol';

// Define custom errors outside the contract
error HotelNotRegistered();
error RoomNotAvailable();
error InvalidNights();
error PaymentFailed();
error WithdrawFailed();
error UnauthorizedRoomOwner();

contract LaLoHotelBook is Ownable {
    struct Room {
        uint256 pricePerNight; // in mUSDC (decimals assumed to be handled off-chain)
        bool isAvailable;
    }

    struct Booking {
        address guest;
        uint256 nights;
        uint256 totalPaid;
        uint256 timestamp;
    }

    IERC20 public immutable usdcToken; // mUSDC
    IHotelRegistry public hotelRegistry;

    uint256 public nextRoomId;
    mapping(uint256 => Room) public rooms;
    mapping(uint256 => Booking[]) public roomBookings;
    mapping(uint256 => uint256) public roomToHotel; // Maps roomId to hotelId

    event RoomListed(uint256 roomId, uint256 price);
    event RoomBooked(uint256 roomId, address guest, uint256 nights, uint256 totalPaid);

    constructor(address _usdcToken, address _hotelRegistry) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    modifier onlyRegisteredHotel(uint256 hotelId) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered(); // Use the custom error
        }
        _;
    }

    // Function to list a room by a registered hotel owner
    function listRoom(uint256 hotelId, uint256 pricePerNight) external onlyRegisteredHotel(hotelId) {
        rooms[nextRoomId] = Room(pricePerNight, true);
        roomToHotel[nextRoomId] = hotelId;  // Associate the room with the hotel ID
        emit RoomListed(nextRoomId, pricePerNight);
        nextRoomId++;
    }

    // Function to update room availability, only by the hotel owner
    function updateRoomAvailability(uint256 roomId, uint256 hotelId, bool availability) external {
        if (roomToHotel[roomId] != hotelId) {
            revert UnauthorizedRoomOwner(); // Ensure the room belongs to the caller's hotel
        }

        rooms[roomId].isAvailable = availability;
    }

    // Function to book a room
    function bookRoom(uint256 roomId, uint256 nights) external {
        Room memory room = rooms[roomId];
        if (!room.isAvailable) revert RoomNotAvailable();
        if (nights == 0) revert InvalidNights();

        uint256 totalCost = room.pricePerNight * nights;
        uint256 hotelId = roomToHotel[roomId];

        // Get Vault from HotelRegistry
        IHotelRegistry.Hotel memory hotel = hotelRegistry.getHotel(hotelId);
        address vault = hotel.vaultAddress;

        // Set the booker if not already set
        try LaLoVault(vault).setBooker(address(this)) {
            // success or already set
        } catch {
            // Ignore if already set or not allowed
        }

        // Transfer booking fee to Vault
        LaLoVault(vault).depositYield(msg.sender, totalCost);

        // Record the booking
        roomBookings[roomId].push(Booking(msg.sender, nights, totalCost, block.timestamp));
        emit RoomBooked(roomId, msg.sender, nights, totalCost);
    }

    // Function to get all bookings for a specific room
    function getBookingsForRoom(uint256 roomId) external view returns (Booking[] memory) {
        return roomBookings[roomId];
    }

    // Function to withdraw earnings to a specified address
    function withdrawEarnings(address to, uint256 amount) external onlyOwner {
        if (!usdcToken.transfer(to, amount)) {
            revert WithdrawFailed(); // Use the custom error
        }
    }

    function getVaultAddress(uint256 hotelId) external view returns (address) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }

        return hotelRegistry.getHotel(hotelId).vaultAddress;
    }
}
