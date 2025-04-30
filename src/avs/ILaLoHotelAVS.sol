// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;


interface ILaLoHotelAVS {
    // Errors
    error Unauthorized();
    error TransferFailed();
    error NoActiveUnderwriters();
    error InsufficientFunds();
    error FeeAlreadyClaimed();
    error NoEligibleUnderwriters();
    error HotelPeriodNotEnded();
    error UnderwriterNotApproved();
    error NotHotelOwner();
    error LiabilityAlreadyPaid();
    error NoRevenueMissing();

    // Events
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event UnderwriterAdded(address indexed underwriter, uint256 stake);
    event MonthlyReportSubmitted(uint256 month, uint256 revenueReport, uint256 revenueMissing);
    event RevenueLiabilityPaid(uint256 month, uint256 amount);
    event UnderwriterFeeDistributed(address indexed underwriter, uint256 amount);
    event OwnerDepositReceived(uint256 month, uint256 amount);

    // Structs
    struct MonthlyReport {
        uint256 expectedRevenue;
        uint256 actualRevenue;
        uint256 missingRevenue;
        bool liabilityPaid;
        uint256 timestamp;
    }

    struct UnderwriterInfo {
        uint256 stake;
        bool approved;
        bool feeClaimed;
    }
}