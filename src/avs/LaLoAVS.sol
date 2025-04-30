// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {LaLoUnderwriterSystem} from "../underwriter/LaLoUnderwriterSystem.sol";
import {ILaLoUnderwriterSystem} from "../underwriter/ILaLoUnderwriterSystem.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {ILaLoAVS} from "./ILaLoAVS.sol";

contract LaLoAVS is ILaLoAVS, ReentrancyGuard {
    // State variables
    IERC20 public immutable usdcToken;
    LaLoHotelRegistry public immutable hotelRegistry;
    LaLoUnderwriterSystem public immutable underwriterSystem;
    address public admin;
    uint256 public protocolFee; // Percentage expressed as basis points (e.g., 200 = 2%)
    
    // Mappings
    mapping(address => bool) public operators;
    mapping(uint256 => mapping(uint256 => HotelReport)) public hotelReports; // hotelId => month => report
    mapping(uint256 => HotelApproval) public hotelApprovals; // hotelId => approval data
    mapping(uint256 => uint256) public lastReportedMonth; // hotelId => last reported month
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000; // 100%
    uint256 public constant MAX_PROTOCOL_FEE = 1000; // Max 10%
    uint256 public constant REPORT_FREQUENCY = 30 days;
    uint256 public constant MIN_APPROVALS = 2;

    /**
     * @dev Constructor
     * @param _usdcToken Address of the USDC token
     * @param _hotelRegistry Address of the Hotel Registry
     * @param _underwriterSystem Address of the Underwriter System
     */
    constructor(
        address _usdcToken,
        address _hotelRegistry,
        address _underwriterSystem
    ) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = LaLoHotelRegistry(_hotelRegistry);
        underwriterSystem = LaLoUnderwriterSystem(_underwriterSystem);
        admin = msg.sender;
        operators[msg.sender] = true;
        protocolFee = 200; // Default 2%
    }
    
    /**
     * @dev Modifier to check if sender is admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    /**
     * @dev Modifier to check if sender is an operator
     */
    modifier onlyOperator() {
        if (!operators[msg.sender]) revert Unauthorized();
        _;
    }
    
    /**
     * @dev Add a new operator
     * @param _operator Address of the new operator
     */
    function addOperator(address _operator) external onlyAdmin {
        operators[_operator] = true;
        emit OperatorAdded(_operator);
    }
    
    /**
     * @dev Remove an operator
     * @param _operator Address of the operator to remove
     */
    function removeOperator(address _operator) external onlyAdmin {
        if (_operator == admin) revert Unauthorized();
        operators[_operator] = false;
        emit OperatorRemoved(_operator);
    }
    
    /**
     * @dev Update protocol fee
     * @param _newFee New fee in basis points
     */
    function updateProtocolFee(uint256 _newFee) external onlyAdmin {
        if (_newFee > MAX_PROTOCOL_FEE) revert Unauthorized();
        protocolFee = _newFee;
    }
    
    /**
     * @dev Operator approves a hotel after verification
     * @param _hotelId Hotel ID
     */
    function approveHotel(uint256 _hotelId) external onlyOperator {
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        
        HotelApproval storage approval = hotelApprovals[_hotelId];
        if (approval.isApproved) revert HotelAlreadyApproved();
        
        approval.isApproved = true;
        approval.requiredApprovals = MIN_APPROVALS;
        
        emit HotelApproved(_hotelId, msg.sender);
    }
    
    /**
     * @dev Approve an underwriter for a hotel
     * @param _hotelId Hotel ID
     * @param _underwriter Address of the underwriter
     */
    function approveUnderwriter(uint256 _hotelId, address _underwriter) external onlyOperator {
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        if (!underwriterSystem.isRegisteredUnderwriter(_underwriter)) revert InvalidUnderwriter();
        
        HotelApproval storage approval = hotelApprovals[_hotelId];
        if (!approval.isApproved) revert InvalidHotelId();
        if (approval.underwriterApprovals[_underwriter]) revert UnderwriterAlreadyApproved();
        
        // Check underwriter has sufficient stake
        (uint256 totalStake, uint256 availableStake,) = underwriterSystem.underwriters(_underwriter);
        if (availableStake < 100 * 10**6) revert MinimumStakeNotMet(); // Minimum 100 USDC stake
        
        approval.underwriterApprovals[_underwriter] = true;
        approval.approvedUnderwriters.push(_underwriter);
        approval.totalApprovals++;
        
        emit UnderwriterApproved(_hotelId, _underwriter, msg.sender);
    }
    
    /**
     * @dev Get approved underwriters for a hotel
     * @param _hotelId Hotel ID
     * @return Array of approved underwriter addresses
     */
    function getApprovedUnderwriters(uint256 _hotelId) external view returns (address[] memory) {
        return hotelApprovals[_hotelId].approvedUnderwriters;
    }
    
    /**
     * @dev Check if a hotel has sufficient underwriter approvals
     * @param _hotelId Hotel ID
     * @return hasEnough True if hotel has enough approvals
     */
    function hasSufficientApprovals(uint256 _hotelId) public view returns (bool hasEnough) {
        HotelApproval storage approval = hotelApprovals[_hotelId];
        return approval.totalApprovals >= approval.requiredApprovals;
    }
    
    /**
     * @dev Generate monthly report for a hotel
     * @param _hotelId Hotel ID
     * @param _revenueReported Actual revenue reported
     * @param _month Month number (starting from 1)
     */
    function generateMonthlyReport(
        uint256 _hotelId,
        uint256 _revenueReported,
        uint256 _month
    ) external onlyOperator nonReentrant {
        if (!hotelRegistry.isHotelRegistered(_hotelId)) revert UnsupportedHotelId();
        if (!hasSufficientApprovals(_hotelId)) revert InsufficientApprovals();
        
        // Check if it's time for a new report
        uint256 lastMonth = lastReportedMonth[_hotelId];
        if (_month <= lastMonth) revert ReportAlreadySubmitted();
        if (_month > lastMonth + 1) revert InvalidReportData(); // Can only report consecutive months
        
        // Get vault and required revenue info
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        uint256 totalPromisedRevenue = vault.promisedRevenue();
        uint256 totalMonths = vault.totalMonth();
        
        // Calculate required monthly revenue
        uint256 revenueRequired = totalPromisedRevenue / totalMonths;
        
        // Calculate shortfall
        uint256 shortfallAmount = 0;
        if (_revenueReported < revenueRequired) {
            shortfallAmount = revenueRequired - _revenueReported;
        }
        
        // Store report
        hotelReports[_hotelId][_month] = HotelReport({
            month: _month,
            revenueReported: _revenueReported,
            revenueRequired: revenueRequired,
            shortfallAmount: shortfallAmount,
            shortfallCovered: false,
            reportTimestamp: block.timestamp
        });
        
        // Update last reported month
        lastReportedMonth[_hotelId] = _month;
        
        emit MonthlyReportGenerated(_hotelId, _month, _revenueReported, revenueRequired);
        
        // If there's a shortfall, trigger the underwriter system to cover it
        if (shortfallAmount > 0) {
            emit RevenueShortfallDetected(_hotelId, _month, shortfallAmount);
            underwriterSystem.payRevenueLiability(_hotelId, shortfallAmount);
            hotelReports[_hotelId][_month].shortfallCovered = true;
        }
    }
    
    /**
     * @dev Collect protocol fee
     * @param _amount Amount to collect
     */
    function collectProtocolFee(uint256 _amount) external onlyAdmin nonReentrant {
        bool success = usdcToken.transfer(admin, _amount);
        if (!success) revert TransferFailed();
        
        emit AVSProtocolFeeCollected(_amount);
    }
    
    // /**
    //  * @dev View function to get report for a specific month
    //  * @param _hotelId Hotel ID
    //  * @param _month Month number
    //  * @return Report data
    //  */
    function getMonthlyReport(uint256 _hotelId, uint256 _month) 
        external 
        view 
        returns (
            uint256 month,
            uint256 revenueReported,
            uint256 revenueRequired,
            uint256 shortfallAmount,
            bool shortfallCovered,
            uint256 reportTimestamp
        ) 
    {
        HotelReport storage report = hotelReports[_hotelId][_month];
        if (report.reportTimestamp == 0) revert NoReportForMonth();
        
        return (
            report.month,
            report.revenueReported,
            report.revenueRequired,
            report.shortfallAmount,
            report.shortfallCovered,
            report.reportTimestamp
        );
    }
    
    /**
     * @dev Check if a hotel has had any revenue shortfalls
     * @param _hotelId Hotel ID
     * @return hasShortfall True if hotel has had shortfalls
     */
    function hasHadShortfalls(uint256 _hotelId) external view returns (bool hasShortfall) {
        uint256 lastMonth = lastReportedMonth[_hotelId];
        
        for (uint256 i = 1; i <= lastMonth; i++) {
            if (hotelReports[_hotelId][i].shortfallAmount > 0) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Calculate hotel reliability score based on historical reports
     * @param _hotelId Hotel ID
     * @return score Reliability score (0-100)
     */
    function calculateHotelReliabilityScore(uint256 _hotelId) external view returns (uint256 score) {
        uint256 lastMonth = lastReportedMonth[_hotelId];
        if (lastMonth == 0) return 0;
        
        uint256 totalShortfall = 0;
        uint256 totalRequired = 0;
        
        for (uint256 i = 1; i <= lastMonth; i++) {
            HotelReport storage report = hotelReports[_hotelId][i];
            if (report.reportTimestamp > 0) {
                totalShortfall += report.shortfallAmount;
                totalRequired += report.revenueRequired;
            }
        }
        
        if (totalRequired == 0) return 100;
        
        // Score = 100 - (shortfall / required * 100)
        return 100 - ((totalShortfall * 100) / totalRequired);
    }
    
    /**
     * @dev Get the total number of hotels with active underwriters
     * @return count Number of hotels
     */
    function getActiveHotelCount() external view returns (uint256 count) {
        uint256 totalHotels = hotelRegistry.nextHotelId();
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < totalHotels; i++) {
            if (hasSufficientApprovals(i)) {
                activeCount++;
            }
        }
        
        return activeCount;
    }
}