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
    uint256 private constant LIQUIDATION_BONUS_IN_PERCENT = 10;

    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event ZeniMinted(address indexed user, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed collateral,
        uint256 amount
    );
    event ZeniBurned(address indexed user, uint256 amount);

    error ZeniEngine__TokensLengthIsDifferentThanPriceFeedsLength();
    error ZeniEngine__AmountIsZero();
    error ZeniEngine__TokenIsZeroAddress();
    error ZeniEngine__PriceFeedIsZeroAddresss();
    error ZeniEngine__CollateralNotSupported();
    error ZeniEngine__TokenTransferFailed();
    error ZeniEngine__HealthFactorBelowMinimumThreshold();
    error ZeniEngine__MintFailed();
    error ZeniEngine__HealthFactorIsGreaterThanMinimumHealthFactor();
    error ZeniEngine__HealthFactorNotImproved();
    error ZeniEngine__LiquidatorHealthFactorBelowMinimumThreshold();

    modifier amountGreaterThanZero(uint256 amount) {
        require(amount > 0, ZeniEngine__AmountIsZero());
        _;
    }

    modifier collateralSupported(address token) {
        require(s_priceFeeds[token] != address(0), ZeniEngine__CollateralNotSupported());
        _;
    }

    constructor(Zeni zeni, address[] memory tokens, address[] memory priceFeeds) {
        require(tokens.length == priceFeeds.length, ZeniEngine__TokensLengthIsDifferentThanPriceFeedsLength());
        i_zeni = zeni;

        uint256 length = tokens.length;
        for (uint8 i; i < length; ) {
            _addPriceFeed(tokens[i], priceFeeds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @param collateral The address of the collateral token.
    /// @param amount The amount of the collateral to deposit.
    function depositCollateral(
        address collateral,
        uint256 amount
    ) public nonReentrant collateralSupported(collateral) amountGreaterThanZero(amount) {
        s_collateralBalance[msg.sender][collateral] += amount;
        emit CollateralDeposited(msg.sender, collateral, amount);
        bool success = IERC20(collateral).transferFrom(msg.sender, address(this), amount);
        require(success, ZeniEngine__TokenTransferFailed());
    }

    /// @param collateral The address of the collateral token.
    /// @param amount The amount of the collateral to redeem.
    function redeemCollateral(address collateral, uint256 amount) public nonReentrant amountGreaterThanZero(amount) {
        _redeemCollateral(msg.sender, msg.sender, collateral, amount);
        uint256 healthFactor = getHealthFactor(msg.sender);
        require(healthFactor >= MINIMUM_HEALTH_FACTOR, ZeniEngine__HealthFactorBelowMinimumThreshold());
    }

    /// @param amount The amount of Zeni to mint.
    function mintZeni(uint256 amount) public nonReentrant amountGreaterThanZero(amount) {
        address user = msg.sender;
        s_amountMinted[user] += amount;
        uint256 healthFactor = getHealthFactor(user);
        require(healthFactor >= MINIMUM_HEALTH_FACTOR, ZeniEngine__HealthFactorBelowMinimumThreshold());
        bool success = i_zeni.mint(user, amount);
        require(success, ZeniEngine__MintFailed());
        emit ZeniMinted(user, amount);
    }

    function burnZeni(uint256 amount) public amountGreaterThanZero(amount) {
        _burnZeni(msg.sender, msg.sender, amount);
    }

    function getTokenAmountFromUSD(
        address collateral,
        uint256 amountZeniToBurn
    ) public view returns (uint256 tokenAmount) {
        (, int256 price, , , ) = AggregatorV3Interface(s_priceFeeds[collateral]).latestRoundData();
        return (amountZeniToBurn * DECIMALS) / (uint256(price) * PRICE_FEED_PRECISION_TO_MATCH_DECIMALS_PRECISION);
    }

    function getHealthFactor(address user) public view returns (uint256 healthFactor) {
        uint256 amountMinted = s_amountMinted[user];
        uint256 collateralValueInUSD = getAccountCollateralValueInUSD(user);
        uint256 collateralValueAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD_IN_PERCENT) /
            LIQUIDATION_PRECISION;
        if (amountMinted != 0) {
            return (collateralValueAdjustedForThreshold * DECIMALS) / amountMinted;
        }
        return type(uint256).max;
    }

    function getAccountCollateralValueInUSD(address user) public view returns (uint256 accountCollateralValueInUSD) {
        uint256 length = s_supportedCollaterals.length;
        for (uint8 i; i < length; ) {
            address collateral = s_supportedCollaterals[i];
            uint256 amount = s_collateralBalance[user][collateral];
            accountCollateralValueInUSD += getCollateralValueInUSD(collateral, amount);

            unchecked {
                ++i;
            }
        }
        return accountCollateralValueInUSD;
    }

    function getCollateralValueInUSD(address token, uint256 amount) public view returns (uint256 collateralValueInUSD) {
        (, int256 price, , , ) = AggregatorV3Interface(s_priceFeeds[token]).latestRoundData();
        return (amount * (uint256(price) * PRICE_FEED_PRECISION_TO_MATCH_DECIMALS_PRECISION)) / DECIMALS;
    }

    /// @param collateral The address of the collateral token.
    /// @param collateralAmount The amount of the collateral to deposit.
    /// @param amountZeniToMint The amount of Zeni to mint.
    /// @notice Deposits your collateral and mints Zeni in one transaction.
    function depositCollateralAndMintZeni(
        address collateral,
        uint256 collateralAmount,
        uint256 amountZeniToMint
    ) external {
        depositCollateral(collateral, collateralAmount);
        mintZeni(amountZeniToMint);
    }

    /// @param collateral The address of the collateral token.
    /// @param collateralAmount The amount of the collateral to redeem.
    /// @param amountZeniToBurn The amount of Zeni to burn.
    /// @notice Burns Zeni and redeems the underlying collateral in one transaction.
    function redeemCollateralForZeni(address collateral, uint256 collateralAmount, uint256 amountZeniToBurn) external {
        burnZeni(amountZeniToBurn);
        redeemCollateral(collateral, collateralAmount);
    }

    /// @param user The address of the user to be liquidated, whose health factor is below MINIMUM_HEALTH_FACTOR.
    /// @param collateral The address of the collateral token.
    /// @param amountZeniToBurn The amount of Zeni to burn to improve the user's health factor.
    /// @notice You can partially liquidate the user as long as it brings their health factor above MINIMUM_HEALTH_FACTOR. As a reward for keeping the protocol secure, you will get a liquidation bonus.
    function liquidate(
        address user,
        address collateral,
        uint256 amountZeniToBurn
    ) external nonReentrant amountGreaterThanZero(amountZeniToBurn) {
        uint256 startingHealthFactor = getHealthFactor(user);
        require(
            startingHealthFactor < MINIMUM_HEALTH_FACTOR,
            ZeniEngine__HealthFactorIsGreaterThanMinimumHealthFactor()
        );

        uint256 tokenAmountCoveredFromDebt = getTokenAmountFromUSD(collateral, amountZeniToBurn);
        uint256 bonusCollateral = (tokenAmountCoveredFromDebt * LIQUIDATION_BONUS_IN_PERCENT) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountCoveredFromDebt + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnZeni(user, msg.sender, amountZeniToBurn);
        uint256 endingHealthFactor = getHealthFactor(user);
        require(endingHealthFactor >= startingHealthFactor, ZeniEngine__HealthFactorNotImproved());
        uint256 liquidatorHealthFactor = getHealthFactor(msg.sender);
        require(
            liquidatorHealthFactor >= MINIMUM_HEALTH_FACTOR,
            ZeniEngine__LiquidatorHealthFactorBelowMinimumThreshold()
        );
    }

    function getSupportedCollaterals() external view returns (address[] memory supportedCollaterals) {
        return s_supportedCollaterals;
    }

    function getCollateralBalance(address user, address collateral) external view returns (uint256 balance) {
        return s_collateralBalance[user][collateral];
    }

    function _addPriceFeed(address token, address priceFeed) private {
        require(token != address(0), ZeniEngine__TokenIsZeroAddress());
        require(priceFeed != address(0), ZeniEngine__PriceFeedIsZeroAddresss());
        s_priceFeeds[token] = priceFeed;
        s_supportedCollaterals.push(token);
    }

    function _redeemCollateral(address from, address to, address collateral, uint256 amount) private {
        s_collateralBalance[from][collateral] -= amount;
        emit CollateralRedeemed(from, to, collateral, amount);
        bool success = IERC20(collateral).transfer(to, amount);
        require(success, ZeniEngine__TokenTransferFailed());
    }

    /// @param onBehalfOf The address that initiated the burn process.
    /// @param from The address for which the Zeni will be burned.
    /// @param amount The amount of Zeni to burn.
    /// @dev Should not be called if health factor is not checked.
    function _burnZeni(address onBehalfOf, address from, uint256 amount) private {
        s_amountMinted[onBehalfOf] -= amount;
        bool success = IERC20(i_zeni).transferFrom(from, address(this), amount);
        require(success, ZeniEngine__TokenTransferFailed());
        i_zeni.burn(amount);
        emit ZeniBurned(from, amount);
    }
}
