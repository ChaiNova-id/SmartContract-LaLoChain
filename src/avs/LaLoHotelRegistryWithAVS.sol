// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoAVS} from "./LaLoAVS.sol";
import {LaLoUnderwriterRegistry} from "../underwriter/LaLoUnderwriterRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";

contract LaLoHotelRegistryWithAVS is LaLoHotelRegistry {
    LaLoAVS public avsSystem;
    LaLoUnderwriterRegistry public underwriterRegistry;

    event HotelRegisteredWithAVS(uint256 indexed hotelId, uint256 revenueStake, uint256 saleStake, uint256 underwriterFee);

    constructor(
        address _usdcToken,
        address _tokenFactory,
        address _avsSystem,
        address _underwriterRegistry
    ) LaLoHotelRegistry(_usdcToken, _tokenFactory) {
        avsSystem = LaLoAVS(_avsSystem);
        underwriterRegistry = LaLoUnderwriterRegistry(_underwriterRegistry);
    }

    /**
     * @dev Register a hotel with AVS support
     * @param _name Hotel name
     * @param _tokenAmount Initial token amount
     * @param _usdcPrice USDC price
     * @param _totalMonth Total months for revenue
     * @param _auctionDuration Duration of token sale auction
     * @param _requiredRevenueStake Required stake for revenue guarantee
     * @param _requiredSaleStake Required stake for token sales guarantee
     * @param _underwriterFee Fee paid to underwriters
     */
    function registerHotelWithAVS(
        string memory _name,
        uint256 _tokenAmount,
        uint256 _usdcPrice,
        uint256 _totalMonth,
        uint256 _auctionDuration,
        uint256 _requiredRevenueStake,
        uint256 _requiredSaleStake,
        uint256 _underwriterFee
    ) public {
        // First register the hotel normally
        super.registerHotel(_name, _tokenAmount, _usdcPrice, _totalMonth, _auctionDuration);
        
        // Get the hotel ID (it was incremented in the registerHotel function)
        uint256 hotelId = nextHotelId - 1;
        
        // Create AVS for this hotel
        avsSystem.createAVS(hotelId, _requiredRevenueStake, _requiredSaleStake, _underwriterFee);
        
        emit HotelRegisteredWithAVS(hotelId, _requiredRevenueStake, _requiredSaleStake, _underwriterFee);
    }

    /**
     * @dev Check if hotel has active underwriters
     * @param _hotelId ID of the hotel
     * @return hasRevenue Whether hotel has revenue underwriters
     * @return hasSale Whether hotel has sale underwriters
     */
    function hasActiveUnderwriters(uint256 _hotelId) external view returns (bool hasRevenue, bool hasSale) {
        hasRevenue = avsSystem.hasActiveRevenueUnderwriters(_hotelId);
        hasSale = avsSystem.hasActiveSaleUnderwriters(_hotelId);
    }
}