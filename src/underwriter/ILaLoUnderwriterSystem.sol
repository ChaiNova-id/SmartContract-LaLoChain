// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface ILaLoUnderwriterSystem {
    // Errors
    error NotHotelOwner();
    error UnsupportedHotelId();
    error InsufficientUnderwriterStake();
    error NoActiveUnderwriter();
    error UnauthorizedUnderwriter();
    error NotEnoughUnderwriters();
    error NotEnoughStake();
    error UnderwriterAlreadyAssigned();
    error InvalidStakeAmount();
    error NotEnoughStakeForClaim();
    error NotAllowedToWithdraw();
    error TransferFailed();
    error ClaimPeriodExpired();
    error ProtocolFeeChangeTooHigh();
    error NotAdmin();

    // Events
    event UnderwriterRegistered(address indexed underwriter, uint256 stake);
    event UnderwriterAssigned(uint256 indexed hotelId, address indexed underwriter, uint256 stake);
    event UnderwriterClaim(uint256 indexed hotelId, address indexed underwriter, uint256 claimAmount);
    event UnderwriterWithdrawal(address indexed underwriter, uint256 amount);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event HotelUnderwriterFeeDeposited(uint256 indexed hotelId, uint256 amount);
    event UnderwriterFeeClaimed(uint256 indexed hotelId, address indexed underwriter, uint256 amount);
    event RevenueGuaranteePaid(uint256 indexed hotelId, address indexed underwriter, uint256 amount);

    // Structs
    struct UnderwriterInfo {
        uint256 totalStake;
        uint256 availableStake;
        uint256 lockedStake;
    }

    struct HotelUnderwriting {
        address[] underwriters;
        mapping(address => uint256) stakes;
        uint256 totalStake;
        uint256 underwriterFee;
        uint256 totalPromisedRevenue;
        uint256 endDate;
        bool isActive;
        bool isFeeDistributed;
    }
}