// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RevenueToken.sol";

contract RevenueTokenFactory {
    mapping(uint256 => address) public hotelTokens;

    event RevenueTokenCreated(uint256 indexed hotelId, address tokenAddress);

    function createToken(uint256 hotelId) external returns (address) {
        require(hotelTokens[hotelId] == address(0), "Token already exists");

        string memory name = string(abi.encodePacked("Hotel-", uint2str(hotelId), " Revenue Token"));
        string memory symbol = string(abi.encodePacked("HRT", uint2str(hotelId)));

        RevenueToken token = new RevenueToken(name, symbol);
        token.transferOwnership(msg.sender);

        hotelTokens[hotelId] = address(token);

        emit RevenueTokenCreated(hotelId, address(token));
        return address(token);
    }

    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }
}
