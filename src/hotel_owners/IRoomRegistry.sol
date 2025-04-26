// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IRoomRegistry {
    struct Room {
        uint256 pricePerNight; // in mUSDC
        bool isAvailable;
    }

    event RoomListed(uint256 roomId, uint256 price);
    event RoomAvailabilityUpdated(uint256 roomId, bool availability);
    event RoomPriceUpdated(uint256 roomId, uint256 newPricePerNight);

    function listRoom(uint256 hotelId, uint256 pricePerNight) external;
    function updateRoomAvailability(uint256 roomId, bool availability) external;
    function getRoom(uint256 roomId) external view returns (Room memory);
    function getHotelIdOfRoom(uint256 roomId) external view returns (uint256 hotelId);
}