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
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultDepositSettlementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_settleDeposit_revertsGivenCallerIsNotOracle() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // settle deposit
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.ORACLE
            )
        );
        vault.settleDeposit(1, new uint256[](1));
    }

    function test_settleDeposit_whenCallerIsOracle_revertsGivenFlowIsPaused() public {
        // pause settle deposit flow
        vm.prank(manager);
        vault.pause(PausableFlows.SETTLE_DEPOSIT_FLOW);

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.settleDeposit(1, new uint256[](1));
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_revertsGivenDepositSettleIdIsEqualToCurrentBatchId(
    ) public {
        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IERC7540Settlement.NoDepositsToSettle.selector);
        vault.settleDeposit(1, new uint256[](1));
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenLastFeePaidIdIsLessThanCurrentBatchId_shouldCallAccumulateFees(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);

        // assert last fee paid id is less than current batch id
        assertLt(vault.lastFeePaidId(), vault.currentBatch());

        // settle deposit
        vm.prank(oracle);
        vault.settleDeposit(1, new uint256[](1));

        // assert last fee paid id is equal to current batch id
        assertEq(vault.lastFeePaidId(), vault.currentBatch());
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsZero_shouldNotSettleDeposit()
        public
    {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);

        // assert deposit settle id is less than current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertLt(vault.depositSettleId(), _currentBatchId);

        // settle deposit
        vm.prank(oracle);
        vault.settleDeposit(1, new uint256[](1));

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsZero_whenNewTotalAssetsChanges_shouldUpdateTotalAssets(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);

        // check total assets and total shares
        uint256 _totalAssets = vault.totalAssets();
        uint256 _totalShares = vault.totalShares();

        // settle deposit
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = _totalAssets + 100;
        vm.prank(oracle);
        vault.settleDeposit(1, _newTotalAssets);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets[0]);
        assertEq(vault.totalShares(), _totalShares);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_revertsGivenVaultHasInsufficientBalance(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch deposit requests
        vault.setBatchDeposit(vault.currentBatch() - 1, mockUser_1, 100);

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(vault), 0, 100));
        vault.settleDeposit(1, new uint256[](1));
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_shouldSucceed_singleBatch(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch deposit requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 100);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_2, 200);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalShares(), 0);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0);

        // mint balance for vault
        underlyingToken.mint(address(vault), 300);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleDepositBatch(_currentBatchId - 1, 1, 0, 300, 300);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleDeposit(0, _currentBatchId, 1, 0, 300, 300, 300);
        vault.settleDeposit(1, new uint256[](1));
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 300);
        assertEq(vault.totalShares(), 300);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 100);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 200);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);

        // assert balance of custodian is 300
        assertEq(underlyingToken.balanceOf(address(custodian)), 300);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_shouldSucceed_multipleBatches(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);

        // assert current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertEq(_currentBatchId, 3);

        // set batch deposit requests
        vault.setBatchDeposit(_currentBatchId - 2, mockUser_1, 100);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 200);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_2, 300);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalShares(), 0);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0);

        // mint balance for vault
        underlyingToken.mint(address(vault), 600);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleDepositBatch(1, 1, 0, 100, 100);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleDepositBatch(2, 1, 0, 500, 500);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleDeposit(0, _currentBatchId, 1, 0, 600, 600, 600);
        vault.settleDeposit(1, new uint256[](1));
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 600);
        assertEq(vault.totalShares(), 600);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 300);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 300);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);

        // assert balance of custodian is 600
        assertEq(underlyingToken.balanceOf(address(custodian)), 600);
    }
}
