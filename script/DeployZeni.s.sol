// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Zeni} from "../src/Zeni.sol";
import {ZeniEngine} from "../src/ZeniEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployZeni is Script {
    function run() external returns (Zeni, ZeniEngine) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.Config memory config = helperConfig.run();
        (address[] memory collaterals, address[] memory priceFeeds) = (config.collaterals, config.priceFeeds);
        vm.startBroadcast();
        Zeni zeni = new Zeni();
        ZeniEngine zeniEngine = new ZeniEngine(zeni, collaterals, priceFeeds);
        zeni.transferOwnership(address(zeniEngine));
        vm.stopBroadcast();
        return (zeni, zeniEngine);
    }
}
