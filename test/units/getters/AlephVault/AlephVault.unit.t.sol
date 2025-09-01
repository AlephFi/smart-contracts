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

import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVault_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                GET TOTAL AMOUNT FOR REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/
    // function test_getTotalAmountForRedemption() public {
    //     // set total assets and total shares
    //     vault.setTotalAssets(0, 1000 ether);
    //     vault.setTotalShares(0, 1000 ether);
    //     vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

    //     // set user shares
    //     vault.setSharesOf(0, mockUser_1, 500 ether);
    //     vault.setSharesOf(0, mockUser_2, 500 ether);

    //     // roll the block forward to make batch available
    //     vm.warp(block.timestamp + 1 days + 1);

    //     // set redemption requests
    //     vault.setBatchRedeem(vault.currentBatch(), mockUser_1, 100 ether);
    //     vault.setBatchRedeem(vault.currentBatch(), mockUser_2, 200 ether);

    //     vm.warp(block.timestamp + 1 days + 1);
    //     vault.setBatchRedeem(vault.currentBatch(), mockUser_1, 100 ether);
    //     vault.setBatchRedeem(vault.currentBatch(), mockUser_2, 200 ether);

    //     vm.warp(block.timestamp + 10 days);

    //     // calculate fee shares
    //     uint256 _newTotalAssets = 1200 ether;
    //     uint256 _totalShares = vault.totalShares();
    //     uint256 _expectedManagementFeeShares = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 12);
    //     uint256 _expectedPerformanceFeeShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
    //     _totalShares += _expectedManagementFeeShares + _expectedPerformanceFeeShares;
    //     uint256 _expectedTotalAmountForRedemption =
    //         ERC4626Math.previewRedeem(vault.totalSharesToRedeem(), _newTotalAssets, _totalShares);

    //     // get total amount for redemption
    //     assertEq(vault.totalAmountForRedemption(_newTotalAssets), _expectedTotalAmountForRedemption);
    // }
}
