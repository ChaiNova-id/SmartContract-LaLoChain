// SPX License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface ILaLoAVS {
    error UnauthorizedCaller();
    error InvalidHotel();
    error InsufficientStake();
    error InvalidUnderwriter();
    error AlreadyFulfilled();

    event UnderwriterRegistered(address indexed underwriter, uint256 indexed hotelId, uint256 stakeAmount);
    event RevenueUnderwriterActivated(address indexed underwriter, uint256 indexed hotelId, uint256 stakeAmount);
    event TokenSaleUnderwriterActivated(address indexed underwriter, uint256 indexed hotelId, uint256 stakeAmount);
    event RevenueGuaranteeTriggered(uint256 indexed hotelId, uint256 amount);
    event TokenSaleGuaranteeTriggered(uint256 indexed hotelId, uint256 amount);
    event UnderwriterRewardsDistributed(uint256 indexed hotelId, uint256 amount);
}