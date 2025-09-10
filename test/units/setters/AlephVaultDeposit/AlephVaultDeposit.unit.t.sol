// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
/*
  ______   __                      __       
 /      \ /  |                    /  |      
/$$$$$$  |$$ |  ______    ______  $$ |____  
$$ |__$$ |$$ | /      \  /      \ $$      \ 
$$    $$ |$$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |
$$$$$$$$ |$$ |$$    $$ |$$ |  $$ |$$ |  $$ |
$$ |  $$ |$$ |$$$$$$$$/ $$ |__$$ |$$ |  $$ |
$$ |  $$ |$$ |$$       |$$    $$/ $$ |  $$ |
$$/   $$/ $$/  $$$$$$$/ $$$$$$$/  $$/   $$/ 
                        $$ |                
                        $$ |                
                        $$/                 
*/

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVaultDeposit_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE MIN DEPOSIT AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueMinDepositAmount_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue min deposit amount
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueMinDepositAmount(1, 100);
    }

    function test_queueMinDepositAmount_whenCallerIsManager_shouldSucceed() public {
        // queue min deposit amount
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.NewMinDepositAmountQueued(1, 100);
        vault.queueMinDepositAmount(1, 100);

        // check min deposit amount is queued
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MIN_DEPOSIT_AMOUNT, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.minDepositAmountTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.isQueued, true);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET MIN DEPOSIT AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setMinDepositAmount_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set min deposit amount
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setMinDepositAmount(1);
    }

    function test_setMinDepositAmount_revertsWhenTimelockIsNotQueued() public {
        // set min deposit amount
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(TimelockRegistry.TimelockNotQueued.selector, TimelockRegistry.MIN_DEPOSIT_AMOUNT, 1)
        );
        vault.setMinDepositAmount(1);
    }

    function test_setMinDepositAmount_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue min deposit amount
        vm.prank(manager);
        vault.queueMinDepositAmount(1, 100);

        // get min deposit amount timelock params
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MIN_DEPOSIT_AMOUNT, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.minDepositAmountTimelock();

        // set min deposit amount
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockRegistry.TimelockNotExpired.selector, TimelockRegistry.MIN_DEPOSIT_AMOUNT, 1, _unlockTimestamp
            )
        );
        vault.setMinDepositAmount(1);
    }

    function test_setMinDepositAmount_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue min deposit amount
        vm.prank(manager);
        vault.queueMinDepositAmount(1, 100);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.minDepositAmountTimelock() + 1);

        // set min deposit amount
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.NewMinDepositAmountSet(1, 100);
        vault.setMinDepositAmount(1);

        // check min deposit amount is set
        assertEq(vault.minDepositAmount(1), 100);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE MAX DEPOSIT CAP TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueMaxDepositCap_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue max deposit cap
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueMaxDepositCap(1, 100);
    }

    function test_queueMaxDepositCap_whenCallerIsManager_shouldSucceed() public {
        // queue max deposit cap
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.NewMaxDepositCapQueued(1, 100);
        vault.queueMaxDepositCap(1, 100);

        // check max deposit cap is queued
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MAX_DEPOSIT_CAP, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.maxDepositCapTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.isQueued, true);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET MAX DEPOSIT CAP TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setMaxDepositCap_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set max deposit cap
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setMaxDepositCap(1);
    }

    function test_setMaxDepositCap_revertsWhenTimelockIsNotQueued() public {
        // set max deposit cap
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(TimelockRegistry.TimelockNotQueued.selector, TimelockRegistry.MAX_DEPOSIT_CAP, 1)
        );
        vault.setMaxDepositCap(1);
    }

    function test_setMaxDepositCap_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue max deposit cap
        vm.prank(manager);
        vault.queueMaxDepositCap(1, 100);

        // get max deposit cap timelock params
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MAX_DEPOSIT_CAP, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.maxDepositCapTimelock();

        // set max deposit cap
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockRegistry.TimelockNotExpired.selector, TimelockRegistry.MAX_DEPOSIT_CAP, 1, _unlockTimestamp
            )
        );
        vault.setMaxDepositCap(1);
    }

    function test_setMaxDepositCap_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue max deposit cap
        vm.prank(manager);
        vault.queueMaxDepositCap(1, 100);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.maxDepositCapTimelock() + 1);

        // set max deposit cap
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.NewMaxDepositCapSet(1, 100);
        vault.setMaxDepositCap(1);

        // check max deposit cap is set
        assertEq(vault.maxDepositCap(1), 100);
    }
}
