// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LaLoTokenFactory.sol";

contract LaLoTokenFactoryTest is Test {
    LaLoTokenFactory factory;

    function setUp() public {
        factory = new LaLoTokenFactory();
    }
}
