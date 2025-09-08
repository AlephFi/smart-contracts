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
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVaultRedeem_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE NOTICE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueNoticePeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue notice period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueNoticePeriod(1, 30);
    }

    function test_queueNoticePeriod_whenCallerIsManager_shouldSucceed() public {
        // queue notice period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.NewNoticePeriodQueued(1, 100);
        vault.queueNoticePeriod(1, 100);

        // check notice period is queued
        bytes4 _key = TimelockRegistry.NOTICE_PERIOD;
        uint48 _unlockTimestamp = Time.timestamp() + vault.noticePeriodTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(1, 100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET NOTICE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setNoticePeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set notice period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setNoticePeriod();
    }

    function test_setNoticePeriod_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue notice period
        vm.prank(manager);
        vault.queueNoticePeriod(1, 30);

        // get notice period timelock params
        bytes4 _key = TimelockRegistry.NOTICE_PERIOD;
        uint48 _unlockTimestamp = Time.timestamp() + vault.noticePeriodTimelock();

        // set notice period
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(TimelockRegistry.TimelockNotExpired.selector, _key, _unlockTimestamp));
        vault.setNoticePeriod();
    }

    function test_setNoticePeriod_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue notice period
        vm.prank(manager);
        vault.queueNoticePeriod(1, 30);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.noticePeriodTimelock() + 1);

        // set notice period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.NewNoticePeriodSet(1, 30);
        vault.setNoticePeriod();

        // check notice period is set
        assertEq(vault.noticePeriod(1), 30);
    }
}
