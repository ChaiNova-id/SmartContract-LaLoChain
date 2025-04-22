// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LaLoTokenFactory.sol";
import "../src/LaLoHotel.sol";

contract DeployHotelSystem is Script {
    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        // Deploy factory
        LaLoTokenFactory factory = new LaLoTokenFactory();

        // Deploy HotelRegistry with factory address
        LaLoHotel registry = new LaLoHotel(address(factory));

        console.log("LaLoTokenFactory deployed at:", address(factory));
        console.log("HotelRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
