// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract ErrorsAndEvents {
    event CollateralTypeAdded(address collateralAddress);
    event CollateralDeposited(address indexed owner, uint256 amount);
    event CollateralWithdrawn(address indexed owner, address to, uint256 amount);
    event CurrencyMinted(address indexed owner, uint256 amount);
    event CurrencyBurned(address indexed owner, uint256 amount);
    event FeesPaid(address indexed owner, uint256 amount);
    event Liquidated(
        address indexed owner, address liquidator, uint256 currencyAmountPaid, uint256 collateralAmountCovered
    );

    error ZeroAddress();
    error UnrecognizedParam();
    error BadHealthFactor();
    error PositionIsSafe();
    error ZeroCollateral();
    error TotalUserCollateralBelowFloor();
    error CollateralAlreadyExists();
    error CollateralDoesNotExist();
    error NotOwnerOrReliedUpon();
    error HealthFactorNotImproved();
    error NotEnoughCollateralToPay();
    error EthTransferFailed();
    error Paused();
}
