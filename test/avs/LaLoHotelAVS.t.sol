// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LaLoHotelRegistry} from "../../src/hotel_owners/LaLoHotelRegistry.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelTokenization} from "../../src/revenue_stream/LaLoHotelTokenization.sol";
import {LaLoUnderwriterSystem} from "../../src/underwriter/LaLoUnderwriterSystem.sol";
import {LaLoHotelAVS, ILaLoHotelAVS} from "../../src/avs/LaLoHotelAVS.sol";
import {LaLoVault} from "../../src/revenue_stream/LaLoVault.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract LaLoHotelAVSTest is Test {
    MockUSDC usdc;
    LaLoHotelRegistry registry;
    LaLoTokenFactory factory;
    LaLoHotelTokenization tokenization;
    LaLoUnderwriterSystem underwriterSystem;
    LaLoHotelAVS hotelAVS;

    string hotelName = "LaLo Hotel";
    uint256 tokenAmount = 1200;
    uint256 usdcPrice = 1000;
    uint256 totalMonths = 12;
    uint256 auctionDuration = 7 days;

    address hotelOwner;
    address underwriter1;
    address underwriter2;
    address operator;
    address alice;
    uint256 hotelId;

    function setUp() public {
        // Create addresses
        hotelOwner = vm.addr(1);
        underwriter1 = vm.addr(2);
        underwriter2 = vm.addr(3);
        operator = vm.addr(4);
        alice = vm.addr(5);

        // Deploy contracts
        usdc = new MockUSDC(1e6, "LaLoUSDC", "LUSDC");
        factory = new LaLoTokenFactory();
        registry = new LaLoHotelRegistry(address(usdc), address(factory));
        tokenization = new LaLoHotelTokenization(
            address(usdc),
            address(registry)
        );
        underwriterSystem = new LaLoUnderwriterSystem(
            address(usdc),
            address(registry)
        );

        // Set underwriter system in registry
        registry.setUnderwriterSystem(address(underwriterSystem));

        // Distribute USDC
        usdc.transfer(hotelOwner, 5000 * 10 ** 6);
        usdc.transfer(underwriter1, 1000 * 10 ** 6);
        usdc.transfer(underwriter2, 1000 * 10 ** 6);
        usdc.transfer(alice, 500 * 10 ** 6);

        // Register hotel
        vm.startPrank(hotelOwner);
        usdc.approve(address(registry), 10000 * 10 ** 6);
        hotelId = registry.registerHotel(
            hotelName,
            tokenAmount,
            usdcPrice,
            totalMonths,
            auctionDuration
        );
        vm.stopPrank();

        // Get hotel AVS
        hotelAVS = LaLoHotelAVS(registry.getHotelAVS(hotelId));
    }

    function testHotelAVSBasicFlow() public {
        // 1. Register underwriters in the global system
        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), 600 * 10 ** 6);
        underwriterSystem.registerAsUnderwriter(600 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), 500 * 10 ** 6);
        underwriterSystem.registerAsUnderwriter(500 * 10 ** 6);
        vm.stopPrank();

        // 2. Approve underwriters in the hotel AVS
        vm.startPrank(address(this)); // The test contract is the default operator
        hotelAVS.addUnderwriter(underwriter1, 600 * 10 ** 6);
        hotelAVS.addUnderwriter(underwriter2, 500 * 10 ** 6);
        vm.stopPrank();

        // Verify underwriters were added
        address[] memory underwriters = hotelAVS.getAllUnderwriters();
        assertEq(underwriters.length, 2, "Should have 2 underwriters");
        assertEq(
            underwriters[0],
            underwriter1,
            "First underwriter should be underwriter1"
        );
        assertEq(
            underwriters[1],
            underwriter2,
            "Second underwriter should be underwriter2"
        );

        // 3. Hotel owner sets and deposits underwriter fee
        vm.startPrank(hotelOwner);
        uint256 underwriterFee = 100 * 10 ** 6; // 100 USDC fee
        hotelAVS.setUnderwriterFee(underwriterFee);
        usdc.approve(address(hotelAVS), underwriterFee);
        hotelAVS.depositUnderwriterFee();
        vm.stopPrank();

        // Verify fee was deposited
        assertEq(
            usdc.balanceOf(address(hotelAVS)),
            underwriterFee,
            "AVS should have the underwriter fee"
        );

        // 4. Alice buys tokens
        vm.startPrank(alice);
        usdc.approve(
            address(tokenization.getVaultAddress(hotelId)),
            500 * 10 ** 6
        );
        tokenization.buyLaLoTokens(hotelId, 500 * 10 ** 6);
        vm.stopPrank();

        // 5. First month: Owner makes full revenue deposit
        vm.warp(block.timestamp + 30 days); // Fast forward 1 month

        uint256 monthlyRevenue = 100 * 10 ** 6; // 100 USDC (full amount)

        vm.startPrank(hotelOwner);
        usdc.approve(
            address(tokenization.getVaultAddress(hotelId)),
            monthlyRevenue
        );
        tokenization.ownerDepositUSDC(hotelId, monthlyRevenue);

        // Also deposit through AVS for tracking
        usdc.approve(address(hotelAVS), 0); // Reset approval
        usdc.approve(address(hotelAVS), monthlyRevenue);
        hotelAVS.ownerDepositRevenue(1, monthlyRevenue);
        vm.stopPrank();

        // 6. AVS generates first monthly report
        vm.prank(address(this));
        hotelAVS.submitMonthlyReport(monthlyRevenue);

        // 7. Second month: Owner makes partial payment
        vm.warp(block.timestamp + 30 days); // Fast forward another month

        uint256 partialRevenue = 60 * 10 ** 6; // Only 60 USDC (shortfall of 40 USDC)

        vm.startPrank(hotelOwner);
        usdc.approve(
            address(tokenization.getVaultAddress(hotelId)),
            partialRevenue
        );
        tokenization.ownerDepositUSDC(hotelId, partialRevenue);
        usdc.approve(address(hotelAVS), partialRevenue);
        hotelAVS.ownerDepositRevenue(2, partialRevenue);
        vm.stopPrank();

        // 8. AVS generates second monthly report
        vm.startPrank(address(this));
        hotelAVS.submitMonthlyReport(partialRevenue);

        // 9. Process revenue liability for month 2
        hotelAVS.processRevenueLiability(2);
        vm.stopPrank(); 

        // 10. Verify liability was paid
        // bool isLiabilityPaid = hotelAVS.monthlyReports(2);
        // assertTrue(isLiabilityPaid, "Liability should be marked as paid");

        // 11. Jump to end of contract term
        vm.warp(block.timestamp + 365 days);

        // 12. Distribute underwriter fees
        vm.prank(address(this));
        hotelAVS.distributeUnderwriterFees();

        // Verify underwriters received their fees
        uint256 underwriter1ExpectedShare = 55 * 10 ** 6; // ~55% of 100 USDC fee
        uint256 underwriter2ExpectedShare = 45 * 10 ** 6; // ~45% of 100 USDC fee

        uint256 underwriter1BalanceBefore = usdc.balanceOf(underwriter1);
        uint256 underwriter2BalanceBefore = usdc.balanceOf(underwriter2);

        assertApproxEqAbs(
            underwriter1BalanceBefore,
            underwriter1ExpectedShare,
            1e6, // 1 USDC tolerance (fees might not be exact due to rounding)
            "Underwriter1 should receive approximately correct fee share"
        );

        assertApproxEqAbs(
            underwriter2BalanceBefore,
            underwriter2ExpectedShare,
            1e6, // 1 USDC tolerance
            "Underwriter2 should receive approximately correct fee share"
        );

        // 13. Get hotel performance summary
        (
            uint256 totalExpected,
            uint256 totalActual,
            uint256 totalMissing,
            uint256 totalLiabilityPaid
        ) = hotelAVS.getHotelPerformanceSummary();

        assertEq(
            totalExpected,
            200 * 10 ** 6,
            "Total expected revenue should be 200 USDC for 2 months"
        );
        assertEq(
            totalActual,
            160 * 10 ** 6,
            "Total actual revenue should be 160 USDC"
        );
        assertEq(
            totalMissing,
            40 * 10 ** 6,
            "Total missing revenue should be 40 USDC"
        );
        assertEq(
            totalLiabilityPaid,
            40 * 10 ** 6,
            "Total liability paid should be 40 USDC"
        );
    }

    function testUnauthorizedAccess() public {
        // Try unauthorized operations
        vm.startPrank(alice);

        // Try to add operator
        vm.expectRevert(ILaLoHotelAVS.Unauthorized.selector);
        hotelAVS.addOperator(alice);

        // Try to add underwriter
        vm.expectRevert(ILaLoHotelAVS.Unauthorized.selector);
        hotelAVS.addUnderwriter(underwriter1, 600 * 10 ** 6);

        // Try to submit monthly report
        vm.expectRevert(ILaLoHotelAVS.Unauthorized.selector);
        hotelAVS.submitMonthlyReport(100 * 10 ** 6);

        // Try to process liability
        vm.expectRevert(ILaLoHotelAVS.Unauthorized.selector);
        hotelAVS.processRevenueLiability(1);

        // Try to distribute fees
        vm.expectRevert(ILaLoHotelAVS.Unauthorized.selector);
        hotelAVS.distributeUnderwriterFees();

        vm.stopPrank();

        // Try hotel owner operations as non-owner
        vm.startPrank(alice);

        // Try to set underwriter fee
        vm.expectRevert(ILaLoHotelAVS.NotHotelOwner.selector);
        hotelAVS.setUnderwriterFee(100 * 10 ** 6);

        // Try to deposit fee
        vm.expectRevert(ILaLoHotelAVS.NotHotelOwner.selector);
        hotelAVS.depositUnderwriterFee();

        vm.stopPrank();
    }

    function testMultipleHotels() public {
        // Register a second hotel
        string memory hotel2Name = "LaLo Hotel 2";

        vm.startPrank(hotelOwner);
        usdc.approve(address(registry), 10000 * 10 ** 6);
        uint256 hotel2Id = registry.registerHotel(
            hotel2Name,
            tokenAmount,
            usdcPrice,
            totalMonths,
            auctionDuration
        );
        vm.stopPrank();

        // Verify different AVS addresses
        address avs1 = registry.getHotelAVS(hotelId);
        address avs2 = registry.getHotelAVS(hotel2Id);

        assertTrue(avs1 != avs2, "Hotel AVS addresses should be different");

        // Get the second hotel's AVS
        LaLoHotelAVS hotel2AVS = LaLoHotelAVS(avs2);

        // Add an underwriter to each hotel's AVS
        vm.startPrank(address(this));

        // Register underwriters in the global system first
        vm.stopPrank();

        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), 1000 * 10 ** 6);
        underwriterSystem.registerAsUnderwriter(1000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(address(this));
        // Add underwriter1 to first hotel with 600 USDC stake
        hotelAVS.addUnderwriter(underwriter1, 600 * 10 ** 6);

        // Add underwriter1 to second hotel with 400 USDC stake
        hotel2AVS.addUnderwriter(underwriter1, 400 * 10 ** 6);
        vm.stopPrank();

        // Verify underwriter was added to both hotels with different stakes
        address[] memory underwriters1 = hotelAVS.getAllUnderwriters();
        address[] memory underwriters2 = hotel2AVS.getAllUnderwriters();

        assertEq(
            underwriters1.length,
            1,
            "First hotel should have 1 underwriter"
        );
        assertEq(
            underwriters2.length,
            1,
            "Second hotel should have 1 underwriter"
        );

        assertEq(
            underwriters1[0],
            underwriter1,
            "First hotel underwriter should be underwriter1"
        );
        assertEq(
            underwriters2[0],
            underwriter1,
            "Second hotel underwriter should be underwriter1"
        );

        (uint256 stake1, , ) = hotelAVS.underwriters(underwriter1);
        (uint256 stake2, , ) = hotel2AVS.underwriters(underwriter1);

        assertEq(stake1, 600 * 10 ** 6, "First hotel stake should be 600 USDC");
        assertEq(
            stake2,
            400 * 10 ** 6,
            "Second hotel stake should be 400 USDC"
        );
    }
}
