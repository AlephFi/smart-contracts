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

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {KycAuthLibrary} from "@aleph-vault/libraries/KycAuthLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultDepositTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConstructorParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setKycAuthSignatures();
    }

    function test_requestDeposit_revertsGivenFlowIsPaused() public {
        // pause deposit request flow
        vm.prank(manager);
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        // request deposit
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.requestDeposit(100, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsZero() public {
        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.InsufficientDeposit.selector);
        vault.requestDeposit(0, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsLessThanMinDepositAmount()
        public
    {
        // set min deposit amount to 100
        vault.setMinDepositAmount(100);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.DepositLessThanMinDepositAmount.selector);
        vault.requestDeposit(50, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsGreaterThanMaxDepositCap()
        public
    {
        // set max deposit cap to 100
        vault.setMaxDepositCap(100);

        // set total assets to 100
        vault.setTotalAssets(100);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.DepositExceedsMaxDepositCap.selector);
        vault.requestDeposit(50, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsGreaterThanMaxDepositCap_multipleUsers(
    ) public {
        // set max deposit cap to 100
        vault.setMaxDepositCap(100);

        // set total assets to 50
        vault.setTotalAssets(50);

        // set request deposit
        vm.warp(block.timestamp + 1 days + 1);
        vault.setBatchDeposit(vault.currentBatch(), mockUser_1, 30);
        vm.warp(block.timestamp + 1 days);
        vault.setBatchDeposit(vault.currentBatch(), mockUser_2, 20);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.DepositExceedsMaxDepositCap.selector);
        vault.requestDeposit(10, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenNoBatchAvailable() public {
        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.NoBatchAvailableForDeposit.selector);
        vault.requestDeposit(100, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenLastDepositIdIsNotLessThanCurrentBatchId() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set last deposit id to current batch id
        vault.setLastDepositBatchId(mockUser_1, vault.currentBatch());

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IERC7540Deposit.OnlyOneRequestPerBatchAllowedForDeposit.selector);
        vault.requestDeposit(100, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenVaultHasInsufficientAllowanceToTransfer() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        KycAuthLibrary.KycAuthSignature memory _kycAuthSignature = _getKycAuthSignature(mockUser_1, block.number + 1);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(vault), 0, 100)
        );
        vault.requestDeposit(100, _kycAuthSignature);
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenUserHasInsufficientBalanceToTransfer() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set vault allowance to 100
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 100);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(mockUser_1), 0, 100)
        );
        vault.requestDeposit(100, kycAuthSignature_1);
    }

    function test_requestDeposit_whenFlowIsUnpaused_whenDepositedTokenAmountIsNotZero_shouldSucceed_singleUser()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set user balance to 100
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), 100);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), 100);

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, 100, vault.currentBatch());
        uint48 _batchId = vault.requestDeposit(100, kycAuthSignature_1);
        vm.stopPrank();

        // check the deposit request
        assertEq(vault.totalAmountToDepositAt(_batchId), 100);
        assertEq(vault.depositRequestOfAt(mockUser_1, _batchId), 100);
        assertEq(vault.usersToDepositAt(_batchId).length, 1);
        assertEq(vault.usersToDepositAt(_batchId)[0], mockUser_1);
        assertEq(underlyingToken.balanceOf(address(vault)), 100);
        assertEq(underlyingToken.balanceOf(address(mockUser_1)), 0);
    }

    function test_requestDeposit_whenFlowIsUnpaused_whenDepositedTokenAmountIsNotZero_shouldSucceed_multipleUsers()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set user 1 balance to 100 and approve vault to spend
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), 100);
        underlyingToken.approve(address(vault), 100);

        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, 100, vault.currentBatch());
        uint48 _batchId_user1 = vault.requestDeposit(100, kycAuthSignature_1);
        vm.stopPrank();

        // set user 2 balance to 300 and approve vault to spend
        vm.startPrank(mockUser_2);
        underlyingToken.mint(address(mockUser_2), 300);
        underlyingToken.approve(address(vault), 300);

        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_2, 300, vault.currentBatch());
        uint48 _batchId_user2 = vault.requestDeposit(300, kycAuthSignature_2);
        vm.stopPrank();

        // check the deposit requests
        assertEq(_batchId_user1, _batchId_user2);
        assertEq(vault.totalAmountToDepositAt(_batchId_user1), 100 + 300);
        assertEq(vault.depositRequestOfAt(mockUser_1, _batchId_user1), 100);
        assertEq(vault.depositRequestOfAt(mockUser_2, _batchId_user1), 300);
        assertEq(vault.usersToDepositAt(_batchId_user1).length, 2);
        assertEq(vault.usersToDepositAt(_batchId_user1)[0], mockUser_1);
        assertEq(vault.usersToDepositAt(_batchId_user1)[1], mockUser_2);
        assertEq(underlyingToken.balanceOf(address(vault)), 100 + 300);
        assertEq(underlyingToken.balanceOf(address(mockUser_1)), 0);
        assertEq(underlyingToken.balanceOf(address(mockUser_2)), 0);
    }
}
