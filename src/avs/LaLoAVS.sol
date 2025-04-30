// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {ILaLoAVS} from "./ILaLoAVS.sol";

contract LaLoAVS is ILaLoAVS {
    IERC20 public usdcToken;
    LaLoHotelRegistry public hotelRegistry;

    struct HotelAVS {
        bool isActive;
        uint256 requiredRevenueStake;
        uint256 requiredSaleStake;
        uint256 totalRevenueStake;
        uint256 totalSaleStake;
        uint256 underwriterFeePool;
        mapping(address => uint256) revenueUnderwriterStakes;
        mapping(address => uint256) saleUnderwriterStakes;
        mapping(address => bool) isRevenueUnderwriter;
        mapping(address => bool) isSaleUnderwriter;
        uint256 revenueUnderwriterCount;
        uint256 saleUnderwriterCount;
    }

    mapping(uint256 => HotelAVS) public hotelAVSystems;

    constructor(address _usdcToken, address _hotelRegistry) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = LaLoHotelRegistry(_hotelRegistry);
    }

    modifier onlyHotelOwner(uint256 _hotelId) {
        if (!hotelRegistry.isRegisteredHotel(_hotelId)) revert InvalidHotel();
        _;
    }

    /**
     * @dev Creates an AVS for a hotel during registration
     * @param _hotelId ID of the hotel
     * @param _requiredRevenueStake Required stake for revenue guarantee
     * @param _requiredSaleStake Required stake for token sales guarantee
     * @param _underwriterFee Fee paid to underwriters
     */
    function createAVS(
        uint256 _hotelId,
        uint256 _requiredRevenueStake,
        uint256 _requiredSaleStake,
        uint256 _underwriterFee
    ) external onlyHotelOwner(_hotelId) {
        HotelAVS storage avs = hotelAVSystems[_hotelId];

        avs.isActive = true;
        avs.requiredRevenueStake = _requiredRevenueStake;
        avs.requiredSaleStake = _requiredSaleStake;
        avs.underwriterFeePool = _underwriterFee;

        // Transfer USDC for underwriter fee
        bool success = usdcToken.transferFrom(msg.sender, address(this), _underwriterFee);
        require(success, "USDC transfer failed");
    }

    /**
     * @dev Register as a revenue underwriter for a hotel
     * @param _hotelId ID of the hotel
     * @param _stakeAmount Amount to stake as guarantee
     */
    function registerAsRevenueUnderwriter(uint256 _hotelId, uint256 _stakeAmount) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();
        if (avs.isRevenueUnderwriter[msg.sender]) revert InvalidUnderwriter();
        if (_stakeAmount < avs.requiredRevenueStake) revert InsufficientStake();

        // Transfer USDC for stake
        bool success = usdcToken.transferFrom(msg.sender, address(this), _stakeAmount);
        require(success, "USDC transfer failed");

        avs.revenueUnderwriterStakes[msg.sender] = _stakeAmount;
        avs.isRevenueUnderwriter[msg.sender] = true;
        avs.totalRevenueStake += _stakeAmount;
        avs.revenueUnderwriterCount++;

        emit RevenueUnderwriterActivated(msg.sender, _hotelId, _stakeAmount);
    }

    /**
     * @dev Register as a token sale underwriter for a hotel
     * @param _hotelId ID of the hotel
     * @param _stakeAmount Amount to stake as guarantee
     */
    function registerAsSaleUnderwriter(uint256 _hotelId, uint256 _stakeAmount) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();
        if (avs.isSaleUnderwriter[msg.sender]) revert InvalidUnderwriter();
        if (_stakeAmount < avs.requiredSaleStake) revert InsufficientStake();

        // Transfer USDC for stake
        bool success = usdcToken.transferFrom(msg.sender, address(this), _stakeAmount);
        require(success, "USDC transfer failed");

        avs.saleUnderwriterStakes[msg.sender] = _stakeAmount;
        avs.isSaleUnderwriter[msg.sender] = true;
        avs.totalSaleStake += _stakeAmount;
        avs.saleUnderwriterCount++;

        emit TokenSaleUnderwriterActivated(msg.sender, _hotelId, _stakeAmount);
    }

    /**
     * @dev Trigger revenue guarantee when monthly revenue is not deposited
     * @param _hotelId ID of the hotel
     * @param _month Month number to enforce
     */
    function triggerRevenueGuarantee(uint256 _hotelId, uint256 _month) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();

        // Get the vault address
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);

        // Check if the month has passed and revenue is still due
        uint256 monthsPassed = (block.timestamp - vault.registrationDate()) / 2_592_000; // 30 days
        require(monthsPassed >= _month, "Month not passed yet");

        // Calculate remaining promised revenue
        // uint256 remainingRevenue = vault.remainingPromisedRevenue();
        uint256 monthlyRevenue = vault.totalRevenue() / vault.totalMonth();

        // Transfer USDC from underwriter pool to vault
        bool success = usdcToken.transfer(vaultAddress, monthlyRevenue);
        require(success, "USDC transfer failed");

        emit RevenueGuaranteeTriggered(_hotelId, monthlyRevenue);
    }

    /**
     * @dev Trigger token sale guarantee when auction period ends without selling all tokens
     * @param _hotelId ID of the hotel
     */
    function triggerTokenSaleGuarantee(uint256 _hotelId) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();

        // Get the vault address
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);

        // Check if auction has ended
        uint256 auctionEnd = vault.registrationDate() + vault.auctionDuration();
        require(block.timestamp > auctionEnd, "Auction still active");

        // Get unsold tokens
        uint256 unsoldTokens = vault.getAvailableTokens();
        require(unsoldTokens > 0, "All tokens sold");

        // Calculate USDC needed to buy all tokens
        uint256 rate = vault.rate();
        uint256 ratio = vault.ratio();
        uint256 usdcNeeded = (unsoldTokens * ratio) / rate;

        // Transfer USDC from underwriter pool to owner
        address owner = vault.owner();
        bool success = usdcToken.transfer(owner, usdcNeeded);
        require(success, "USDC transfer failed");

        // Transfer tokens to sale underwriters proportionally
        // uint256 totalStake = avs.totalSaleStake;

        emit TokenSaleGuaranteeTriggered(_hotelId, usdcNeeded);
    }

    /**
     * @dev Distribute underwriter rewards
     * @param _hotelId ID of the hotel
     */
    function distributeUnderwriterRewards(uint256 _hotelId) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();

        // Get total underwriters
        uint256 totalUnderwriters = avs.revenueUnderwriterCount + avs.saleUnderwriterCount;
        require(totalUnderwriters > 0, "No underwriters");

        // Calculate reward per stake unit
        // uint256 totalStake = avs.totalRevenueStake + avs.totalSaleStake;
        // uint256 rewardPerUnit = avs.underwriterFeePool / totalStake;

        // Mark as distributed
        uint256 distributedAmount = avs.underwriterFeePool;
        avs.underwriterFeePool = 0;

        emit UnderwriterRewardsDistributed(_hotelId, distributedAmount);
    }

    /**
     * @dev Claim rewards for an underwriter
     * @param _hotelId ID of the hotel
     */
    function claimUnderwriterRewards(uint256 _hotelId) external {
        HotelAVS storage avs = hotelAVSystems[_hotelId];
        if (!avs.isActive) revert InvalidHotel();

        // Calculate reward based on stake
        uint256 revenueStake = avs.revenueUnderwriterStakes[msg.sender];
        uint256 saleStake = avs.saleUnderwriterStakes[msg.sender];
        uint256 totalStake = revenueStake + saleStake;

        require(totalStake > 0, "No stake");

        // Calculate share of total stake
        uint256 allStakes = avs.totalRevenueStake + avs.totalSaleStake;
        uint256 share = (totalStake * 1e18) / allStakes;

        // Calculate reward
        uint256 reward = (share * avs.underwriterFeePool) / 1e18;

        // Transfer reward
        bool success = usdcToken.transfer(msg.sender, reward);
        require(success, "USDC transfer failed");
    }

    /**
     * @dev Check if a hotel has active revenue underwriters
     * @param _hotelId ID of the hotel
     * @return active Whether revenue underwriters are active
     */
    function hasActiveRevenueUnderwriters(uint256 _hotelId) external view returns (bool) {
        return hotelAVSystems[_hotelId].revenueUnderwriterCount > 0;
    }

    /**
     * @dev Check if a hotel has active sale underwriters
     * @param _hotelId ID of the hotel
     * @return active Whether sale underwriters are active
     */
    function hasActiveSaleUnderwriters(uint256 _hotelId) external view returns (bool) {
        return hotelAVSystems[_hotelId].saleUnderwriterCount > 0;
    }

    /**
     * @dev Get the total revenue stake for a hotel
     * @param _hotelId ID of the hotel
     * @return stake Total revenue stake
     */
    function getTotalRevenueStake(uint256 _hotelId) external view returns (uint256) {
        return hotelAVSystems[_hotelId].totalRevenueStake;
    }

    /**
     * @dev Get the total sale stake for a hotel
     * @param _hotelId ID of the hotel
     * @return stake Total sale stake
     */
    function getTotalSaleStake(uint256 _hotelId) external view returns (uint256) {
        return hotelAVSystems[_hotelId].totalSaleStake;
    }

    /**
     * @dev Get the underwriter fee pool for a hotel
     * @param _hotelId ID of the hotel
     * @return fee Underwriter fee pool
     */
    function getUnderwriterFeePool(uint256 _hotelId) external view returns (uint256) {
        return hotelAVSystems[_hotelId].underwriterFeePool;
    }
}
