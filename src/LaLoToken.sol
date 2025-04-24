// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaLoToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("LaLoToken", "LLOT") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }
}