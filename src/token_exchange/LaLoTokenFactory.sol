// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LaLoToken} from "./LaLoToken.sol";

contract LaLoTokenFactory {
    // Mapping to track deployed tokens
    mapping(address => bool) public tokens;
    LaLoToken public token;

    // Event for logging token creation
    event TokenCreated(address tokenAddress, address creator, uint256 amount);

    // Function to deploy a new token
    function deployToken(uint256 _amount) public returns (address tokenAddress) {
        // Create a new LaLoToken with the specified initial supply
        token = new LaLoToken(_amount);

        // Transfer the entire initial supply to the creator
        token.transfer(msg.sender, _amount);

        // Mark the token as deployed
        tokens[address(token)] = true;

        // Emit an event to log the creation
        emit TokenCreated(address(token), msg.sender, _amount);

        // Return the address of the newly created token contract
        return address(token);
    }
}
