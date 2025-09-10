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

import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_requestRedeem_revertsWhenClassIdIsInvalid() public {
        // request redeem
        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.requestRedeem(0, 100);
    }

    function test_requestRedeem_revertsGivenFlowIsPaused() public {
        // pause redeem request flow
        vm.prank(manager);
        vault.pause(PausableFlows.REDEEM_REQUEST_FLOW);

        // request redeem
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.requestRedeem(1, 100);
    }

    function test_requestRedeem_revertsGivenAmountToRedeemIsZero() public {
        // request redeem
        vm.expectRevert(IAlephVaultRedeem.InsufficientRedeem.selector);
        vault.requestRedeem(1, 0);
    }

    function test_requestRedeem_revertsGivenAmountToRedeemIsLessThanMinRedeemAmount() public {
        // set min redeem amount to 100 ether
        vault.setMinRedeemAmount(1, 100 ether);

        // request redeem
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultRedeem.RedeemLessThanMinRedeemAmount.selector, 100 ether));
        vault.requestRedeem(1, 50 ether);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsWhenUserHasInsufficientAssetsToRedeem() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientAssetsToRedeem.selector);
        vault.requestRedeem(1, 100 ether);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsWhenAmountToRedeemIsLessThanMinDepositAmount() public {
        // set min deposit amount to 100 ether
        vault.setMinDepositAmount(1, 200 ether);

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set shares of user to 200
        vault.setSharesOf(0, mockUser_1, 200 ether);

        // request redeem
        vm.prank(mockUser_1);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultRedeem.RedeemFallBelowMinUserBalance.selector, 200 ether));
        vault.requestRedeem(1, 100 ether);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsGivenUserHasAlreadyMadeARedeemRequestForThisBatch() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set redeem request to current batch id
        vault.setSharesOf(0, mockUser_1, 100 ether);
        vault.setBatchRedeem(vault.currentBatch(), mockUser_1, vault.PRICE_DENOMINATOR() / 2);

        // request redeem
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.OnlyOneRequestPerBatchAllowedForRedeem.selector);
        vault.requestRedeem(1, 50 ether);
    }

    function test_requestRedeem_whenFlowIsUnpaused_whenUserHasSufficientSharesToRedeem_shouldSucceed_singleUser()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set shares of user to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);

        // Capture batch ID before emit expectation
        uint48 _expectedBatchId = vault.currentBatch();

        // request redeem
        vm.prank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.RedeemRequest(mockUser_1, 1, 100 ether, _expectedBatchId);
        uint48 _batchId = vault.requestRedeem(1, 100 ether);

        // check the redeem request
        assertEq(vault.redeemRequestOfAt(1, mockUser_1, _batchId), vault.TOTAL_SHARE_UNITS());
        assertEq(vault.usersToRedeemAt(1, _batchId).length, 1);
        assertEq(vault.usersToRedeemAt(1, _batchId)[0], mockUser_1);
    }

    function test_requestRedeem_whenFlowIsUnpaused_whenUserHasSufficientSharesToRedeem_shouldSucceed_multipleUsers()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set shares of users
        vault.setSharesOf(0, mockUser_1, 100 ether);
        vault.setSharesOf(0, mockUser_2, 300 ether);

        // Capture batch ID before emit expectation
        uint48 _expectedBatchId = vault.currentBatch();

        // request redeem
        vm.prank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.RedeemRequest(mockUser_1, 1, 100 ether, _expectedBatchId);
        uint48 _batchId_user1 = vault.requestRedeem(1, 100 ether);

        vm.prank(mockUser_2);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.RedeemRequest(mockUser_2, 1, 150 ether, _expectedBatchId);
        uint48 _batchId_user2 = vault.requestRedeem(1, 150 ether);

        // check the redeem requests
        assertEq(_batchId_user1, _batchId_user2);
        assertEq(vault.redeemRequestOfAt(1, mockUser_1, _batchId_user1), vault.TOTAL_SHARE_UNITS());
        assertEq(vault.redeemRequestOfAt(1, mockUser_2, _batchId_user1), vault.TOTAL_SHARE_UNITS() / 2);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1).length, 2);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1)[0], mockUser_1);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1)[1], mockUser_2);
    }
}
