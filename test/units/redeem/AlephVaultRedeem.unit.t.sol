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
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
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

    function test_requestRedeem_revertsGivenSharesToRedeemIsZero() public {
        // request redeem
        vm.expectRevert(IERC7540Redeem.InsufficientRedeem.selector);
        vault.requestRedeem(1, 0);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsWhenNoBatchAvailable() public {
        // request redeem
        vm.expectRevert(IERC7540Redeem.NoBatchAvailableForRedeem.selector);
        vault.requestRedeem(1, 100);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsWhenLastRedeemBatchIdIsNotLessThanCurrentBatchId() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set last redeem id to current batch id
        vault.setLastRedeemBatchId(mockUser_1, vault.currentBatch());

        // request redeem
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Redeem.OnlyOneRequestPerBatchAllowedForRedeem.selector);
        vault.requestRedeem(1, 100);
    }

    function test_requestRedeem_whenFlowIsUnpaused_revertsWhenUserHasInsufficientAssetsToRedeem() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Redeem.InsufficientAssetsToRedeem.selector);
        vault.requestRedeem(1, 100);
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
        emit IERC7540Redeem.RedeemRequest(mockUser_1, 1, 100 ether, _expectedBatchId);
        uint48 _batchId = vault.requestRedeem(1, 100 ether);

        // check the redeem request
        assertEq(vault.redeemRequestOfAt(1, mockUser_1, _batchId), vault.PRICE_DENOMINATOR());
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
        emit IERC7540Redeem.RedeemRequest(mockUser_1, 1, 100 ether, _expectedBatchId);
        uint48 _batchId_user1 = vault.requestRedeem(1, 100 ether);

        vm.prank(mockUser_2);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_2, 1, 150 ether, _expectedBatchId);
        uint48 _batchId_user2 = vault.requestRedeem(1, 150 ether);

        // check the redeem requests
        assertEq(_batchId_user1, _batchId_user2);
        assertEq(vault.redeemRequestOfAt(1, mockUser_1, _batchId_user1), vault.PRICE_DENOMINATOR());
        assertEq(vault.redeemRequestOfAt(1, mockUser_2, _batchId_user1), vault.PRICE_DENOMINATOR() / 2);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1).length, 2);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1)[0], mockUser_1);
        assertEq(vault.usersToRedeemAt(1, _batchId_user1)[1], mockUser_2);
    }
}
