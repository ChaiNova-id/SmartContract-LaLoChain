// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MockUSDC} from "../src/token_exchange/MockUSDC.sol";
import {LaLoTokenFactory} from "../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelRegistry} from "../src/hotel_owners/LaLoHotelRegistry.sol";
import {LaLoHotelTokenization} from "../src/revenue_stream/LaLoHotelTokenization.sol";
import {LaLoUnderwriterSystem} from "../src/underwriter/LaLoUnderwriterSystem.sol";

contract DeployHotelSystem is Script {
    function setUp() public {}

    function run() external {
        address sender = vm.envAddress("SENDER_ADDRESS");

        // Get current nonce dynamically
        uint64 nonce = vm.getNonce(sender);

        vm.startBroadcast();
        vm.setNonce(sender, nonce);

        // Deploy Mock USDC
        MockUSDC usdc = new MockUSDC(1e32, "LaLoUSDC", "LUSDC");

        // Deploy factory
        LaLoTokenFactory factory = new LaLoTokenFactory();

        // Deploy HotelRegistry with factory address
        LaLoHotelRegistry registry = new LaLoHotelRegistry(address(usdc), address(factory));

        // Deploy Tokenization with registry address
        LaLoHotelTokenization tokenization = new LaLoHotelTokenization(address(usdc), address(registry));

        // Deploy Underwriter system
        LaLoUnderwriterSystem underwriterSystem = new LaLoUnderwriterSystem(address(usdc), address(registry));

        // Set the underwriter system in the registry
        registry.setUnderwriterSystem(address(underwriterSystem));

        // Print the addresses
        console.log("MockUSDC deployed at:", address(usdc));
        console.log("LaLoTokenFactory deployed at:", address(factory));
        console.log("HotelRegistry deployed at:", address(registry));
        console.log("HotelTokenization deployed at:", address(tokenization));
        console.log("UnderwriterSystem deployed at:", address(underwriterSystem));
        console.log("Note: LaLoHotelAVS will be deployed per hotel during registration.");

        vm.stopBroadcast();
    }
}
