// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RevenueToken.sol";

contract RevenueTokenTest is Test {
    RevenueToken token;

    function setUp() public {
        token = new RevenueToken("HotelToken", "HTKN");
        token.transferOwnership(address(this));
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1000 ether);
        assertEq(token.balanceOf(address(0xBEEF)), 1000 ether);
    }
}
