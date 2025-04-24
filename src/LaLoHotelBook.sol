// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IHotelRegistry} from './IHotelRegistry.sol';

// Define custom errors outside the contract
error HotelNotRegistered();
error RoomNotAvailable();
error InvalidNights();
error PaymentFailed();
error WithdrawFailed();

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

    IERC20 public immutable paymentToken; // mUSDC
    IHotelRegistry public hotelRegistry;

    uint256 public nextRoomId;
    mapping(uint256 => Room) public rooms;
    mapping(uint256 => Booking[]) public roomBookings;

    event RoomListed(uint256 roomId, uint256 price);
    event RoomBooked(uint256 roomId, address guest, uint256 nights, uint256 totalPaid);

    constructor(address _paymentToken, address _hotelRegistry) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    modifier onlyRegisteredHotel() {
        if (!hotelRegistry.isHotelRegistered(msg.sender)) {
            revert HotelNotRegistered(); // Use the custom error
        }
        _;
    }

    function listRoom(uint256 pricePerNight) external onlyRegisteredHotel {
        rooms[nextRoomId] = Room(pricePerNight, true);
        emit RoomListed(nextRoomId, pricePerNight);
        nextRoomId++;
    }

    function updateRoomAvailability(uint256 roomId, bool availability) external onlyRegisteredHotel {
        rooms[roomId].isAvailable = availability;
    }

    function bookRoom(uint256 roomId, uint256 nights) external {
        Room memory room = rooms[roomId];
        if (!room.isAvailable) {
            revert RoomNotAvailable(); // Use the custom error
        }
        if (nights <= 0) {
            revert InvalidNights(); // Use the custom error
        }

        uint256 totalCost = room.pricePerNight * nights;
        if (!paymentToken.transferFrom(msg.sender, address(this), totalCost)) {
            revert PaymentFailed(); // Use the custom error
        }

        roomBookings[roomId].push(Booking(msg.sender, nights, totalCost, block.timestamp));

        emit RoomBooked(roomId, msg.sender, nights, totalCost);
    }

    function getBookingsForRoom(uint256 roomId) external view returns (Booking[] memory) {
        return roomBookings[roomId];
    }

    function withdrawEarnings(address to, uint256 amount) external onlyOwner {
        if (!paymentToken.transfer(to, amount)) {
            revert WithdrawFailed(); // Use the custom error
        }
    }
}
