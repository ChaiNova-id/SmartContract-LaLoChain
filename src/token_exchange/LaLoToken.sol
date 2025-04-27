// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LaLoToken is ERC20, Ownable {
    constructor(
        uint256 _initialSupply
    )
        ERC20("LaLoToken", "LLOT")
        Ownable(msg.sender)
    {
        _mint(msg.sender, _initialSupply);
    }
}