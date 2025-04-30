// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LaLoHotelRegistry} from "../../src/hotel_owners/LaLoHotelRegistry.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelTokenization} from "../../src/revenue_stream/LaLoHotelTokenization.sol";
import {LaLoUnderwriterSystem} from "../../src/underwriter/LaLoUnderwriterSystem.sol";
import {LaLoHotelAVS} from "../../src/avs/LaLoHotelAVS.sol";
import {LaLoVault} from "../../src/revenue_stream/LaLoVault.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract LaLoUnderwriterSystemTest is Test {
    MockUSDC usdc;
    LaLoHotelRegistry registry;
    LaLoTokenFactory factory;
    LaLoHotelTokenization tokenization;
    LaLoUnderwriterSystem underwriterSystem;

    // Hotel parameters
    string hotelName = "LaLo Luxury Hotel";
    uint256 tokenAmount = 1200 * 10 ** 6; // 1200 USDC worth of tokens
    uint256 usdcPrice = 1000 * 10 ** 6; // Selling for 1000 USDC
    uint256 totalMonths = 12; // 1 year term
    uint256 auctionDuration = 7 days; // 1 week auction period

    // Test addresses
    address admin;
    address hotelOwner;
    address underwriter1;
    address underwriter2;
    address underwriter3;
    address user;

    // Test variables
    uint256 hotelId;
    LaLoHotelAVS hotelAVS;
    address vaultAddress;

    function setUp() public {
        // Create addresses
        admin = address(this);
        hotelOwner = vm.addr(1);
        underwriter1 = vm.addr(2);
        underwriter2 = vm.addr(3);
        underwriter3 = vm.addr(4);
        user = vm.addr(5);

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
        usdc.transfer(underwriter1, 2000 * 10 ** 6);
        usdc.transfer(underwriter2, 2000 * 10 ** 6);
        usdc.transfer(underwriter3, 2000 * 10 ** 6);
        usdc.transfer(user, 1000 * 10 ** 6);

        // Register a hotel for testing
        vm.startPrank(hotelOwner);
        usdc.approve(address(registry), tokenAmount);
        hotelId = registry.registerHotel(
            hotelName,
            tokenAmount,
            usdcPrice,
            totalMonths,
            auctionDuration
        );
        vm.stopPrank();

        vaultAddress = registry.getVaultAddress(hotelId);
        hotelAVS = LaLoHotelAVS(registry.getHotelAVS(hotelId));
    }

    function testUnderwriterRegistration() public {
        // 1. Test underwriter registration
        vm.startPrank(underwriter1);
        uint256 stakeAmount = 1000 * 10 ** 6;
        usdc.approve(address(underwriterSystem), stakeAmount);
        underwriterSystem.registerAsUnderwriter(stakeAmount);
        vm.stopPrank();

        // Verify registration
        assertTrue(
            underwriterSystem.isRegisteredUnderwriter(underwriter1),
            "Underwriter should be registered"
        );

        (
            uint256 totalStake,
            uint256 availableStake,
            uint256 lockedStake
        ) = underwriterSystem.underwriters(underwriter1);
        assertEq(totalStake, stakeAmount, "Total stake should match");
        assertEq(availableStake, stakeAmount, "Available stake should match");
        assertEq(lockedStake, 0, "Locked stake should be zero");

        // 2. Test additional stake
        vm.startPrank(underwriter1);
        uint256 additionalStake = 500 * 10 ** 6;
        usdc.approve(address(underwriterSystem), additionalStake);
        underwriterSystem.registerAsUnderwriter(additionalStake);
        vm.stopPrank();

        // Verify updated stake
        (totalStake, availableStake, lockedStake) = underwriterSystem
            .underwriters(underwriter1);
        assertEq(
            totalStake,
            stakeAmount + additionalStake,
            "Total stake should be updated"
        );
        assertEq(
            availableStake,
            stakeAmount + additionalStake,
            "Available stake should be updated"
        );

        // 3. Test registration with zero amount (should fail)
        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), 0);
        vm.expectRevert(); // Should revert with InvalidStakeAmount
        underwriterSystem.registerAsUnderwriter(0);
        vm.stopPrank();
    }

    function testAssignUnderwritersToHotel() public {
        // Register three underwriters
        uint256 stake1 = 1000 * 10 ** 6;
        uint256 stake2 = 800 * 10 ** 6;
        uint256 stake3 = 600 * 10 ** 6;

        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stake1);
        underwriterSystem.registerAsUnderwriter(stake1);
        vm.stopPrank();

        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), stake2);
        underwriterSystem.registerAsUnderwriter(stake2);
        vm.stopPrank();

        vm.startPrank(underwriter3);
        usdc.approve(address(underwriterSystem), stake3);
        underwriterSystem.registerAsUnderwriter(stake3);
        vm.stopPrank();

        // Set up underwriter assignment parameters
        address[] memory underwriterAddresses = new address[](3);
        underwriterAddresses[0] = underwriter1;
        underwriterAddresses[1] = underwriter2;
        underwriterAddresses[2] = underwriter3;

        uint256[] memory stakeAmounts = new uint256[](3);
        stakeAmounts[0] = 600 * 10 ** 6;
        stakeAmounts[1] = 400 * 10 ** 6;
        stakeAmounts[2] = 200 * 10 ** 6;

        uint256 underwriterFee = 100 * 10 ** 6;

        // Test assignment by non-owner (should fail)
        vm.startPrank(user);
        vm.expectRevert(); // NotHotelOwner
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        vm.stopPrank();

        // Test successful assignment by hotel owner
        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        vm.stopPrank();

        // Verify assignments
        for (uint256 i = 0; i < underwriterAddresses.length; i++) {
            uint256 assignedStake = underwriterSystem.getUnderwriterStake(
                hotelId,
                underwriterAddresses[i]
            );
            assertEq(
                assignedStake,
                stakeAmounts[i],
                "Assigned stake should match"
            );
        }

        // Verify underwriter locked stake
        (, , uint256 lockedStake1) = underwriterSystem.underwriters(
            underwriter1
        );
        assertEq(
            lockedStake1,
            600 * 10 ** 6,
            "Underwriter1 locked stake should match"
        );

        // Test underwriter available stake is reduced
        (uint256 total1, uint256 available1, ) = underwriterSystem.underwriters(
            underwriter1
        );
        assertEq(total1, 1000 * 10 ** 6, "Total stake should remain unchanged");
        assertEq(
            available1,
            400 * 10 ** 6,
            "Available stake should be reduced"
        );

        // Test double assignment (should fail)
        vm.startPrank(hotelOwner);
        vm.expectRevert(); // UnderwriterAlreadyAssigned
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        vm.stopPrank();
    }

    function testDepositUnderwriterFee() public {
        // Setup underwriters
        uint256 stake1 = 800 * 10 ** 6;
        uint256 stake2 = 600 * 10 ** 6;

        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stake1);
        underwriterSystem.registerAsUnderwriter(stake1);
        vm.stopPrank();

        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), stake2);
        underwriterSystem.registerAsUnderwriter(stake2);
        vm.stopPrank();

        // Assign underwriters
        address[] memory underwriterAddresses = new address[](2);
        underwriterAddresses[0] = underwriter1;
        underwriterAddresses[1] = underwriter2;

        uint256[] memory stakeAmounts = new uint256[](2);
        stakeAmounts[0] = 500 * 10 ** 6;
        stakeAmounts[1] = 300 * 10 ** 6;

        uint256 underwriterFee = 80 * 10 ** 6;

        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );

        // Test fee deposit by non-owner (should fail)
        vm.stopPrank();
        vm.startPrank(user);
        vm.expectRevert(); // NotHotelOwner
        underwriterSystem.depositUnderwriterFee(hotelId);
        vm.stopPrank();

        // Test successful fee deposit by owner
        vm.startPrank(hotelOwner);
        usdc.approve(address(underwriterSystem), underwriterFee);
        underwriterSystem.depositUnderwriterFee(hotelId);
        vm.stopPrank();

        // Verify fee deposit
        uint256 underwriterSystemBalance = usdc.balanceOf(
            address(underwriterSystem)
        );
        assertEq(
            underwriterSystemBalance,
            underwriterFee,
            "Underwriter system should have the fee"
        );
    }

    function testPayRevenueLiability() public {
        // Setup underwriters
        uint256 stake1 = 800 * 10 ** 6;
        uint256 stake2 = 400 * 10 ** 6;

        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stake1);
        underwriterSystem.registerAsUnderwriter(stake1);
        vm.stopPrank();

        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), stake2);
        underwriterSystem.registerAsUnderwriter(stake2);
        vm.stopPrank();

        // Assign underwriters
        address[] memory underwriterAddresses = new address[](2);
        underwriterAddresses[0] = underwriter1;
        underwriterAddresses[1] = underwriter2;

        uint256[] memory stakeAmounts = new uint256[](2);
        stakeAmounts[0] = 600 * 10 ** 6;
        stakeAmounts[1] = 300 * 10 ** 6;

        uint256 underwriterFee = 50 * 10 ** 6;

        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        usdc.approve(address(underwriterSystem), underwriterFee);
        underwriterSystem.depositUnderwriterFee(hotelId);
        vm.stopPrank();

        // Test paying liability
        uint256 missingAmount = 90 * 10 ** 6; // 90 USDC missing

        // Get initial balances
        uint256 initialVaultBalance = usdc.balanceOf(vaultAddress);
        (, , uint256 initialLocked1) = underwriterSystem.underwriters(
            underwriter1
        );
        (, , uint256 initialLocked2) = underwriterSystem.underwriters(
            underwriter2
        );

        // Pay liability
        underwriterSystem.payRevenueLiability(hotelId, missingAmount);

        // Verify liability payment
        uint256 finalVaultBalance = usdc.balanceOf(vaultAddress);
        assertEq(
            finalVaultBalance - initialVaultBalance,
            missingAmount,
            "Vault should receive the missing amount"
        );

        // Verify underwriter locked stakes were reduced
        (, , uint256 finalLocked1) = underwriterSystem.underwriters(
            underwriter1
        );
        (, , uint256 finalLocked2) = underwriterSystem.underwriters(
            underwriter2
        );

        // Underwriter1 should pay 2/3 of the missing amount
        uint256 expected1 = initialLocked1 - (missingAmount * 600) / 900;
        // Underwriter2 should pay 1/3 of the missing amount
        uint256 expected2 = initialLocked2 - (missingAmount * 300) / 900;

        assertEq(
            finalLocked1,
            expected1,
            "Underwriter1 locked stake should be reduced proportionally"
        );
        assertEq(
            finalLocked2,
            expected2,
            "Underwriter2 locked stake should be reduced proportionally"
        );
    }

    function testClaimUnderwriterFee() public {
        // Setup underwriters
        uint256 stake1 = 800 * 10 ** 6;
        uint256 stake2 = 400 * 10 ** 6;

        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stake1);
        underwriterSystem.registerAsUnderwriter(stake1);
        vm.stopPrank();

        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), stake2);
        underwriterSystem.registerAsUnderwriter(stake2);
        vm.stopPrank();

        // Assign underwriters
        address[] memory underwriterAddresses = new address[](2);
        underwriterAddresses[0] = underwriter1;
        underwriterAddresses[1] = underwriter2;

        uint256[] memory stakeAmounts = new uint256[](2);
        stakeAmounts[0] = 600 * 10 ** 6;
        stakeAmounts[1] = 300 * 10 ** 6;

        uint256 underwriterFee = 95 * 10 ** 6; // 95 USDC fee

        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        usdc.approve(address(underwriterSystem), underwriterFee);
        underwriterSystem.depositUnderwriterFee(hotelId);
        vm.stopPrank();

        // Test claiming fee before period end (should fail)
        vm.startPrank(underwriter1);
        vm.expectRevert(); // ClaimPeriodExpired
        underwriterSystem.claimUnderwriterFee(hotelId);
        vm.stopPrank();

        // Warp to end of contract period
        vm.warp(block.timestamp + 366 days);

        // Test successful fee claim by first underwriter
        uint256 initialBalance1 = usdc.balanceOf(underwriter1);
        vm.startPrank(underwriter1);
        underwriterSystem.claimUnderwriterFee(hotelId);
        vm.stopPrank();

        uint256 totalFee = (95 * 10 ** 6 * 95) / 100; // 95% after protocol fee

        uint256 finalBalance1 = usdc.balanceOf(underwriter1);
        uint256 expectedFee1 = (totalFee * 600) / 900; // 2/3 of totalFee

        assertApproxEqRel(
            finalBalance1 - initialBalance1,
            expectedFee1,
            0.01e18, // 1% tolerance for rounding
            "Underwriter1 should receive correct fee share"
        );

        // Test successful fee claim by second underwriter
        uint256 initialBalance2 = usdc.balanceOf(underwriter2);
        vm.startPrank(underwriter2);
        underwriterSystem.claimUnderwriterFee(hotelId);
        vm.stopPrank();

        uint256 finalBalance2 = usdc.balanceOf(underwriter2);
        uint256 expectedFee2 = (totalFee * 300) / 900; // 1/3 of totalFee

        assertApproxEqRel(
            finalBalance2 - initialBalance2,
            expectedFee2,
            0.01e18, // 1% tolerance for rounding
            "Underwriter2 should receive correct fee share"
        );

        // Verify locked stake is returned to available
        (
            uint256 total1,
            uint256 available1,
            uint256 locked1
        ) = underwriterSystem.underwriters(underwriter1);
        assertEq(locked1, 0, "Locked stake should be zero after claiming");
        assertEq(
            available1,
            total1,
            "Available stake should equal total stake after claiming"
        );
    }

    function testWithdrawStake() public {
        // Register underwriter
        uint256 stakeAmount = 1000 * 10 ** 6;
        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stakeAmount);
        underwriterSystem.registerAsUnderwriter(stakeAmount);

        // Assign 400 USDC of stake to a hotel
        address[] memory underwriterAddresses = new address[](1);
        underwriterAddresses[0] = underwriter1;

        uint256[] memory stakeAmounts = new uint256[](1);
        stakeAmounts[0] = 400 * 10 ** 6;

        vm.stopPrank();

        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            50 * 10 ** 6
        );
        vm.stopPrank();

        // Try to withdraw more than available (should fail)
        vm.startPrank(underwriter1);
        vm.expectRevert(); // NotAllowedToWithdraw
        underwriterSystem.withdrawStake(700 * 10 ** 6);

        // Withdraw available stake
        uint256 initialBalance = usdc.balanceOf(underwriter1);
        underwriterSystem.withdrawStake(500 * 10 ** 6);
        uint256 finalBalance = usdc.balanceOf(underwriter1);
        vm.stopPrank();

        // Verify withdrawal
        assertEq(
            finalBalance - initialBalance,
            500 * 10 ** 6,
            "Underwriter should receive withdrawn stake"
        );

        // Verify stake update
        (uint256 total, uint256 available, uint256 locked) = underwriterSystem
            .underwriters(underwriter1);
        assertEq(total, 500 * 10 ** 6, "Total stake should be reduced");
        assertEq(available, 100 * 10 ** 6, "Available stake should be reduced");
        assertEq(locked, 400 * 10 ** 6, "Locked stake should remain unchanged");
    }

    function testMultipleHotelsForUnderwriter() public {
        // Register a second hotel
        vm.startPrank(hotelOwner);
        uint256 hotel2Id = registry.registerHotel(
            "LaLo Hotel 2",
            tokenAmount,
            usdcPrice,
            totalMonths,
            auctionDuration
        );
        vm.stopPrank();

        // Register underwriter
        uint256 stakeAmount = 1000 * 10 ** 6;
        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), stakeAmount);
        underwriterSystem.registerAsUnderwriter(stakeAmount);
        vm.stopPrank();

        // Assign underwriter to first hotel
        address[] memory underwriterAddresses1 = new address[](1);
        underwriterAddresses1[0] = underwriter1;

        uint256[] memory stakeAmounts1 = new uint256[](1);
        stakeAmounts1[0] = 400 * 10 ** 6;

        vm.startPrank(hotelOwner);
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses1,
            stakeAmounts1,
            50 * 10 ** 6
        );

        // Assign underwriter to second hotel
        address[] memory underwriterAddresses2 = new address[](1);
        underwriterAddresses2[0] = underwriter1;

        uint256[] memory stakeAmounts2 = new uint256[](1);
        stakeAmounts2[0] = 300 * 10 ** 6;

        underwriterSystem.assignUnderwritersToHotel(
            hotel2Id,
            underwriterAddresses2,
            stakeAmounts2,
            50 * 10 ** 6
        );
        vm.stopPrank();

        // Verify stakes for both hotels
        uint256 stake1 = underwriterSystem.getUnderwriterStake(
            hotelId,
            underwriter1
        );
        uint256 stake2 = underwriterSystem.getUnderwriterStake(
            hotel2Id,
            underwriter1
        );

        assertEq(stake1, 400 * 10 ** 6, "Stake for hotel 1 should match");
        assertEq(stake2, 300 * 10 ** 6, "Stake for hotel 2 should match");

        // Verify underwriter's available and locked stake
        (uint256 total, uint256 available, uint256 locked) = underwriterSystem
            .underwriters(underwriter1);
        assertEq(total, 1000 * 10 ** 6, "Total stake should match");
        assertEq(
            available,
            300 * 10 ** 6,
            "Available stake should be reduced by both hotels"
        );
        assertEq(
            locked,
            700 * 10 ** 6,
            "Locked stake should include both hotels"
        );

        // Test liability payment from both hotels
        uint256 liability1 = 50 * 10 ** 6;
        uint256 liability2 = 30 * 10 ** 6;

        underwriterSystem.payRevenueLiability(hotelId, liability1);
        underwriterSystem.payRevenueLiability(hotel2Id, liability2);

        // Verify locked stake reduction
        (, , locked) = underwriterSystem.underwriters(underwriter1);
        assertEq(
            locked,
            620 * 10 ** 6,
            "Locked stake should be reduced by liability payments"
        );
    }
}
