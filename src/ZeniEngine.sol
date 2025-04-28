// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Zeni} from "./Zeni.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ZeniEngine
/// @author Uroš Ognjenović
/// @notice The system is designed to maintain the peg to 1 USD. Zeni stablecoin has the following properties: Exogenous Collateral, Dollar Peggeed, Algorithmically Stable. This contract is the core of the Zeni System. It handles all the logic for minting and burning Zeni, as well as depositing and withdrawing collateral. This contract is loosely based on the MakerDAO DAI stablecoin.
contract ZeniEngine is ReentrancyGuard {
    Zeni private immutable i_zeni;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateral => uint256 amount)) private s_collateralBalance;

    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);

    error ZeniEngine__TokensLengthIsDifferentThanPriceFeedLength();
    error ZeniEngine__AmountIsZero();
    error ZeniEngine__TokenIsZeroAddress();
    error ZeniEngine__PriceFeedIsZeroAddresss();
    error ZeniEngine__CollateralNotSupported();
    error ZeniEngine__TokenTransferFailed();

    modifier amountGreaterThanZero(uint256 amount) {
        require(amount > 0, ZeniEngine__AmountIsZero());
        _;
    }

    modifier collateralSupported(address token) {
        require(s_priceFeeds[token] != address(0), ZeniEngine__CollateralNotSupported());
        _;
    }

    constructor(Zeni zeni, address[] memory tokens, address[] memory priceFeeds) {
        require(tokens.length == priceFeeds.length, ZeniEngine__TokensLengthIsDifferentThanPriceFeedLength());
        i_zeni = zeni;

        uint256 length = tokens.length;
        for (uint8 i; i < length; ) {
            _addPriceFeed(tokens[i], priceFeeds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @param collateral The address of the collateral token
    /// @param amount The amount of the collateral to deposit
    function depositCollateral(
        address collateral,
        uint256 amount
    ) external nonReentrant collateralSupported(collateral) amountGreaterThanZero(amount) {
        s_collateralBalance[msg.sender][collateral] = amount;
        emit CollateralDeposited(msg.sender, collateral, amount);
        bool success = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        require(success, ZeniEngine__TokenTransferFailed());
    }

    function depositCollateralAndMintZeni() external {}

    function redeemCollateral() external {}

    function redeemCollateralForZeni() external {}

    function mintZeni() external {}

    function burnZeni() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    function _addPriceFeed(address token, address priceFeed) internal {
        require(token != address(0), ZeniEngine__TokenIsZeroAddress());
        require(priceFeed != address(0), ZeniEngine__PriceFeedIsZeroAddresss());

        s_priceFeeds[token] = priceFeed;
    }
}
