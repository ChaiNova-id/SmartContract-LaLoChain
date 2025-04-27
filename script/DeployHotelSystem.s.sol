// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MockUSDC} from "../src/token_exchange/MockUSDC.sol";
import {LaLoTokenFactory} from "../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelRegistry} from "../src/hotel_owners/LaLoHotelRegistry.sol";
import {LaLoHotelTokenization} from "../src/revenue_stream/LaLoHotelTokenization.sol";

contract DeployHotelSystem is Script {
    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        // Deploy Mock USDC
        MockUSDC usdc = new MockUSDC();

        // Deploy factory
        LaLoTokenFactory factory = new LaLoTokenFactory();

        // Deploy HotelRegistry with factory address
        LaLoHotelRegistry registry = new LaLoHotelRegistry(
            address(usdc),
            address(factory)
        );

        // Deploy Tokenization with registry address
        LaLoHotelTokenization tokenization = new LaLoHotelTokenization(
            address(usdc),
            address(registry)
        );

        // Print the addresses
        console.log("MockUSDC deployed at:", address(usdc));
        console.log("LaLoTokenFactory deployed at:", address(factory));
        console.log("HotelRegistry deployed at:", address(registry));
        console.log("HotelTokenization deployed at:", address(tokenization));

        vm.stopBroadcast();
    }
}
