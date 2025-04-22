// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RevenueTokenFactory.sol";

contract RevenueTokenFactoryTest is Test {
    RevenueTokenFactory factory;

    function setUp() public {
        factory = new RevenueTokenFactory();
    }

    function testCreateToken() public {
        address tokenAddr = factory.createToken(1);
        assertTrue(tokenAddr != address(0));
        assertEq(factory.hotelTokens(1), tokenAddr);
    }
}
