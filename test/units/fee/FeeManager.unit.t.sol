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
import {FeeManager} from "@aleph-vault/FeeManager.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract FeeManagerTest is BaseTest {
    function setUp() public {
        _setUpNewAlephVault(defaultConstructorParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_accumalateFees_whenNewTotalAssetsIs0_shouldNotAccumalateFees() public {
        // set up context
        uint48 currentBatchId = 3;
        uint48 lastFeePaidId = 1;
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

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsHigherThanPricePerShare_shouldAccumalateOnlyManagementFees() public {
        // set up context
        uint48 currentBatchId = 3;
        uint48 lastFeePaidId = 1;
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
        vault.accumalateFees(_newTotalAssets, currentBatchId, lastFeePaidId, timestamp);

        // check lastFeePaidId is updated
        assertEq(vault.lastFeePaidId(), currentBatchId);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.MANAGEMENT_FEE_RECIPIENT();
        assertEq(vault.sharesOf(managementFeeRecipient), 0);

        // check no fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.PERFORMANCE_FEE_RECIPIENT();
        assertEq(vault.sharesOf(performanceFeeRecipient), 0);
    }

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsLowerThanPricePerShare_shouldAccumalateBothPerformanceAndManagementFees() public {
        // set up context
        uint48 currentBatchId = 3;
        uint48 lastFeePaidId = 1;
        uint48 timestamp = Time.timestamp();

        // set high water mark to 1
        uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
        uint256 _highWaterMark = 1 * _priceDenominator;

        // set total assets and shares
        uint256 _newTotalAssets = 1200;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // accumalate fees
        vault.accumalateFees(_newTotalAssets, currentBatchId, lastFeePaidId, timestamp);

        // check lastFeePaidId is updated
        assertEq(vault.lastFeePaidId(), currentBatchId);

        // check high water mark is updated
        assertGt(vault.highWaterMark(), _highWaterMark);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.MANAGEMENT_FEE_RECIPIENT();
        assertEq(vault.sharesOf(managementFeeRecipient), 0);

        // check fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.PERFORMANCE_FEE_RECIPIENT();
        assertEq(vault.sharesOf(performanceFeeRecipient), 0);
    }
}