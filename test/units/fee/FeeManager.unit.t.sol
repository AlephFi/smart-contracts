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
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {FeeManager} from "@aleph-vault/FeeManager.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract FeeManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConstructorParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    /*//////////////////////////////////////////////////////////////
                        ACCUMALATE FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_accumalateFees_whenNewTotalAssetsIs0_shouldNotAccumalateFees() public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;
        uint48 timestamp = Time.timestamp();

        // accumalate fees
        vault.accumalateFees(0, currentBatchId, lastFeePaidId, timestamp);

        // check lastFeePaidId is updated
        assertEq(vault.lastFeePaidId(), currentBatchId);

        // check no fees are accumalated
        address managementFeeRecipient = vault.MANAGEMENT_FEE_RECIPIENT();
        address performanceFeeRecipient = vault.PERFORMANCE_FEE_RECIPIENT();
        assertEq(vault.sharesOf(managementFeeRecipient), 0);
        assertEq(vault.sharesOf(performanceFeeRecipient), 0);
    }

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsHigherThanPricePerShare_shouldAccumalateOnlyManagementFees(
    ) public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;
        uint48 timestamp = Time.timestamp();

        // set high water mark to 2
        uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
        uint256 _highWaterMark = 2 * _priceDenominator;
        vault.setHighWaterMark(_highWaterMark);

        // set total assets and shares
        uint256 _newTotalAssets = 1200;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // accumalate fees
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesAccumulated(7, 0, timestamp);
        uint256 _totalSharesMinted = vault.accumalateFees(_newTotalAssets, currentBatchId, lastFeePaidId, timestamp);

        // assert total shares minted
        assertEq(_totalSharesMinted, 5);

        // check lastFeePaidId is updated
        assertEq(vault.lastFeePaidId(), currentBatchId);

        // check high water mark is not updated
        assertEq(vault.highWaterMark(), _highWaterMark);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.MANAGEMENT_FEE_RECIPIENT();
        assertEq(vault.sharesOf(managementFeeRecipient), 5);

        // check no fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.PERFORMANCE_FEE_RECIPIENT();
        assertEq(vault.sharesOf(performanceFeeRecipient), 0);
    }

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsLowerThanPricePerShare_shouldAccumalateBothPerformanceAndManagementFees(
    ) public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;
        uint48 timestamp = Time.timestamp();

        // set high water mark to 1
        uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
        uint256 _highWaterMark = 1 * _priceDenominator;
        vault.setHighWaterMark(_highWaterMark);

        // set total assets and shares
        uint256 _newTotalAssets = 1200;
        uint256 _newHighWaterMark = (_newTotalAssets * _priceDenominator) / 1000;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // accumalate fees
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_newHighWaterMark);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesAccumulated(7, 50, timestamp);
        uint256 _totalSharesMinted = vault.accumalateFees(_newTotalAssets, currentBatchId, lastFeePaidId, timestamp);

        // assert total shares minted
        assertEq(_totalSharesMinted, 46);

        // check lastFeePaidId is updated
        assertEq(vault.lastFeePaidId(), currentBatchId);

        // check high water mark is updated
        assertEq(vault.highWaterMark(), _newHighWaterMark);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.MANAGEMENT_FEE_RECIPIENT();
        assertEq(vault.sharesOf(managementFeeRecipient), 5);

        // check fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.PERFORMANCE_FEE_RECIPIENT();
        assertEq(vault.sharesOf(performanceFeeRecipient), 41);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_collectFees_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // collect fees
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonAuthorizedUser,
                RolesLibrary.OPERATIONS_MULTISIG
            )
        );
        vault.collectFees();
    }

    function test_collectFees_whenCallerIsOperationsMultisig_shouldSucceed() public {
        // accumalate fees to recipients
        uint256 _managementShares = 120;
        uint256 _performanceShares = 120;
        vault.setSharesOf(vault.MANAGEMENT_FEE_RECIPIENT(), _managementShares);
        vault.setSharesOf(vault.PERFORMANCE_FEE_RECIPIENT(), _performanceShares);

        // set total assets and shares
        uint256 _totalAssets = 1000;
        uint256 _totalShares = 1200;
        vault.setTotalAssets(_totalAssets);
        vault.setTotalShares(_totalShares);

        // expected fees to collect
        uint256 _expectedManagementFeesToCollect = 100;
        uint256 _expectedPerformanceFeesToCollect = 100;

        // collect fees
        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesCollected(_expectedManagementFeesToCollect, _expectedPerformanceFeesToCollect);
        (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect) = vault.collectFees();

        // check fees are calculated correctly
        assertEq(_managementFeesToCollect, _expectedManagementFeesToCollect);
        assertEq(_performanceFeesToCollect, _expectedPerformanceFeesToCollect);

        // check recipient shares are burned
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), 0);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);

        // check total assets and total shares are updated
        assertEq(
            vault.totalAssets(), _totalAssets - _expectedManagementFeesToCollect - _expectedPerformanceFeesToCollect
        );
        assertEq(vault.totalShares(), _totalShares - _managementShares - _performanceShares);

        // check fee recipient is approved to collect fees
        assertEq(
            underlyingToken.allowance(address(vault), vault.feeRecipient()),
            _expectedManagementFeesToCollect + _expectedPerformanceFeesToCollect
        );
    }
}
