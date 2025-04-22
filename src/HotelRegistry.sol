pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Factory contract must return an ERC-20 compliant token
interface ILaLoTokenFactory {
    function createToken(uint256 hotelId) external returns (address);
}

contract HotelRegistry is AccessControl {
    ILaLoTokenFactory public tokenFactory;

    constructor(address _tokenFactory) {
        tokenFactory = ILaLoTokenFactory(_tokenFactory);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createAndTransfer(uint256 hotelId, address recipient, uint256 amount) external {
        address tokenAddr = tokenFactory.createToken(hotelId);
        IERC20(tokenAddr).transfer(recipient, amount);
    }
}
