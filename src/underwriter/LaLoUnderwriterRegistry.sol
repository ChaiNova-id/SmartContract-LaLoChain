// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoTokenFactory} from "../token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";
import {LaLoAVS} from "../avs/LaLoAVS.sol";
import {ILaLoAVS} from "../avs/ILaLoAVS.sol";

contract LaLoUnderwriterRegistry {
    IERC20 public usdcToken;
    LaLoAVS public avsSystem;

    struct Underwriter {
        address underwriterAddress;
        string name;
        uint256 reputation;
        bool isRevenueUnderwriter;
        bool isSaleUnderwriter;
        mapping(uint256 => bool) participatingHotels;
    }

    mapping(address => Underwriter) public underwriters;
    mapping(address => bool) public registeredUnderwriters;
    address[] public underwriterList;

    event UnderwriterRegistered(address indexed underwriter, string name);
    event UnderwriterParticipation(address indexed underwriter, uint256 indexed hotelId, bool isRevenue);

    constructor(address _usdcToken, address _avsSystem) {
        usdcToken = IERC20(_usdcToken);
        avsSystem = LaLoAVS(_avsSystem);
    }

    /**
     * @dev Register as an underwriter
     * @param _name Name of the underwriter
     * @param _isRevenueUnderwriter Whether underwriter guarantees revenue
     * @param _isSaleUnderwriter Whether underwriter guarantees token sales
     */
    function registerUnderwriter(string memory _name, bool _isRevenueUnderwriter, bool _isSaleUnderwriter) external {
        require(!registeredUnderwriters[msg.sender], "Already registered");
        require(_isRevenueUnderwriter || _isSaleUnderwriter, "Must be at least one type");

        Underwriter storage underwriter = underwriters[msg.sender];
        underwriter.underwriterAddress = msg.sender;
        underwriter.name = _name;
        underwriter.reputation = 100; // Starting reputation
        underwriter.isRevenueUnderwriter = _isRevenueUnderwriter;
        underwriter.isSaleUnderwriter = _isSaleUnderwriter;

        registeredUnderwriters[msg.sender] = true;
        underwriterList.push(msg.sender);

        emit UnderwriterRegistered(msg.sender, _name);
    }

    /**
     * @dev Participate in a hotel as revenue underwriter
     * @param _hotelId ID of the hotel
     * @param _stakeAmount Amount to stake
     */
    function participateAsRevenueUnderwriter(uint256 _hotelId, uint256 _stakeAmount) external {
        require(registeredUnderwriters[msg.sender], "Not registered");
        require(underwriters[msg.sender].isRevenueUnderwriter, "Not a revenue underwriter");

        // Register with AVS
        avsSystem.registerAsRevenueUnderwriter(_hotelId, _stakeAmount);

        // Mark hotel as participating
        underwriters[msg.sender].participatingHotels[_hotelId] = true;

        emit UnderwriterParticipation(msg.sender, _hotelId, true);
    }

    /**
     * @dev Participate in a hotel as sale underwriter
     * @param _hotelId ID of the hotel
     * @param _stakeAmount Amount to stake
     */
    function participateAsSaleUnderwriter(uint256 _hotelId, uint256 _stakeAmount) external {
        require(registeredUnderwriters[msg.sender], "Not registered");
        require(underwriters[msg.sender].isSaleUnderwriter, "Not a sale underwriter");

        // Register with AVS
        avsSystem.registerAsSaleUnderwriter(_hotelId, _stakeAmount);

        // Mark hotel as participating
        underwriters[msg.sender].participatingHotels[_hotelId] = true;

        emit UnderwriterParticipation(msg.sender, _hotelId, false);
    }

    /**
     * @dev Check if underwriter is participating in a hotel
     * @param _underwriter Address of underwriter
     * @param _hotelId ID of the hotel
     * @return participating Whether underwriter is participating
     */
    function isParticipatingInHotel(address _underwriter, uint256 _hotelId) external view returns (bool) {
        return underwriters[_underwriter].participatingHotels[_hotelId];
    }

    /**
     * @dev Get number of registered underwriters
     * @return count Number of underwriters
     */
    function getUnderwriterCount() external view returns (uint256) {
        return underwriterList.length;
    }

    /**
     * @dev Update underwriter reputation (only callable by AVS)
     * @param _underwriter Address of underwriter
     * @param _newReputation New reputation score
     */
    function updateReputation(address _underwriter, uint256 _newReputation) external {
        require(msg.sender == address(avsSystem), "Only AVS can update");
        require(registeredUnderwriters[_underwriter], "Not registered");

        underwriters[_underwriter].reputation = _newReputation;
    }
}
