// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LaLoToken} from "./LaLoToken.sol";

contract LaLoTokenFactory {

  mapping(address => bool) public tokens;

  function deployToken(uint256 amount) public returns (address) {
    LaLoToken token = new LaLoToken(amount);
    token.transfer(msg.sender, amount);
    tokens[address(token)] = true;
    return address(token);
  }

}