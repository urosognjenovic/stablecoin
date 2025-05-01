// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Zeni} from "./Zeni.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/shared/interfaces/AggregatorV3Interface.sol";

/// @title ZeniEngine
/// @author Uroš Ognjenović
/// @notice The system is designed to maintain the peg to 1 USD. Zeni stablecoin has the following properties: Exogenous Collateral, Dollar Peggeed, Algorithmically Stable. This contract is the core of the Zeni System. It handles all the logic for minting and burning Zeni, as well as depositing and withdrawing collateral. This contract is loosely based on the MakerDAO DAI stablecoin.
contract ZeniEngine is ReentrancyGuard {
    Zeni private immutable i_zeni;
    address[] private s_supportedCollaterals;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateral => uint256 amount)) private s_collateralBalance;
    mapping(address user => uint256 amount) private s_amountMinted;
    uint256 private constant DECIMALS = 1e18;
    uint256 private constant PRICE_FEED_PRECISION_TO_MATCH_DECIMALS_PRECISION = 1e10;
    // 200% overcollateralized
    uint256 private constant LIQUIDATION_THRESHOLD_IN_PERCENT = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1;

    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event ZeniMinted(address indexed user, uint256 amount);

    error ZeniEngine__TokensLengthIsDifferentThanPriceFeedLength();
    error ZeniEngine__AmountIsZero();
    error ZeniEngine__TokenIsZeroAddress();
    error ZeniEngine__PriceFeedIsZeroAddresss();
    error ZeniEngine__CollateralNotSupported();
    error ZeniEngine__TokenTransferFailed();
    error ZeniEngine__HealthFactorBelowMinimumThreshold();
    error ZeniEngine__MintFailed();

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

    /// @param amount The amount of Zeni to mint.
    function mintZeni(uint256 amount) external nonReentrant amountGreaterThanZero(amount) {
        address user = msg.sender;
        s_amountMinted[user] += amount;
        uint256 healthFactor = _getHealthFactor(user);
        require(healthFactor >= MINIMUM_HEALTH_FACTOR, ZeniEngine__HealthFactorBelowMinimumThreshold());
        bool success = i_zeni.mint(user, amount);
        require(success, ZeniEngine__MintFailed());
        emit ZeniMinted(user, amount);
    }

    function burnZeni() external {}

    function liquidate() external {}

    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        return _getHealthFactor(user);
    }

    function getAccountCollateralValueInUSD(address user) external view returns (uint256 collateralValueInUSD) {
        return _getAccountCollateralValueInUSD(user);
    }

    function getCollateralValueInUSD(
        address token,
        uint256 amount
    ) external view returns (uint256 collateralValueInUSD) {
        return _getCollateralValueInUSD(token, amount);
    }

    function getSupportedCollaterals() external view returns (address[] memory supportedCollaterals) {
        return s_supportedCollaterals;
    }

    function _addPriceFeed(address token, address priceFeed) private {
        require(token != address(0), ZeniEngine__TokenIsZeroAddress());
        require(priceFeed != address(0), ZeniEngine__PriceFeedIsZeroAddresss());
        s_priceFeeds[token] = priceFeed;
        s_supportedCollaterals.push(token);
    }

    function _getHealthFactor(address user) private view returns (uint256 healthFactor) {
        uint256 amountMinted = s_amountMinted[user];
        uint256 collateralValueInUSD = _getAccountCollateralValueInUSD(user);
        uint256 collateralValueAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD_IN_PERCENT) /
            LIQUIDATION_PRECISION;
        return (collateralValueAdjustedForThreshold * DECIMALS) / amountMinted;
    }

    function _getAccountCollateralValueInUSD(address user) private view returns (uint256 accountCollateralValueInUSD) {
        uint256 length = s_supportedCollaterals.length;
        for (uint8 i; i < length; ) {
            address collateral = s_supportedCollaterals[i];
            uint256 amount = s_collateralBalance[user][collateral];
            accountCollateralValueInUSD += _getCollateralValueInUSD(collateral, amount);

            unchecked {
                ++i;
            }
        }
        return accountCollateralValueInUSD;
    }

    function _getCollateralValueInUSD(
        address token,
        uint256 amount
    ) private view returns (uint256 collateralValueInUSD) {
        (, int256 price, , , ) = AggregatorV3Interface(s_priceFeeds[token]).latestRoundData();
        return (amount * (uint256(price) * PRICE_FEED_PRECISION_TO_MATCH_DECIMALS_PRECISION)) / DECIMALS;
    }
}
