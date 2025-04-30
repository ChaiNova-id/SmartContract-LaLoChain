// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;
interface ILaLoAVS {
    // Errors
    error Unauthorized();
    error InvalidHotelId();
    error NoReportForMonth();
    error UnsupportedHotelId();
    error TransferFailed();
    error NoActiveUnderwriters();
    error InvalidUnderwriter();
    error UnderwriterAlreadyApproved();
    error InsufficientApprovals();
    error HotelAlreadyApproved();
    error MinimumStakeNotMet();
    error ReportAlreadySubmitted();
    error InvalidReportData();
    error NotYetTimeForReport();

    // Events
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event HotelApproved(uint256 indexed hotelId, address indexed approver);
    event UnderwriterApproved(uint256 indexed hotelId, address indexed underwriter, address indexed approver);
    event MonthlyReportGenerated(uint256 indexed hotelId, uint256 month, uint256 revenueReported, uint256 revenueRequired);
    event RevenueShortfallDetected(uint256 indexed hotelId, uint256 month, uint256 shortfallAmount);
    event UnderwriterFeeDistributed(uint256 indexed hotelId, uint256 totalAmount);
    event AVSProtocolFeeCollected(uint256 amount);

    // Structs
    struct HotelReport {
        uint256 month;
        uint256 revenueReported;
        uint256 revenueRequired;
        uint256 shortfallAmount;
        bool shortfallCovered;
        uint256 reportTimestamp;
    }
    
    struct HotelApproval {
        bool isApproved;
        mapping(address => bool) underwriterApprovals;
        address[] approvedUnderwriters;
        uint256 requiredApprovals;
        uint256 totalApprovals;
    }
}
