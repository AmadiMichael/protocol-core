// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseTest, ERC20, IVault} from "../../../base.t.sol";

contract WithdrawCollateralTest is BaseTest {
    function setUp() public override {
        super.setUp();

        // use user1 as default for all tests
        vm.startPrank(user1);

        // deposit amount to be used when testing
        vault.depositCollateral(usdc, user1, 1_000e18);

        vm.stopPrank();
    }

    function test_WhenVaultIsPaused() external useUser1 {
        // pause vault
        vm.stopPrank();
        vm.prank(owner);
        // pause vault
        vault.pause();

        // it should revert with custom error Paused()
        vm.expectRevert(Paused.selector);
        vault.withdrawCollateral(usdc, user1, user1, 1_000e18);
    }

    modifier whenVaultIsNotPaused() {
        _;
    }

    function test_WhenCollateralDoesNotExist() external whenVaultIsNotPaused useUser1 {
        // it should revert with custom error CollateralDoesNotExist()
        vm.expectRevert(CollateralDoesNotExist.selector);

        // call with non existing collateral
        vault.withdrawCollateral(ERC20(vm.addr(11111)), user1, user1, 1_000e18);
    }

    modifier whenCollateralExists() {
        _;
    }

    function test_WhenCallerIsNotOwnerAndNotReliedUponByOwner() external whenVaultIsNotPaused whenCollateralExists {
        // use unrelied upon user2
        vm.prank(user2);

        // it should revert with custom error NotOwnerOrReliedUpon()
        vm.expectRevert(NotOwnerOrReliedUpon.selector);

        // call and try to interact with user1 vault with address user1 does not rely on
        vault.withdrawCollateral(usdc, user1, user1, 1_000e18);
    }

    modifier whenCallerIsOwnerOrReliedUponByOwner() {
        _;
    }

    function test_WhenTheAmountIsGreaterThanTheBorrowersDepositedCollateral()
        external
        whenVaultIsNotPaused
        whenCollateralExists
        whenCallerIsOwnerOrReliedUponByOwner
        useUser1
    {
        // it should revert with solidity panic error underflow error
        vm.expectRevert(UNDERFLOW_OVERFLOW_PANIC_ERROR);
        vault.withdrawCollateral(usdc, user1, user1, 1_000e18 + 1);
    }

    modifier whenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral() {
        _;
    }

    function test_WhenTheWithdrawalMakesTheVaultsHealthFactorBelowTheMinHealthFactor_useUser1()
        external
        whenVaultIsNotPaused
        whenCollateralExists
        whenCallerIsOwnerOrReliedUponByOwner
        whenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral
        useUser1
    {
        // mint max amount possible of currency to make withdrawing any of my collateral bad for user1 vault position
        vault.mintCurrency(usdc, user1, user1, 500_000e18);

        // it should revert with custom error BadHealthFactor()
        vm.expectRevert(BadHealthFactor.selector);
        vault.withdrawCollateral(usdc, user1, user1, 1);
    }

    function test_WhenTheWithdrawalMakesTheVaultsHealthFactorBelowTheMinHealthFactor_useReliedOnForUser1()
        external
        whenVaultIsNotPaused
        whenCollateralExists
        whenCallerIsOwnerOrReliedUponByOwner
        whenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral
        useReliedOnForUser1(user2)
    {
        // mint max amount possible of currency to make withdrawing any of my collateral bad for user1 vault position
        vault.mintCurrency(usdc, user1, user1, 500_000e18);

        // it should revert with custom error BadHealthFactor()
        vm.expectRevert(BadHealthFactor.selector);
        vault.withdrawCollateral(usdc, user1, user1, 1);
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral_useUser1()
        external
        whenVaultIsNotPaused
        whenCollateralExists
        whenCallerIsOwnerOrReliedUponByOwner
        whenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral
        useUser1
    {
        // it should update accrued fees for the user's position
        // it should emit CollateralWithdrawn() event with expected indexed and unindexed parameters
        // it should update user's, collateral's and global pending fee to the right figures
        // it should update the _owner's deposited collateral and collateral's total deposit
        // it should send the collateral token to the to address from the vault

        runWithdrawCollateralTestWithChecks(user2);
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral_useReliedOnForUser1()
        external
        whenVaultIsNotPaused
        whenCollateralExists
        whenCallerIsOwnerOrReliedUponByOwner
        whenTheAmountIsLessThanOrEqualToTheBorrowersDepositedCollateral
        useReliedOnForUser1(user2)
    {
        // it should update accrued fees for the user's position
        // it should emit CollateralWithdrawn() event with expected indexed and unindexed parameters
        // it should update user's, collateral's and global pending fee to the right figures
        // it should update the _owner's deposited collateral and collateral's total deposit
        // it should send the collateral token to the to address from the vault

        runWithdrawCollateralTestWithChecks(user3);
    }

    function runWithdrawCollateralTestWithChecks(address recipient) private {
        // cache pre balances
        uint256 userOldBalance = usdc.balanceOf(recipient);
        uint256 vaultOldBalance = usdc.balanceOf(address(vault));

        // cache pre storage vars and old accrued fees
        IVault.VaultInfo memory initialUserVaultInfo = getVaultMapping(usdc, user1);
        IVault.CollateralInfo memory initialCollateralInfo = getCollateralMapping(usdc);
        uint256 initialAccruedFees = vault.accruedFees();

        // take a loan of xNGN to be able to calculate fees acrrual
        uint256 amountMinted = 100_000e18;
        vault.mintCurrency(usdc, user1, user1, amountMinted);

        // skip time to be able to check accrued interest
        uint256 timeElapsed = 1_000;
        skip(timeElapsed);

        // amount to withdraw
        uint256 amount = 500e18;

        // it should emit CollateralWithdrawn() event with expected indexed and unindexed parameters
        vm.expectEmit(true, false, false, true, address(vault));
        emit CollateralWithdrawn(user1, recipient, amount);

        // call withdrawCollateral to deposit 1,000 usdc into user1's vault
        vault.withdrawCollateral(usdc, user1, recipient, amount);

        // // it should update the user1's deposited collateral and collateral's total deposit
        IVault.VaultInfo memory afterUserVaultInfo = getVaultMapping(usdc, user1);
        IVault.CollateralInfo memory afterCollateralInfo = getCollateralMapping(usdc);

        // get expected accrued fees
        uint256 accruedFees = (
            (calculateCurrentTotalAccumulatedRate(usdc) - initialUserVaultInfo.lastTotalAccumulatedRate) * amountMinted
        ) / PRECISION;

        // it should update accrued fees for the user's position
        assertEq(initialUserVaultInfo.accruedFees + accruedFees, afterUserVaultInfo.accruedFees);
        assertEq(initialAccruedFees + accruedFees, vault.accruedFees());

        // it should update the storage vars correctly
        assertEq(afterCollateralInfo.totalDepositedCollateral, initialCollateralInfo.totalDepositedCollateral - amount);
        assertEq(afterUserVaultInfo.depositedCollateral, initialUserVaultInfo.depositedCollateral - amount);

        // it should send the collateral token to the vault from the user1
        assertEq(vaultOldBalance - usdc.balanceOf(address(vault)), amount);
        assertEq(usdc.balanceOf(recipient) - userOldBalance, amount);
    }
}
