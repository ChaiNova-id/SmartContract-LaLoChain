// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RevenueTokenFactory.sol";
import "../src/HotelRegistry.sol";

contract DeployHotelSystem is Script {
    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        // Deploy factory
        RevenueTokenFactory factory = new RevenueTokenFactory();

        // Deploy HotelRegistry with factory address
        HotelRegistry registry = new HotelRegistry(address(factory));

        console.log("RevenueTokenFactory deployed at:", address(factory));
        console.log("HotelRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
