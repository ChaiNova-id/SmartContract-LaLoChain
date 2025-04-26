// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHotelRegistry} from "../hotel_owners/IHotelRegistry.sol";
import {IRoomRegistry} from "../hotel_owners/IRoomRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {IHotelBook} from "./IHotelBook.sol";

contract LaLoHotelBook is Ownable, IHotelBook {
    IERC20 public immutable usdcToken;
    IHotelRegistry public hotelRegistry;
    IRoomRegistry public roomRegistry;

    mapping(uint256 => Booking[]) public roomBookings;

    constructor(address _usdcToken, address _hotelRegistry, address _roomRegistry) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = IHotelRegistry(_hotelRegistry);
        roomRegistry = IRoomRegistry(_roomRegistry);
    }

    function bookRoom(uint256 roomId, uint256 nights) external {
        IRoomRegistry.Room memory room = roomRegistry.getRoom(roomId);
        if (!room.isAvailable) revert RoomNotAvailable();
        if (nights == 0) revert InvalidNights();

        uint256 totalCost = room.pricePerNight * nights;
        uint256 hotelId = roomRegistry.getHotelIdOfRoom(roomId);

        // Get Vault address from HotelRegistry
        IHotelRegistry.Hotel memory hotel = hotelRegistry.getHotel(hotelId);
        address vault = hotel.vaultAddress;

        // Transfer booking fee
        LaLoVault(vault).depositYield(msg.sender, totalCost);

        // Record booking
        roomBookings[roomId].push(Booking(msg.sender, nights, totalCost, block.timestamp));
        emit RoomBooked(roomId, msg.sender, nights, totalCost);
    }

    // History
    function getBookingsForRoom(uint256 roomId) external view returns (Booking[] memory) {
        return roomBookings[roomId];
    }

    function getVaultAddress(uint256 hotelId) external view returns (address) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert IHotelRegistry.HotelNotRegistered();
        }
        return hotelRegistry.getHotel(hotelId).vaultAddress;
    }
}
