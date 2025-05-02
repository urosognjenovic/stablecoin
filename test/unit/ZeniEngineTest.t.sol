// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import "../../script/Addresses.sol";

contract ZeniEngineTest is Test {
    Zeni private s_zeni;
    ZeniEngine private s_zeniEngine;
    address[] private collaterals = [ETHEREUM_SEPOLIA_WETH_TOKEN, ETHEREUM_SEPOLIA_WBTC_TOKEN];
    address[] private priceFeeds = [ETHEREUM_SEPOLIA_ETH_USD_PRICE_FEED, ETHEREUM_SEPOLIA_BTC_USD_PRICE_FEED];
    address[] private prunedPriceFeeds = [ETHEREUM_SEPOLIA_ETH_USD_PRICE_FEED];

    function setUp() external {
        s_zeni = new Zeni();
        s_zeniEngine = new ZeniEngine(s_zeni, collaterals, priceFeeds);
    }

    function testDeploymentFailsWhenCollateralsLengthIsDifferentThanPriceFeedsLength() external {
        s_zeni = new Zeni();
        vm.expectRevert(ZeniEngine.ZeniEngine__TokensLengthIsDifferentThanPriceFeedsLength.selector);
        s_zeniEngine = new ZeniEngine(s_zeni, collaterals, prunedPriceFeeds);
    }
}
