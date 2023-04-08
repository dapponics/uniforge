// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Price Converter
 * @author d-carranza
 * @notice This library provides utility functions for converting ETH amounts to USD amounts using Chainlink Data Feeds as the price oracle.
 */
library PriceConverter {
    /**
     * @notice Returns the current price from the given Chainlink price feed.
     * @param priceFeed The Chainlink price feed to retrieve the price from.
     * @return The current price in USD with 18 decimal places.
     */
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 1e10);
    }

    /**
     * @notice Converts an amount of ETH to its equivalent value in USD using the given Chainlink price feed.
     * @param ethAmount The amount of ETH to convert.
     * @param priceFeed The Chainlink price feed to use for conversion.
     * @return The equivalent value of the given amount of ETH in USD with 18 decimal places.
     */
    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }
}
