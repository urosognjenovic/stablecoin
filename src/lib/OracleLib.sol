// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/shared/interfaces/AggregatorV3Interface.sol";

/// @title OracleLib
/// @author Uroš Ognjenović
/// @notice This library is used to check the Chainlink Oracle for state data. If a price is stale, the function will revert, and render the ZeniEngine unusable.
library OracleLib {
    uint256 private constant TIMEOUT = 3 hours;

    error OracleLib__StalePrice();

    function checkStalePrice(
        AggregatorV3Interface priceFeed
    ) external view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        uint256 timeSinceUpdate = block.timestamp - updatedAt;

        require(timeSinceUpdate <= TIMEOUT, OracleLib__StalePrice());
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
