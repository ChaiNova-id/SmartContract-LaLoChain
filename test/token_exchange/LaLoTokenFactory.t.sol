// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";

contract LaLoTokenFactoryTest is Test {
    LaLoTokenFactory factory;

    function setUp() public {
        factory = new LaLoTokenFactory();
    }

    function testDeploy() public {
        address tokenAddress = factory.deployToken(1000);
        assertTrue(factory.tokens(tokenAddress), "Token should be deployed");

        ERC20 token = ERC20(tokenAddress);
        assertEq(tokenAddress, address(token), "Token address should match");
        assertEq(token.totalSupply(), 1000, "Token amount should match");
        assertEq(token.balanceOf(address(this)), 1000, "Token balance should match");
        assertEq(token.decimals(), 18, "Token should have 18 decimals");
    }
}
