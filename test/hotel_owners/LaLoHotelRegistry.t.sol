// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LaLoToken} from "../../src/token_exchange/LaLoToken.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoVault} from "../../src/revenue_stream/LaLoVault.sol";
import {LaLoHotelRegistry} from "../../src/hotel_owners/LaLoHotelRegistry.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract LaLoHotelRegistryTest is Test {
    MockUSDC usdc;
    LaLoTokenFactory factory;
    LaLoHotelRegistry registry;

    string hotelName;
    string hotelLocation;
    uint256 tokenAmount;
    uint256 totalMonths;

    function setUp() public {
        usdc = new MockUSDC(1e6);

        factory = new LaLoTokenFactory();

        registry = new LaLoHotelRegistry(
            address(usdc),
            address(factory)
        );

        hotelName = "LaLo Hotel";
        hotelLocation = "Paris, France";
        tokenAmount = 1000;
        totalMonths = 10;
    }

    function testRegisterHotelZeroToken() public {
        vm.expectRevert();
        registry.registerHotel(
            hotelName,
            hotelLocation,
            0,
            1000,
            totalMonths
        );
    }

    function testRegisterHotelZeroPrice() public {
        vm.expectRevert();
        registry.registerHotel(
            hotelName,
            hotelLocation,
            tokenAmount,
            0,
            totalMonths
        );
    }

    function testRegisterHotelExcessPrice() public {
        vm.expectRevert();
        registry.registerHotel(
            hotelName,
            hotelLocation,
            tokenAmount,
            1001,
            totalMonths
        );
    }

    function testRegisterHotelAndVault() public {
        // Test Hotel Registry
        registry.registerHotel(
          hotelName,
          hotelLocation,
          tokenAmount,
          1000,
          totalMonths
        );

        (
            address owner,
            string memory name,
            string memory location,
            address vaultAddress,
            uint256 registrationDate
        ) = registry.hotels(0);

        assertEq(owner, address(this), "Owner should be the contract deployer");
        assertEq(name, hotelName, "Hotel name should match");
        assertEq(location, hotelLocation, "Hotel location should match");
        assertEq(registrationDate, block.timestamp, "Registration date should match");

        assertTrue(
            registry.isHotelRegistered(0),
            "Hotel should be registered"
        );

        assertEq(registry.nextHotelId(), 1, "Hotel ID should be 1");

        // Test Vault
        LaLoVault vault = LaLoVault(vaultAddress);

        assertEq(vaultAddress, address(vault), "Vault address should match");
        assertEq(registry.getVaultAddress(0), vaultAddress, "Vault address should match");

        assertEq(
            vault.usdcToken().balanceOf(vaultAddress),
            0,
            "USDC balance should be 0"
        );

        LaLoToken token = vault.getToken();

        assertEq(token.balanceOf(vaultAddress), tokenAmount, "Token amount should match");
        assertEq(token.totalSupply(), tokenAmount, "Token total supply should match");
        assertEq(token.decimals(), 18, "Token should have 18 decimals");

        assertEq(vault.owner(), address(this), "Vault owner should match registry owner");
        assertEq(vault.ratio(), 1e18, "Vault ratio should be 1e18");
        assertEq(
          vault.rate(),
          tokenAmount * 1e18 / 1000,
          "Vault rate should match"
        );

        assertEq(
            vault.totalMonth(),
            totalMonths,
            "Vault total months should match"
        );

        assertEq(
            vault.totalRevenue(),
            tokenAmount,
            "Vault total revenue should match"
        );

        assertEq(
            vault.registrationDate(),
            block.timestamp,
            "Vault registration date should match"
        );

        assertEq(
            vault.getAvailableTokens(),
            tokenAmount,
            "Vault initial available tokens should match"
        );

        assertEq(
            vault.getAvailableRevenues(),
            0,
            "Vault available revenues should be 0"
        );

        assertEq(
            vault.promisedRevenue(),
            tokenAmount,
            "Vault promised revenue should match"
        );

        assertEq(
            vault.remainingPromisedRevenue(),
            tokenAmount,
            "Vault remaining promised revenue should match"
        );

        // USDC holder
        address bank = address(this);

        // Buying shares case
        address alice = vm.addr(0x1);
        usdc.transfer(alice, 100);

        assertEq(
            usdc.balanceOf(alice),
            100,
            "Alice should have 100 USDC"
        );

        vm.startPrank(alice);
        usdc.approve(vaultAddress, 1000);
        vm.stopPrank();

        // Zero transaction
        vm.expectRevert();
        vault.buyShares(alice, 0);

        // Exceeding stock transaction
        vm.expectRevert();
        vault.buyShares(alice, 1001);

        // Out of budget transaction
        vm.expectRevert();
        vault.buyShares(alice, 101);

        // Successful transaction
        vault.buyShares(alice, 100);

        // Check vault's remaining LLoT
        assertEq(
          vault.getAvailableTokens(),
          900,
          "Vault should lose 100 tokens"
        );

        // Check Alice's USDC balance
        assertEq(
            usdc.balanceOf(alice),
            0,
            "Alice should have 0 USDC"
        );

        // Check Alice's LLoT balance
        assertEq(
            token.balanceOf(alice),
            100,
            "Alice should have 100 LLoT tokens"
        );

        // Check Alice's LLoT balance from vault
        assertEq(
            vault.checkBalance(alice),
            100,
            "Vault should have 100 LLoT tokens for Alice"
        );

        // Check Alice's withdraw limit
        assertEq(
            vault.getTransferLimit(alice),
            0,
            "Alice's withdraw limit should be 0"
        );

        // Check Alice's claimed revenues
        assertEq(
            vault.getClaimedRevenues(alice),
            0,
            "Alice's claimed revenues should be 0"
        );

        // Try withdraw for Alice
        vm.expectRevert();
        vault.withdraw(alice, 100);

        // Try not owner deposit
        vm.expectRevert();
        vault.deposit(alice, 100);

        // Bank doing deposit
        usdc.approve(vaultAddress, 1001);

        // Zero deposit
        vm.expectRevert();
        vault.deposit(bank, 0);

        // Excessive deposit
        vm.expectRevert();
        vault.deposit(bank, 1001);

        // Successful deposit
        vault.deposit(bank, 90);

        // Check available revenues
        assertEq(
          vault.getAvailableRevenues(),
          90,
          "Available revenues should match"
        );

        assertEq(
          vault.getRemainingPromisedRevenues(),
          910,
          "Available revenues should match"
        );

        // Alice's transfer limit must be still zero
        assertEq(
          vault.getTransferLimit(alice),
          0,
          "Transfer limit must be still 0 due to unchanged month"
        );

        // Simulate one month passed
        vm.warp(block.timestamp + 2_592_000);

        // Check Alice's transfer limit should be 1/10 (10%) from the initial deposit already
        assertEq(
          vault.getTransferLimit(alice),
          10,
          "Transfer limit must change to 10 due to monthly shares"
        );

        // Alice try withdraw 4 USDC
        vault.withdraw(alice, 4);

        // Alice check current USDC
        assertEq(
          usdc.balanceOf(alice),
          4,
          "Alice's balance must be updated to 4"
        );

        // Alice check withdrawn from vault
        assertEq(
          vault.claimedRevenuesInLLoT(alice),
          4,
          "Alice's withdrawn must be updated to 4"
        );

        // Alice check remaining limit
        assertEq(
          vault.getTransferLimit(alice),
          6,
          "Alice's transfer limit must be 6 left"
        );

        // Vault's balance must lose 4 usdc
        assertEq(
          vault.getAvailableRevenues(),
          86,
          "Available revenues should lose 4 USDC"
        );

        // Warp time to 4 months afterwards
        vm.warp(block.timestamp + 2_592_000 * 4);

        // Check Alice's limit
        assertEq(
          vault.getTransferLimit(alice),
          46,
          "Alice's transfer limit must be 46 (40 for 4 months + previous remaining 6)"
        );

        // Try withdraw all
        vault.withdraw(alice, 46);

        // Check limit
        assertEq(
          vault.getTransferLimit(alice),
          0,
          "Alice's transfer limit must be 0 due to full withdraw"
        );

        // Check claimed revenues
        assertEq(
          vault.claimedRevenuesInLLoT(alice),
          50,
          "Alice should've withdrawn 46 + 4 USDC"
        );

        // Check revenue
        assertEq(
          vault.getAvailableRevenues(),
          40,
          "Available revenues should lose 46 + 4 USDC"
        );

        // Warp to more than the time limit
        vm.warp(block.timestamp + 2_592_000 * 10);

        // Check Alice's transfer limit
        assertEq(
          vault.getTransferLimit(alice),
          50,
          "Alice's transfer limit must be 50 due to remaining "
        );

        // Try to pull all but restricted to not enough revenue
        vm.expectRevert();
        vault.withdraw(alice, 50);

        // Bank fulfill the promise
        usdc.approve(vaultAddress, 910);
        vault.deposit(bank, 910);

        // Alice retry withdraw
        vault.withdraw(alice, 50);

        // Final values recheck
        assertEq(
          usdc.balanceOf(alice),
          100,
          "Alice should've withdrawn 46 + 4 + 50 USDC"
        );

        assertEq(
          vault.claimedRevenuesInLLoT(alice),
          100,
          "Alice should've withdrawn 46 + 4 + 50 USDC"
        );

        assertEq(
          vault.getAvailableRevenues(),
          900,
          "Available revenues should lose 46 + 4 + 50 USDC"
        );

        assertEq(
          vault.getRemainingPromisedRevenues(),
          0,
          "Remaining promised revenue must be 0"
        );
    }
}