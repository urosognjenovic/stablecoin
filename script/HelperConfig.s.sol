// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import "./Addresses.sol";
import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct Config {
        address[] collaterals;
        address[] priceFeeds;
    }

    Config private s_activeConfig;
    uint256 private constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant ANVIL_CHAIN_ID = 31337;
    uint8 public constant DECIMALS = 8;
    int256 public immutable ETH_USD_INITIAL_ANSWER = 1800e8;
    int256 public constant BTC_USD_INITIAL_ANSWER = 94000e8;

    error HelperConfig__CollateralsLengthIsDifferentThanPriceFeedsLength();

    modifier collateralLengthIsEqualToPriceFeedsLength() {
        _;
        require(
            s_activeConfig.collaterals.length == s_activeConfig.priceFeeds.length,
            HelperConfig__CollateralsLengthIsDifferentThanPriceFeedsLength()
        );
    }

    function run() external returns (Config memory) {
        delete s_activeConfig;
        if (block.chainid == ETHEREUM_SEPOLIA_CHAIN_ID) {
            _setEthereumSepoliaConfig();
        } else if (block.chainid == ANVIL_CHAIN_ID) {
            _setAnvilConfig();
        }
        return s_activeConfig;
    }

    function getActiveConfig() external view returns (Config memory) {
        return s_activeConfig;
    }

    function _setEthereumSepoliaConfig() private collateralLengthIsEqualToPriceFeedsLength {
        s_activeConfig.collaterals.push(ETHEREUM_SEPOLIA_WETH_TOKEN);
        s_activeConfig.collaterals.push(ETHEREUM_SEPOLIA_WBTC_TOKEN);
        s_activeConfig.priceFeeds.push(ETHEREUM_SEPOLIA_ETH_USD_PRICE_FEED);
        s_activeConfig.priceFeeds.push(ETHEREUM_SEPOLIA_BTC_USD_PRICE_FEED);
    }

    function _setAnvilConfig() private {
        vm.startBroadcast();
        ERC20Mock wETHMock = new ERC20Mock();
        ERC20Mock wBTCMock = new ERC20Mock();
        MockV3Aggregator ETHUSDPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_INITIAL_ANSWER);
        MockV3Aggregator BTCUSDPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_INITIAL_ANSWER);
        vm.stopBroadcast();
        s_activeConfig.collaterals.push(address(wETHMock));
        s_activeConfig.collaterals.push(address(wBTCMock));
        s_activeConfig.priceFeeds.push(address(ETHUSDPriceFeed));
        s_activeConfig.priceFeeds.push(address(BTCUSDPriceFeed));
    }
}
