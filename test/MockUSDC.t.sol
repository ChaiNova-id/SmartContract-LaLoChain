// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC usdc;

    function setUp() public {
        usdc = new MockUSDC();
    }

    function testInitialSupply() public {
        assertEq(usdc.balanceOf(address(this)), 1_000_000 * 10 ** 6);
        assertEq(usdc.decimals(), 6);
    }
}
