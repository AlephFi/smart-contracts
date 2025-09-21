// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVault_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE SHARE CLASS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_createShareClass_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;

        // set is deposit auth enabled
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.createShareClass(_shareClassParams);
    }

    function test_createShareClass_revertsWhenManagementFeeIsGreaterThanMAXIMUM_MANAGEMENT_FEE() public {
        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;
        _shareClassParams.managementFee = vault.MAXIMUM_MANAGEMENT_FEE() + 1;

        // create share class
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAlephVault.InvalidShareClassParams.selector));
        vault.createShareClass(_shareClassParams);
    }

    function test_createShareClass_revertsWhenPerformanceFeeIsGreaterThanMAXIMUM_PERFORMANCE_FEE() public {
        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;
        _shareClassParams.performanceFee = vault.MAXIMUM_PERFORMANCE_FEE() + 1;

        // create share class
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAlephVault.InvalidShareClassParams.selector));
        vault.createShareClass(_shareClassParams);
    }

    function test_createShareClass_revertsWhenMinDepositAmountIsZero() public {
        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;
        _shareClassParams.minDepositAmount = 0;

        // create share class
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAlephVault.InvalidShareClassParams.selector));
        vault.createShareClass(_shareClassParams);
    }

    function test_createShareClass_revertsWhenMinRedeemAmountIsZero() public {
        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;
        _shareClassParams.minRedeemAmount = 0;

        // create share class
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAlephVault.InvalidShareClassParams.selector));
        vault.createShareClass(_shareClassParams);
    }

    function test_createShareClass_whenCallerIsManager_shouldSucceed() public {
        // previous number of share classes
        uint8 _previousShareClasses = vault.shareClasses();

        // create share class params
        IAlephVault.ShareClassParams memory _shareClassParams =
            defaultInitializationParams.userInitializationParams.shareClassParams;

        // create share class
        vm.prank(manager);
        uint8 _classId = vault.createShareClass(_shareClassParams);

        // check if share class was created
        assertEq(vault.shareClasses(), _previousShareClasses + 1);
        assertEq(vault.shareClasses(), _classId);
        assertEq(vault.managementFee(_classId), _shareClassParams.managementFee);
        assertEq(vault.performanceFee(_classId), _shareClassParams.performanceFee);
        assertEq(vault.noticePeriod(_classId), _shareClassParams.noticePeriod);
        assertEq(vault.lockInPeriod(_classId), _shareClassParams.lockInPeriod);
        assertEq(vault.minDepositAmount(_classId), _shareClassParams.minDepositAmount);
        assertEq(vault.minUserBalance(_classId), _shareClassParams.minUserBalance);
        assertEq(vault.maxDepositCap(_classId), _shareClassParams.maxDepositCap);
        assertEq(vault.minRedeemAmount(_classId), _shareClassParams.minRedeemAmount);
    }
}
