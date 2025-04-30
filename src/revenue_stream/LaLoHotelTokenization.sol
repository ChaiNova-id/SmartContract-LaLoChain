// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHotelTokenization} from "./IHotelTokenization.sol";
import {IHotelRegistry} from "../hotel_owners/IHotelRegistry.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";

contract LaLoHotelTokenization is IHotelTokenization {
    IERC20 public usdcToken;
    LaLoHotelRegistry public hotelRegistry;

    constructor(address _usdcToken, address _hotelRegistry) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = LaLoHotelRegistry(_hotelRegistry);
    }

    modifier onlyRegisteredHotel(uint256 hotelId) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }
        _;
    }

    function buyLaLoTokens(uint256 _hotelId, uint256 _buyInUSDC) external onlyRegisteredHotel(_hotelId) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        vault.buyShares(msg.sender, _buyInUSDC);
        emit TokensBought(_hotelId, msg.sender, _buyInUSDC);
    }

    function withdrawUSDC(uint256 _hotelId, uint256 _withdrawInUSDC) external onlyRegisteredHotel(_hotelId) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        vault.withdraw(msg.sender, _withdrawInUSDC);
        emit USDCWithdrawn(_hotelId, msg.sender, _withdrawInUSDC);
    }

    function ownerDepositUSDC(uint256 _hotelId, uint256 _depositInUSDC) external onlyRegisteredHotel(_hotelId) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        vault.deposit(msg.sender, _depositInUSDC);
        emit USDCWithdrawn(_hotelId, msg.sender, _depositInUSDC);
    }

    function getAvailableTokens(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.getAvailableTokens();
    }

    function getAvailableRevenues(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.getAvailableRevenues();
    }

    function getRatio(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.ratio();
    }

    function getRate(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.rate();
    }

    function getAuctionEndDate(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.registrationDate() + vault.auctionDuration();
    }

    function getTransferLimit(uint256 _hotelId) external view returns (uint256 limit) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        limit = vault.getTransferLimit(msg.sender);
    }

    function getVaultAddress(uint256 _hotelId) external view returns (address vaultAddress) {
        return hotelRegistry.getVaultAddress(_hotelId);
    }

    function getCurrentTokens(uint256 _hotelId) external view returns (uint256 lloTokens) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        lloTokens = vault.checkBalance(msg.sender);
    }

    function getCollectedRevenues(uint256 _hotelId) external view returns (uint256 usdcs) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        usdcs = vault.getClaimedRevenues(msg.sender);
    }

    function getRemainingPromisedRevenues(uint256 _hotelId) external view returns (uint256 remainingRevs) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        remainingRevs = vault.remainingPromisedRevenue();
    }

    // Testing purposes
    function setMonthTest(uint256 _hotelId, uint256 _month) external {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        vault.setTestPurposes(msg.sender, _month);
    }

    function getMonthTest(uint256 _hotelId) external view returns (uint256 month) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        month = vault.getMonths();
    }
}
