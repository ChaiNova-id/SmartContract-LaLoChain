// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {LaLoUnderwriterSystem} from "../underwriter/LaLoUnderwriterSystem.sol";
import {ILaLoUnderwriterSystem} from "../underwriter/ILaLoUnderwriterSystem.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {ILaLoHotelAVS} from "./ILaLoHotelAVS.sol";

contract LaLoHotelAVS is ILaLoHotelAVS, ReentrancyGuard {
    // State variables
    IERC20 public immutable usdcToken;
    uint256 public immutable hotelId;
    LaLoHotelRegistry public immutable registry;
    LaLoUnderwriterSystem public immutable underwriterSystem;
    uint256 public monthlyExpectedRevenue;
    uint256 public underwriterFeeAmount;
    uint256 public startTimestamp;
    address public hotelOwner;
    
    // Access control
    mapping(address => bool) public operators;
    address public admin;
    
    // Underwriter management
    address[] public underwriterAddresses;
    mapping(address => UnderwriterInfo) public underwriters;
    uint256 public totalStake;
    
    // Reporting data
    mapping(uint256 => MonthlyReport) public monthlyReports;
    uint256 public currentMonth;
    uint256 public totalRevenueExpected;
    uint256 public totalRevenueCollected;
    uint256 public totalLiabilityPaid;
    bool public feesDistributed;
    
    /**
     * @dev Constructor
     * @param _usdcToken Address of the USDC token
     * @param _hotelId Hotel ID
     * @param _registry Address of the hotel registry
     * @param _underwriterSystem Address of the underwriter system
     * @param _monthlyRevenue Expected monthly revenue
     * @param _hotelOwner Address of hotel owner
     */
    constructor(
        address _usdcToken,
        uint256 _hotelId,
        address _registry,
        address _underwriterSystem,
        uint256 _monthlyRevenue,
        address _hotelOwner
    ) {
        usdcToken = IERC20(_usdcToken);
        hotelId = _hotelId;
        registry = LaLoHotelRegistry(_registry);
        underwriterSystem = LaLoUnderwriterSystem(_underwriterSystem);
        monthlyExpectedRevenue = _monthlyRevenue;
        hotelOwner = _hotelOwner;
        startTimestamp = block.timestamp;
        admin = msg.sender;
        operators[msg.sender] = true;
        currentMonth = 1;
    }
    
    /**
     * @dev Modifier to restrict access to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    /**
     * @dev Modifier to restrict access to operators
     */
    modifier onlyOperator() {
        if (!operators[msg.sender]) revert Unauthorized();
        _;
    }
    
    /**
     * @dev Modifier to restrict access to hotel owner
     */
    modifier onlyHotelOwner() {
        if (msg.sender != hotelOwner) revert NotHotelOwner();
        _;
    }
    
    /**
     * @dev Add an operator
     * @param _operator Address of the operator
     */
    function addOperator(address _operator) external onlyAdmin {
        operators[_operator] = true;
        emit OperatorAdded(_operator);
    }
    
    /**
     * @dev Remove an operator
     * @param _operator Address of the operator
     */
    function removeOperator(address _operator) external onlyAdmin {
        if (_operator == admin) revert Unauthorized();
        operators[_operator] = false;
        emit OperatorRemoved(_operator);
    }
    
    /**
     * @dev Set the amount of underwriter fee
     * @param _amount Fee amount
     */
    function setUnderwriterFee(uint256 _amount) external onlyHotelOwner {
        underwriterFeeAmount = _amount;
    }
    
    /**
     * @dev Add an underwriter to this hotel
     * @param _underwriter Address of the underwriter
     * @param _stake Stake amount for this hotel
     */
    function addUnderwriter(address _underwriter, uint256 _stake) external onlyOperator {
        require(underwriterSystem.isRegisteredUnderwriter(_underwriter), "Not a registered underwriter");
        
        // Ensure underwriter is not already added
        require(!underwriters[_underwriter].approved, "Underwriter already added");
        
        // Add underwriter
        underwriters[_underwriter] = UnderwriterInfo({
            stake: _stake,
            approved: true,
            feeClaimed: false
        });
        
        underwriterAddresses.push(_underwriter);
        totalStake += _stake;
        
        emit UnderwriterAdded(_underwriter, _stake);
    }
    
    /**
     * @dev Deposit underwriter fee (called by hotel owner)
     */
    function depositUnderwriterFee() external onlyHotelOwner nonReentrant {
        require(underwriterFeeAmount > 0, "Fee amount not set");
        require(totalStake > 0, "No underwriters staked");
        
        bool success = usdcToken.transferFrom(hotelOwner, address(this), underwriterFeeAmount);
        if (!success) revert TransferFailed();
    }
    
    /**
     * @dev Submit monthly revenue report
     * @param _actualRevenue Actual revenue collected
     */
    function submitMonthlyReport(uint256 _actualRevenue) external onlyOperator nonReentrant {
        // Calculate missing revenue if any
        uint256 missingRevenue = 0;
        if (_actualRevenue < monthlyExpectedRevenue) {
            missingRevenue = monthlyExpectedRevenue - _actualRevenue;
        }
        
        // Store report
        monthlyReports[currentMonth] = MonthlyReport({
            expectedRevenue: monthlyExpectedRevenue,
            actualRevenue: _actualRevenue,
            missingRevenue: missingRevenue,
            liabilityPaid: false,
            timestamp: block.timestamp
        });
        
        // Update totals
        totalRevenueExpected += monthlyExpectedRevenue;
        totalRevenueCollected += _actualRevenue;
        
        emit MonthlyReportSubmitted(currentMonth, _actualRevenue, missingRevenue);
        
        // Increment month for next report
        currentMonth++;
    }
    
    /**
     * @dev Process revenue liability for a specific month
     * @param _month Month number
     */
    function processRevenueLiability(uint256 _month) external onlyOperator nonReentrant {
        MonthlyReport storage report = monthlyReports[_month];
        
        // Ensure there's a report for this month
        require(report.timestamp > 0, "No report for this month");
        
        // Check if liability needs to be paid
        if (report.missingRevenue == 0) revert NoRevenueMissing();
        if (report.liabilityPaid) revert LiabilityAlreadyPaid();
        
        // Ensure there are underwriters
        if (totalStake == 0) revert NoActiveUnderwriters();
        
        // Mark liability as paid
        report.liabilityPaid = true;
        totalLiabilityPaid += report.missingRevenue;
        
        // Request underwriter system to pay the liability
        underwriterSystem.payRevenueLiability(hotelId, report.missingRevenue);
        
        emit RevenueLiabilityPaid(_month, report.missingRevenue);
    }
    
    /**
     * @dev Owner deposits revenue (monthly)
     * @param _month Month number
     * @param _amount Amount to deposit
     */
    function ownerDepositRevenue(uint256 _month, uint256 _amount) external onlyHotelOwner nonReentrant {
        require(_month > 0 && _month <= currentMonth, "Invalid month");
        
        // Transfer USDC from owner to vault
        address vaultAddress = registry.getVaultAddress(hotelId);
        bool success = usdcToken.transferFrom(hotelOwner, vaultAddress, _amount);
        if (!success) revert TransferFailed();
        
        emit OwnerDepositReceived(_month, _amount);
    }
    
    /**
     * @dev Distribute underwriter fees at end of contract
     */
    function distributeUnderwriterFees() external onlyOperator nonReentrant {
        // Ensure we have underwriter fees to distribute
        uint256 balance = usdcToken.balanceOf(address(this));
        if (balance == 0) revert InsufficientFunds();
        
        // Ensure fees haven't been distributed already
        if (feesDistributed) revert FeeAlreadyClaimed();
        
        // Mark as distributed
        feesDistributed = true;
        
        // Distribute proportionally to each underwriter
        for (uint256 i = 0; i < underwriterAddresses.length; i++) {
            address underwriterAddr = underwriterAddresses[i];
            UnderwriterInfo storage info = underwriters[underwriterAddr];
            
            if (info.approved && !info.feeClaimed) {
                // Calculate proportional share
                uint256 share = (balance * info.stake) / totalStake;
                
                // Mark as claimed
                info.feeClaimed = true;
                
                // Send share to underwriter
                bool success = usdcToken.transfer(underwriterAddr, share);
                if (!success) revert TransferFailed();
                
                emit UnderwriterFeeDistributed(underwriterAddr, share);
            }
        }
    }
    
    /**
     * @dev Check if contract period has ended
     * @return hasEnded True if period has ended
     */
    function hasContractPeriodEnded() public view returns (bool hasEnded) {
        // Get total months from vault
        address vaultAddress = registry.getVaultAddress(hotelId);
        
        // We're accessing LaLoVault totalMonth directly
        (bool success, bytes memory data) = vaultAddress.staticcall(
            abi.encodeWithSignature("totalMonth()")
        );
        
        if (success) {
            uint256 totalMonths = abi.decode(data, (uint256));
            
            // Check if enough time has passed (rough estimate based on 30 days per month)
            uint256 contractDuration = totalMonths * 30 days;
            return (block.timestamp >= startTimestamp + contractDuration);
        }
        
        return false;
    }
    
    /**
     * @dev Claim underwriter fee as an underwriter
     */
    function claimUnderwriterFee() external nonReentrant {
        // Ensure caller is an approved underwriter
        UnderwriterInfo storage info = underwriters[msg.sender];
        if (!info.approved) revert UnderwriterNotApproved();
        
        // Ensure period has ended
        if (!hasContractPeriodEnded()) revert HotelPeriodNotEnded();
        
        // Ensure not already claimed
        if (info.feeClaimed) revert FeeAlreadyClaimed();
        
        // Mark as claimed
        info.feeClaimed = true;
        
        // Calculate their share of the fee
        uint256 balance = usdcToken.balanceOf(address(this));
        uint256 share = (balance * info.stake) / totalStake;
        
        // Send fee to underwriter
        bool success = usdcToken.transfer(msg.sender, share);
        if (!success) revert TransferFailed();
        
        emit UnderwriterFeeDistributed(msg.sender, share);
    }
    
    /**
     * @dev Get all underwriters
     * @return Addresses of all underwriters
     */
    function getAllUnderwriters() external view returns (address[] memory) {
        return underwriterAddresses;
    }
    
    /**
     * @dev Get hotel performance summary
     * @return totalExpected Total expected revenue
     * @return totalActual Total actual revenue
     * @return totalMissing Total missing revenue
     * @return liabilityPaid Total liability paid by underwriters
     */
    function getHotelPerformanceSummary() external view returns (
        uint256 totalExpected,
        uint256 totalActual,
        uint256 totalMissing,
        uint256 liabilityPaid
    ) {
        return (
            totalRevenueExpected,
            totalRevenueCollected,
            totalRevenueExpected - totalRevenueCollected,
            totalLiabilityPaid
        );
    }
}