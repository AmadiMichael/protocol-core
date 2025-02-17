// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vault, IVault, Currency, ERC20} from "../src/vault.sol";
import {Feed} from "../src/feed.sol";
import {ERC20Token} from "./mocks/ERC20Token.sol";
import {ErrorsAndEvents} from "./mocks/ErrorsAndEvents.sol";

contract BaseTest is Test, ErrorsAndEvents {
    bytes constant UNDERFLOW_OVERFLOW_PANIC_ERROR = abi.encodeWithSelector(bytes4(keccak256("Panic(uint256)")), 17);

    uint256 PRECISION = 1e18;
    Vault vault;
    Currency xNGN;
    ERC20 usdc;
    Feed feed;
    address owner = vm.addr(uint256(keccak256("OWNER")));
    address user1 = vm.addr(uint256(keccak256("User1")));
    address user2 = vm.addr(uint256(keccak256("User2")));
    address user3 = vm.addr(uint256(keccak256("User3")));
    address user4 = vm.addr(uint256(keccak256("User4")));
    address user5 = vm.addr(uint256(keccak256("User5")));
    uint256 constant onePercentPerAnnum = 1;
    uint256 onePercentPerSecondInterestRate = ((1e18 * onePercentPerAnnum) / 100) / 365 days;
    uint256 oneAndHalfPercentPerSecondInterestRate = ((1.5e18 * onePercentPerAnnum) / 100) / 365 days;

    function labelAddresses() private {
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(address(vault), "Vault");
        vm.label(address(xNGN), "xNGN");
        vm.label(address(feed), "Feed");
        vm.label(address(usdc), "USDC");
    }

    function setUp() public virtual {
        vm.startPrank(owner);

        xNGN = new Currency("xNGN", "xNGN");

        usdc = ERC20(address(new ERC20Token("Circle USD", "USDC")));

        vault = new Vault(xNGN, onePercentPerSecondInterestRate);

        feed = new Feed(vault);

        vault.createCollateralType(
            usdc, oneAndHalfPercentPerSecondInterestRate, 0.5e18, 0.1e18, type(uint256).max, 100e18
        );
        vault.updateFeedContract(address(feed));
        feed.mockUpdatePrice(address(usdc), 1000e6);
        xNGN.setMinterRole(address(vault));

        ERC20Token(address(usdc)).mint(user1, 100_000e18);
        ERC20Token(address(usdc)).mint(user2, 100_000e18);
        ERC20Token(address(usdc)).mint(user3, 100_000e18);
        ERC20Token(address(usdc)).mint(user4, 100_000e18);
        ERC20Token(address(usdc)).mint(user5, 100_000e18);

        vm.stopPrank();

        labelAddresses();

        allUsersApproveTokensForVault();
    }

    function allUsersApproveTokensForVault() private {
        vm.startPrank(user1);
        usdc.approve(address(vault), type(uint256).max);
        xNGN.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(vault), type(uint256).max);
        xNGN.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(vault), type(uint256).max);
        xNGN.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user4);
        usdc.approve(address(vault), type(uint256).max);
        xNGN.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user5);
        usdc.approve(address(vault), type(uint256).max);
        xNGN.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    modifier useUser1() {
        vm.startPrank(user1);
        _;
    }

    modifier useReliedOnForUser1(address relyOn) {
        vm.prank(user1);
        vault.rely(relyOn);

        vm.startPrank(relyOn);
        _;
    }

    function getVaultMapping(ERC20 _collateralToken, address _owner) internal view returns (IVault.VaultInfo memory) {
        (uint256 depositedCollateral, uint256 borrowedAmount, uint256 accruedFees, uint256 lastTotalAccumulatedRate) =
            vault.vaultMapping(_collateralToken, _owner);

        return IVault.VaultInfo(depositedCollateral, borrowedAmount, accruedFees, lastTotalAccumulatedRate);
    }

    function getCollateralMapping(ERC20 _collateralToken) internal view returns (IVault.CollateralInfo memory) {
        (
            uint256 totalDepositedCollateral,
            uint256 totalBorrowedAmount,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            Vault.RateInfo memory rateInfo,
            uint256 paidFees,
            uint256 price,
            uint256 debtCeiling,
            uint256 collateralFloorPerPosition,
            uint256 additionalCollateralPercision,
            bool exists
        ) = vault.collateralMapping(_collateralToken);

        return IVault.CollateralInfo(
            totalDepositedCollateral,
            totalBorrowedAmount,
            liquidationThreshold,
            liquidationBonus,
            rateInfo,
            paidFees,
            price,
            debtCeiling,
            collateralFloorPerPosition,
            additionalCollateralPercision,
            exists
        );
    }

    function calculateCurrentTotalAccumulatedRate(ERC20 _collateralToken) internal view returns (uint256) {
        IVault.CollateralInfo memory _collateral = getCollateralMapping(_collateralToken);
        // calculates pending collateral rate and adds it to the last stored collateral rate
        uint256 _collateralCurrentAccumulatedRate = _collateral.rateInfo.accumulatedRate
            + (_collateral.rateInfo.rate * (block.timestamp - _collateral.rateInfo.lastUpdateTime));

        // calculates pending base rate and adds it to the last stored base rate
        (uint256 _rate, uint256 _accumulatedRate, uint256 _lastUpdateTime) = vault.baseRateInfo();
        uint256 _baseCurrentAccumulatedRate = _accumulatedRate + (_rate * (block.timestamp - _lastUpdateTime));

        // adds together to get total rate since inception
        return _collateralCurrentAccumulatedRate + _baseCurrentAccumulatedRate;
    }

    function calculateUserCurrentAccruedFees(ERC20 _collateralToken, address _owner)
        internal
        view
        returns (uint256 accruedFees)
    {
        IVault.VaultInfo memory userVaultInfo = getVaultMapping(_collateralToken, _owner);
        accruedFees = userVaultInfo.accruedFees
            + (
                (calculateCurrentTotalAccumulatedRate(usdc) - userVaultInfo.lastTotalAccumulatedRate)
                    * userVaultInfo.borrowedAmount
            ) / PRECISION;
    }
}
