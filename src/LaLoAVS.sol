// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LaLoTokenFactory} from "./LaLoTokenFactory.sol";

contract LaLoTokenAVS {

  error NotRegisteredToken();

  LaLoTokenFactory public factory;

  // token -> underwriter -> amount
  mapping(address => mapping(address => uint256)) public underwritingAmounts;

  constructor(address _factory) {
    factory = LaLoTokenFactory(_factory);
  }

   function underwrite(address token, uint256 amount) public {
      if(!factory.tokens(token)) revert NotRegisteredToken();
      address underwriter = msg.sender;
      underwritingAmounts[token][underwriter] += amount;
   }

}