// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol";
import {IRoomRegistry} from "./IRoomRegistry.sol";

contract LaLoHotelRoomRegistry is Ownable, IRoomRegistry {
    IHotelRegistry public hotelRegistry;
    uint256 public nextRoomId;

    mapping(uint256 => Room) public rooms;
    mapping(uint256 => uint256) public roomToHotel; // roomId -> hotelId

    constructor(address _hotelRegistry) Ownable(msg.sender) {
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    // Internal helper to fetch and validate hotelId from roomId
    function _getHotelIdFromRoom(uint256 roomId) internal view returns (uint256 hotelId) {
        hotelId = roomToHotel[roomId];
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert IHotelRegistry.HotelNotRegistered();
        }
    }

    // Internal helper to validate hotel ownership
    function _assertHotelOwner(uint256 hotelId) internal view {
        if (msg.sender != hotelRegistry.getHotel(hotelId).owner) {
            revert IHotelRegistry.UnauthorizedHotelOwner();
        }
    }

    modifier onlyHotelOwner(uint256 hotelId) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert IHotelRegistry.HotelNotRegistered();
        }
        _assertHotelOwner(hotelId);
        _;
    }

    modifier onlyHotelOwnerByRoom(uint256 roomId) {
        uint256 hotelId = _getHotelIdFromRoom(roomId);
        _assertHotelOwner(hotelId);
        _;
    }

    // Create new room
    function listRoom(uint256 hotelId, uint256 pricePerNight) external onlyHotelOwner(hotelId) {
        rooms[nextRoomId] = Room(pricePerNight, true);
        roomToHotel[nextRoomId] = hotelId;
        emit RoomListed(nextRoomId, pricePerNight);
        nextRoomId++;
    }

    // Update room availability
    function updateRoomAvailability(uint256 roomId, bool availability) external onlyHotelOwnerByRoom(roomId) {
        rooms[roomId].isAvailable = availability;
        emit RoomAvailabilityUpdated(roomId, availability);
    }

    // Update room price
    function updateRoomPrice(uint256 roomId, uint256 newPricePerNight) external onlyHotelOwnerByRoom(roomId) {
        rooms[roomId].pricePerNight = newPricePerNight;
        emit RoomPriceUpdated(roomId, newPricePerNight);
    }

    // Viewer Functions
    function getRoom(uint256 roomId) external view returns (Room memory) {
        return rooms[roomId];
    }

    function getHotelIdOfRoom(uint256 roomId) external view returns (uint256 hotelId) {
        return roomToHotel[roomId];
    }
}
