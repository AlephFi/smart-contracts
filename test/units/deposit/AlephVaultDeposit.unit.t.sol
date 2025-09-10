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
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultDepositTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();
    }

    function test_requestDeposit_revertsWhenClassIdIsInvalid() public {
        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 0, amount: 100, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_revertsGivenFlowIsPaused() public {
        // pause deposit request flow
        vm.prank(manager);
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        // request deposit
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsZero() public {
        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.InsufficientDeposit.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 0, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsLessThanMinDepositAmount()
        public
    {
        // set min deposit amount to 100 ether
        vault.setMinDepositAmount(1, 100 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.DepositLessThanMinDepositAmount.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountDoesntMaintainMinUserBalance()
        public
    {
        // set min user balance to 200 ether
        vault.setMinUserBalance(1, 200 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.DepositLessThanMinUserBalance.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsGreaterThanMaxDepositCap()
        public
    {
        // set max deposit cap to 200 ether
        vault.setMaxDepositCap(1, 200 ether);

        // set total assets to 200 ether
        vault.setTotalAssets(0, 200 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.DepositExceedsMaxDepositCap.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenDepositedTokenAmountIsGreaterThanMaxDepositCap_multipleUsers(
    ) public {
        // set max deposit cap to 300 ether
        vault.setMaxDepositCap(1, 300 ether);

        // set total assets to 100 ether
        vault.setTotalAssets(0, 100 ether);

        // set request deposit
        vm.warp(block.timestamp + 1 days + 1);
        vault.setBatchDeposit(vault.currentBatch(), mockUser_1, 100 ether);
        vm.warp(block.timestamp + 1 days);
        vault.setBatchDeposit(vault.currentBatch(), mockUser_2, 100 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.DepositExceedsMaxDepositCap.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenAuthSignatureIsExpired() public {
        // set  auth signature expiry block to 1
        authSignature_1.expiryBlock = 0;

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(AuthLibrary.AuthSignatureExpired.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenAuthSignatureIsInvalid() public {
        // make invalid sig
        AuthLibrary.AuthSignature memory _authSignature =
            _getDepositAuthSignature(makeAddr("invalid user"), block.number + 1);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(AuthLibrary.InvalidAuthSignature.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: _authSignature})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsGivenUserHasAlreadyMadeADepositRequestForThisBatch()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set deposit request to current batch id
        vault.setBatchDeposit(vault.currentBatch(), mockUser_1, 100 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.OnlyOneRequestPerBatchAllowedForDeposit.selector);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenVaultHasInsufficientAllowanceToTransfer() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(vault), 0, 100 ether)
        );
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_revertsWhenUserHasInsufficientBalanceToTransfer() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set vault allowance to 100 ether
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 100 ether);

        // request deposit
        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(mockUser_1), 0, 100 ether)
        );
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
    }

    function test_requestDeposit_whenFlowIsUnpaused_whenDepositedTokenAmountIsNotZero_shouldSucceed_singleUser()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set user balance to 100
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), 100 ether);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), 100 ether);

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.DepositRequest(mockUser_1, 1, 100 ether, vault.currentBatch());
        uint48 _batchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // check the deposit request
        assertEq(vault.totalAmountToDepositAt(1, _batchId), 100 ether);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _batchId), 100 ether);
        assertEq(vault.usersToDepositAt(1, _batchId).length, 1);
        assertEq(vault.usersToDepositAt(1, _batchId)[0], mockUser_1);
        assertEq(underlyingToken.balanceOf(address(vault)), 100 ether);
        assertEq(underlyingToken.balanceOf(address(mockUser_1)), 0);
    }

    function test_requestDeposit_whenFlowIsUnpaused_whenDepositedTokenAmountIsNotZero_shouldSucceed_multipleUsers()
        public
    {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set user 1 balance to 100 and approve vault to spend
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), 100 ether);
        underlyingToken.approve(address(vault), 100 ether);

        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.DepositRequest(mockUser_1, 1, 100 ether, vault.currentBatch());
        uint48 _batchId_user1 = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // set user 2 balance to 300 and approve vault to spend
        vm.startPrank(mockUser_2);
        underlyingToken.mint(address(mockUser_2), 300 ether);
        underlyingToken.approve(address(vault), 300 ether);

        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.DepositRequest(mockUser_2, 1, 300 ether, vault.currentBatch());
        uint48 _batchId_user2 = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_2})
        );
        vm.stopPrank();

        // check the deposit requests
        assertEq(_batchId_user1, _batchId_user2);
        assertEq(vault.totalAmountToDepositAt(1, _batchId_user1), 100 ether + 300 ether);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _batchId_user1), 100 ether);
        assertEq(vault.depositRequestOfAt(1, mockUser_2, _batchId_user1), 300 ether);
        assertEq(vault.usersToDepositAt(1, _batchId_user1).length, 2);
        assertEq(vault.usersToDepositAt(1, _batchId_user1)[0], mockUser_1);
        assertEq(vault.usersToDepositAt(1, _batchId_user1)[1], mockUser_2);
        assertEq(underlyingToken.balanceOf(address(vault)), 100 ether + 300 ether);
        assertEq(underlyingToken.balanceOf(address(mockUser_1)), 0);
        assertEq(underlyingToken.balanceOf(address(mockUser_2)), 0);
    }
}
