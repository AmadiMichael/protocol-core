// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IFeed {
    error Paused();

    event Read(address collateral, uint256 price);

    function updatePrice(address collateral) external;

    function setPriceOracleContract(address oracle, address collateral) external;
}
