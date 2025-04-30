// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {ILaLoUnderwriterSystem} from "./ILaLoUnderwriterSystem.sol";

contract LaLoUnderwriterSystem is ILaLoUnderwriterSystem, ReentrancyGuard {
    // State variables
    IERC20 public immutable usdcToken;
    LaLoHotelRegistry public immutable hotelRegistry;
    uint256 public protocolFee; // Percentage expressed as basis points (e.g., 500 = 5%)
    address public admin;

    // Mappings
    mapping(address => UnderwriterInfo) public underwriters;
    mapping(uint256 => HotelUnderwriting) public hotelUnderwritings;
    mapping(address => bool) public isRegisteredUnderwriter;

    // Constants
    uint256 public constant MIN_UNDERWRITERS_PER_HOTEL = 2;
    uint256 public constant MAX_PROTOCOL_FEE = 1000; // Max 10%
    uint256 public constant BASIS_POINTS = 10000; // 100%

    /**
     * @dev Constructor
     * @param _usdcToken Address of the USDC token contract
     * @param _hotelRegistry Address of the LaLoHotelRegistry contract
     */
    constructor(address _usdcToken, address _hotelRegistry) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = LaLoHotelRegistry(_hotelRegistry);
        protocolFee = 500; // Default 5%
        admin = msg.sender;
    }

    /**
     * @dev Modifier to check if sender is admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    /**
     * @dev Update protocol fee
     * @param _newFee New fee in basis points
     */
    function updateProtocolFee(uint256 _newFee) external onlyAdmin {
        if (_newFee > MAX_PROTOCOL_FEE) revert ProtocolFeeChangeTooHigh();
        uint256 oldFee = protocolFee;
        protocolFee = _newFee;
        emit ProtocolFeeUpdated(oldFee, _newFee);
    }

    /**
     * @dev Register as an underwriter by staking USDC
     * @param _stakeAmount Amount of USDC to stake
     */
    function registerAsUnderwriter(uint256 _stakeAmount) external nonReentrant {
        if (_stakeAmount == 0) revert InvalidStakeAmount();
        
        // Transfer USDC from underwriter to contract
        bool success = usdcToken.transferFrom(msg.sender, address(this), _stakeAmount);
        if (!success) revert TransferFailed();
        
        // Update underwriter info
        if (!isRegisteredUnderwriter[msg.sender]) {
            isRegisteredUnderwriter[msg.sender] = true;
            underwriters[msg.sender] = UnderwriterInfo({
                totalStake: _stakeAmount,
                availableStake: _stakeAmount,
                lockedStake: 0
            });
        } else {
            UnderwriterInfo storage info = underwriters[msg.sender];
            info.totalStake += _stakeAmount;
            info.availableStake += _stakeAmount;
        }
        
        emit UnderwriterRegistered(msg.sender, _stakeAmount);
    }

    /**
     * @dev Assigns underwriters to a hotel
     * @param _hotelId Hotel ID
     * @param _underwriterAddresses Array of underwriter addresses
     * @param _stakeAmounts Array of stake amounts corresponding to each underwriter
     * @param _underwriterFee Total fee for underwriters
     */
    function assignUnderwritersToHotel(
        uint256 _hotelId,
        address[] calldata _underwriterAddresses,
        uint256[] calldata _stakeAmounts,
        uint256 _underwriterFee
    ) external nonReentrant {
        // Check if the hotel exists
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        
        // Check if the hotel owner is calling this function
        (address owner, , ) = hotelRegistry.hotels(_hotelId);
        if (msg.sender != owner) revert NotHotelOwner();
        
        // Validate parameters
        if (_underwriterAddresses.length < MIN_UNDERWRITERS_PER_HOTEL) revert NotEnoughUnderwriters();
        if (_underwriterAddresses.length != _stakeAmounts.length) revert InvalidStakeAmount();
        
        // Initialize hotel underwriting
        HotelUnderwriting storage hotelUw = hotelUnderwritings[_hotelId];
        if (hotelUw.isActive) revert UnderwriterAlreadyAssigned();
        
        // Get vault and total revenue
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        uint256 totalPromisedRevenue = vault.promisedRevenue();
        
        // Process each underwriter
        uint256 totalStakeCommitted = 0;
        for (uint256 i = 0; i < _underwriterAddresses.length; i++) {
            address underwriterAddr = _underwriterAddresses[i];
            uint256 stakeAmount = _stakeAmounts[i];
            
            // Validate underwriter
            if (!isRegisteredUnderwriter[underwriterAddr]) revert UnauthorizedUnderwriter();
            
            UnderwriterInfo storage uwInfo = underwriters[underwriterAddr];
            if (uwInfo.availableStake < stakeAmount) revert InsufficientUnderwriterStake();
            
            // Update underwriter stakes
            uwInfo.availableStake -= stakeAmount;
            uwInfo.lockedStake += stakeAmount;
            
            // Update hotel underwriting info
            hotelUw.stakes[underwriterAddr] = stakeAmount;
            hotelUw.underwriters.push(underwriterAddr);
            totalStakeCommitted += stakeAmount;
        }
        
        // Ensure enough stake is committed
        if (totalStakeCommitted < totalPromisedRevenue) revert NotEnoughStake();
        
        // Finalize hotel underwriting setup
        hotelUw.totalStake = totalStakeCommitted;
        hotelUw.underwriterFee = _underwriterFee;
        hotelUw.isActive = true;
        hotelUw.totalPromisedRevenue = totalPromisedRevenue;
        hotelUw.endDate = block.timestamp + (vault.totalMonth() * 30 days);
        
        for (uint256 i = 0; i < _underwriterAddresses.length; i++) {
            emit UnderwriterAssigned(_hotelId, _underwriterAddresses[i], _stakeAmounts[i]);
        }
    }

    /**
     * @dev Hotel owner deposits underwriter fee
     * @param _hotelId Hotel ID
     */
    function depositUnderwriterFee(uint256 _hotelId) external nonReentrant {
        // Check if the hotel exists with active underwriters
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        
        HotelUnderwriting storage hotelUw = hotelUnderwritings[_hotelId];
        if (!hotelUw.isActive) revert NoActiveUnderwriter();
        
        // Check if the hotel owner is calling this function
        (address owner, , ) = hotelRegistry.hotels(_hotelId);
        if (msg.sender != owner) revert NotHotelOwner();
        
        // Transfer fee from hotel owner to contract
        bool success = usdcToken.transferFrom(msg.sender, address(this), hotelUw.underwriterFee);
        if (!success) revert TransferFailed();
        
        emit HotelUnderwriterFeeDeposited(_hotelId, hotelUw.underwriterFee);
    }

    /**
     * @dev Pay for missing revenue when owner fails to deposit
     * @param _hotelId Hotel ID
     * @param _missingAmount Amount missing from the owner's deposit
     */
    function payRevenueLiability(uint256 _hotelId, uint256 _missingAmount) external nonReentrant {
        // This function would typically be called by a trusted external system or oracle
        // that monitors hotel revenue deposits
        
        // Check if hotel is registered and has active underwriters
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        
        HotelUnderwriting storage hotelUw = hotelUnderwritings[_hotelId];
        if (!hotelUw.isActive) revert NoActiveUnderwriter();
        
        // Get vault address
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        
        // Calculate each underwriter's contribution proportionally
        for (uint256 i = 0; i < hotelUw.underwriters.length; i++) {
            address underwriterAddr = hotelUw.underwriters[i];
            uint256 stake = hotelUw.stakes[underwriterAddr];
            
            // Calculate proportional liability
            uint256 liabilityAmount = (_missingAmount * stake) / hotelUw.totalStake;
            
            // Ensure underwriter has enough stake
            if (liabilityAmount > underwriters[underwriterAddr].lockedStake) revert NotEnoughStakeForClaim();
            
            // Update underwriter stake
            underwriters[underwriterAddr].lockedStake -= liabilityAmount;
            
            // Transfer USDC to vault
            bool success = usdcToken.transfer(vaultAddress, liabilityAmount);
            if (!success) revert TransferFailed();
            
            emit RevenueGuaranteePaid(_hotelId, underwriterAddr, liabilityAmount);
        }
    }

    /**
     * @dev Underwriter claims their share of the fee
     * @param _hotelId Hotel ID
     */
    function claimUnderwriterFee(uint256 _hotelId) external nonReentrant {
        // Check if the hotel exists
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        
        HotelUnderwriting storage hotelUw = hotelUnderwritings[_hotelId];
        if (!hotelUw.isActive) revert NoActiveUnderwriter();
        
        // Check if the underwriter is assigned to this hotel
        uint256 stake = hotelUw.stakes[msg.sender];
        if (stake == 0) revert UnauthorizedUnderwriter();
        
        // Check if contract period has ended
        if (block.timestamp < hotelUw.endDate) revert ClaimPeriodExpired();
        
        // Calculate fee share
        uint256 protocolFeeAmount = (hotelUw.underwriterFee * protocolFee) / BASIS_POINTS;
        uint256 totalUnderwriterFee = hotelUw.underwriterFee - protocolFeeAmount;
        uint256 underwriterShare = (totalUnderwriterFee * stake) / hotelUw.totalStake;
        
        // Update underwriter stakes
        underwriters[msg.sender].lockedStake -= stake;
        underwriters[msg.sender].availableStake += stake;
        
        // Remove stake from hotel
        hotelUw.stakes[msg.sender] = 0;
        
        // Transfer fee to underwriter
        bool success = usdcToken.transfer(msg.sender, underwriterShare);
        if (!success) revert TransferFailed();
        
        emit UnderwriterFeeClaimed(_hotelId, msg.sender, underwriterShare);
    }

    /**
     * @dev Withdraw available stake
     * @param _amount Amount to withdraw
     */
    function withdrawStake(uint256 _amount) external nonReentrant {
        UnderwriterInfo storage info = underwriters[msg.sender];
        
        if (_amount > info.availableStake) revert NotAllowedToWithdraw();
        
        // Update underwriter info
        info.totalStake -= _amount;
        info.availableStake -= _amount;
        
        // Transfer USDC back to underwriter
        bool success = usdcToken.transfer(msg.sender, _amount);
        if (!success) revert TransferFailed();
        
        emit UnderwriterWithdrawal(msg.sender, _amount);
    }

    /**
     * @dev Get underwriter stakes for a hotel
     * @param _hotelId Hotel ID
     * @param _underwriter Underwriter address
     * @return stake Amount staked
     */
    function getUnderwriterStake(uint256 _hotelId, address _underwriter) external view returns (uint256 stake) {
        return hotelUnderwritings[_hotelId].stakes[_underwriter];
    }

    /**
     * @dev Get all underwriters for a hotel
     * @param _hotelId Hotel ID
     * @return Array of underwriter addresses
     */
    function getHotelUnderwriters(uint256 _hotelId) external view returns (address[] memory) {
        return hotelUnderwritings[_hotelId].underwriters;
    }

    /**
     * @dev Check if a hotel's underwriting period has ended
     * @param _hotelId Hotel ID
     * @return hasEnded Boolean indicating if period has ended
     */
    function hasUnderwritingPeriodEnded(uint256 _hotelId) external view returns (bool hasEnded) {
        return block.timestamp >= hotelUnderwritings[_hotelId].endDate;
    }
}