// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LaLoHotelTokenization} from "../../src/revenue_stream/LaLoHotelTokenization.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelRegistry} from "../../src/hotel_owners/LaLoHotelRegistry.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract LaLoHotelTokenizationTest is Test {
    MockUSDC usdc;
    LaLoHotelRegistry registry;
    LaLoTokenFactory factory;
    LaLoHotelTokenization tokenization;

    string hotelName;
    uint256 tokenAmount;
    uint256 totalMonths;
    uint256 duration;

    function setUp() public {
        usdc = new MockUSDC(1e6, "LaLoUSDC", "LUSDC");

        factory = new LaLoTokenFactory();

        registry = new LaLoHotelRegistry(address(usdc), address(factory));

        tokenization = new LaLoHotelTokenization(address(usdc), address(registry));

        hotelName = "LaLo Hotel";
        tokenAmount = 1000;
        totalMonths = 10;
        duration = 604_800; // 7 days in seconds
    }

    function testTokenization() public {
        registry.registerHotel(hotelName, tokenAmount, 1000, totalMonths, duration);

        (,, address vaultAddress) = registry.hotels(0);

        // Check getRate
        uint256 defaultRatio = 1e18;
        assertEq(tokenization.getRatio(0), defaultRatio, "Ratio should be 1e18");
        assertEq(tokenization.getRate(0), 1000 * defaultRatio / tokenAmount, "Rate should be 1000 USDC per 1 LLoT");

        // Check auctionDurartion
        assertEq(tokenization.getAuctionEndDate(0), block.timestamp + duration, "Auction duration should match");

        // Buying shares case
        address alice = vm.addr(0x1);
        usdc.transfer(alice, 100);

        assertEq(usdc.balanceOf(alice), 100, "Alice should have 100 USDC");

        vm.startPrank(alice);
        usdc.approve(vaultAddress, 1000);

        // Zero transaction
        vm.expectRevert();
        tokenization.buyLaLoTokens(0, 0);

        // Exceeding stock transaction
        vm.expectRevert();
        tokenization.buyLaLoTokens(0, 1001);

        // Out of budget transaction
        vm.expectRevert();
        tokenization.buyLaLoTokens(0, 101);

        // Successful transaction
        tokenization.buyLaLoTokens(0, 100);

        // Check vault's remaining LLoT
        assertEq(tokenization.getAvailableTokens(0), 900, "Vault should lose 100 tokens");

        // Check Alice's USDC balance
        assertEq(usdc.balanceOf(alice), 0, "Alice should have 0 USDC");

        // Check Alice's LLoT balance from vault
        assertEq(tokenization.getCurrentTokens(0), 100, "Vault should have 100 LLoT tokens for Alice");

        // Check Alice's withdraw limit
        assertEq(tokenization.getTransferLimit(0), 0, "Alice's withdraw limit should be 0");

        // Check Alice's claimed revenues
        assertEq(tokenization.getCollectedRevenues(0), 0, "Alice's claimed revenues should be 0");

        // Try withdraw for Alice
        vm.expectRevert();
        tokenization.withdrawUSDC(0, 100);

        // Try not owner deposit
        vm.expectRevert();
        tokenization.ownerDepositUSDC(0, 100);

        vm.stopPrank();

        // Bank doing deposit
        usdc.approve(vaultAddress, 1001);

        // Zero deposit
        vm.expectRevert();
        tokenization.ownerDepositUSDC(0, 0);

        // Excessive deposit
        vm.expectRevert();
        tokenization.ownerDepositUSDC(0, 1001);

        // Successful deposit
        tokenization.ownerDepositUSDC(0, 90);

        // Check available revenues
        assertEq(tokenization.getAvailableRevenues(0), 90, "Available revenues should match");

        assertEq(tokenization.getRemainingPromisedRevenues(0), 910, "Remaining promised revenues should match");

        // Alice's transfer limit must be still zero
        vm.startPrank(alice);
        assertEq(tokenization.getTransferLimit(0), 0, "Transfer limit must be still 0 due to unchanged month");

        // Simulate one month passed
        vm.warp(block.timestamp + 2_592_000);

        // Check Alice's transfer limit should be 1/10 (10%) from the initial deposit already
        assertEq(tokenization.getTransferLimit(0), 10, "Transfer limit must change to 10 due to monthly shares");

        // Alice try withdraw 4 USDC
        tokenization.withdrawUSDC(0, 4);

        // Expect fail for buying after duration passed
        vm.expectRevert();
        tokenization.buyLaLoTokens(0, 4);

        // Alice check current USDC
        assertEq(usdc.balanceOf(alice), 4, "Alice's balance must be updated to 4");

        // Alice check withdrawn from vault
        assertEq(tokenization.getCollectedRevenues(0), 4, "Alice's withdrawn must be updated to 4");

        // Alice check remaining limit
        assertEq(tokenization.getTransferLimit(0), 6, "Alice's transfer limit must be 6 left");

        // Vault's balance must lose 4 usdc
        assertEq(tokenization.getAvailableRevenues(0), 86, "Available revenues should lose 4 USDC");

        // Warp time to 4 months afterwards
        vm.warp(block.timestamp + 2_592_000 * 4);

        // Check Alice's limit
        assertEq(
            tokenization.getTransferLimit(0),
            46,
            "Alice's transfer limit must be 46 (40 for 4 months + previous remaining 6)"
        );

        // Try withdraw all
        tokenization.withdrawUSDC(0, 46);

        // Check limit
        assertEq(tokenization.getTransferLimit(0), 0, "Alice's transfer limit must be 0 due to full withdraw");

        // Check claimed revenues
        assertEq(tokenization.getCollectedRevenues(0), 50, "Alice should've withdrawn 46 + 4 USDC");

        // Check revenue
        assertEq(tokenization.getAvailableRevenues(0), 40, "Available revenues should lose 46 + 4 USDC");

        // Warp to more than the time limit
        vm.warp(block.timestamp + 2_592_000 * 10);

        // Check Alice's transfer limit
        assertEq(tokenization.getTransferLimit(0), 50, "Alice's transfer limit must be 50 due to remaining ");

        // Try to pull all but restricted to not enough revenue
        vm.expectRevert();
        tokenization.withdrawUSDC(0, 50);

        vm.stopPrank();
        // Bank fulfill the promise
        usdc.approve(vaultAddress, 910);
        tokenization.ownerDepositUSDC(0, 910);

        // Alice retry withdraw
        vm.startPrank(alice);
        tokenization.withdrawUSDC(0, 50);

        // Final values recheck
        assertEq(tokenization.getCollectedRevenues(0), 100, "Alice should've withdrawn 46 + 4 + 50 USDC");

        vm.stopPrank();
        assertEq(usdc.balanceOf(alice), 100, "Alice should've withdrawn 46 + 4 + 50 USDC");

        assertEq(tokenization.getAvailableRevenues(0), 900, "Available revenues should lose 46 + 4 + 50 USDC");

        assertEq(tokenization.getRemainingPromisedRevenues(0), 0, "Remaining promised revenue must be 0");
    }
}
