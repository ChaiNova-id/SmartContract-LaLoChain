// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC usdc;

    function setUp() public {
        usdc = new MockUSDC();
    }

    function testInitialSupply() public view {
        assertEq(usdc.balanceOf(address(this)), 1_000_000 * 10 ** 6, "Initial supply should be 1,000,000 USDC");
        assertEq(usdc.decimals(), 6, "USDC should have 6 decimals");
    }
}
