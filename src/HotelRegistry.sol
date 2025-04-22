// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IRevenueTokenFactory {
    function createToken(uint256 hotelId) external returns (address);
}

contract HotelRegistry is AccessControl, Pausable {
    bytes32 public constant OVERWRITER_ROLE = keccak256("OVERWRITER_ROLE");

    enum Status { Pending, Approved, Rejected }

    struct Hotel {
        address owner;
        uint256 stake;
        Status status;
    }

    error InsufficientStake(uint256 sent, uint256 required);
    error HotelNotPending(uint256 hotelId);
    error HotelNotRejected(uint256 hotelId);
    error NotHotelOwner(address caller);
    error HotelNotApproved(uint256 hotelId);
    error ZeroValueBooking();

    uint256 public hotelCount;
    mapping(uint256 => Hotel) public hotels;
    mapping(uint256 => address) public hotelToToken;

    uint256 public requiredStake = 1 ether;
    IRevenueTokenFactory public tokenFactory;

    event HotelRegistered(uint256 indexed hotelId, address indexed owner);
    event HotelApproved(uint256 indexed hotelId, address tokenAddress);
    event HotelRejected(uint256 indexed hotelId);
    event HotelBooked(uint256 indexed hotelId, address indexed user, uint256 value);

    constructor(address _tokenFactory) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OVERWRITER_ROLE, msg.sender);
        tokenFactory = IRevenueTokenFactory(_tokenFactory);
    }

    function registerHotel() external payable whenNotPaused {
        if (msg.value < requiredStake) {
            revert InsufficientStake(msg.value, requiredStake);
        }

        uint256 hotelId = hotelCount++;
        hotels[hotelId] = Hotel(msg.sender, msg.value, Status.Pending);

        emit HotelRegistered(hotelId, msg.sender);
    }

    function approveHotel(uint256 hotelId) external onlyRole(OVERWRITER_ROLE) {
        Hotel storage h = hotels[hotelId];
        if (h.status != Status.Pending) {
            revert HotelNotPending(hotelId);
        }

        h.status = Status.Approved;

        address token = tokenFactory.createToken(hotelId);
        hotelToToken[hotelId] = token;

        emit HotelApproved(hotelId, token);
    }

    function rejectHotel(uint256 hotelId) external onlyRole(OVERWRITER_ROLE) {
        Hotel storage h = hotels[hotelId];
        if (h.status != Status.Pending) {
            revert HotelNotPending(hotelId);
        }

        h.status = Status.Rejected;

        emit HotelRejected(hotelId);
    }

    function withdrawStake(uint256 hotelId) external {
        Hotel storage h = hotels[hotelId];
        if (h.status != Status.Rejected) {
            revert HotelNotRejected(hotelId);
        }
        if (msg.sender != h.owner) {
            revert NotHotelOwner(msg.sender);
        }

        uint256 stake = h.stake;
        h.stake = 0;
        payable(msg.sender).transfer(stake);
    }

    function getHotelStatus(uint256 hotelId) external view returns (Status) {
        return hotels[hotelId].status;
    }

    function bookHotel(uint256 hotelId) external payable whenNotPaused {
        Hotel storage h = hotels[hotelId];
        if (h.status != Status.Approved) {
            revert HotelNotApproved(hotelId);
        }
        if (msg.value == 0) {
            revert ZeroValueBooking();
        }

        emit HotelBooked(hotelId, msg.sender, msg.value);
    }

    function pauseContract() external onlyRole(OVERWRITER_ROLE) {
        _pause();
    }

    function unpauseContract() external onlyRole(OVERWRITER_ROLE) {
        _unpause();
    }
}
