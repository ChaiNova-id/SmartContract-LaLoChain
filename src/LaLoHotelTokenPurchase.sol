// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol";
import {LaLoToken} from "./LaLoToken.sol";

contract LaLoHotelTokenPurchase {
    error USDCTransferFailed();
    error HotelNotRegistered();

    event TokensBought(uint256 indexed hotelId, address indexed buyer, uint256 amount);

    IERC20 public usdcToken;
    IHotelRegistry public hotelRegistry;

    constructor(address _usdcToken, address _hotelRegistry) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    // Function to buy hotel tokens
    function buyHotelTokens(uint256 hotelId, uint256 amountInUSDC) public {
        // Ensure the hotel is registered
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }

        // Fetch the hotel details
        IHotelRegistry.Hotel memory hotel = hotelRegistry.getHotel(hotelId);

        // Transfer USDC from the user to the registry contract
        if (!usdcToken.transferFrom(msg.sender, address(this), amountInUSDC)) {
            revert USDCTransferFailed();
        }

        // Transfer the corresponding amount of hotel tokens to the user
        IERC20(hotel.tokenAddress).transfer(msg.sender, amountInUSDC); // Assuming 1:1 exchange rate for simplicity

        emit TokensBought(hotelId, msg.sender, amountInUSDC);
    }
}
