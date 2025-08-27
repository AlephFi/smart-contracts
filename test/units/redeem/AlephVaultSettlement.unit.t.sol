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
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultRedeemSettlementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: 0, // 0%
                performanceFee: 0, // 0%
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap
            }),
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        _setUpNewAlephVault(defaultConfigParams, _initializationParams);
        _unpauseVaultFlows();
    }

    function test_settleRedeem_revertsGivenCallerIsNotOracle() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // settle redeem
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.ORACLE
            )
        );
        vault.settleRedeem(1, new uint256[](0));
    }

    function test_settleRedeem_whenCallerIsOracle_revertsGivenFlowIsPaused() public {
        // pause settle redeem flow
        vm.prank(manager);
        vault.pause(PausableFlows.SETTLE_REDEEM_FLOW);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.settleRedeem(1, new uint256[](0));
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_revertsGivenRedeemSettleIdIsEqualToCurrentBatchId()
        public
    {
        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IERC7540Settlement.NoRedeemsToSettle.selector);
        vault.settleRedeem(1, new uint256[](0));
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenLastFeePaidIdIsLessThanCurrentBatchId_shouldCallAccumulateFees(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);

        // assert last fee paid id is less than current batch id
        assertLt(vault.lastFeePaidId(), vault.currentBatch());

        // settle redeem
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000;
        vm.prank(oracle);
        vault.settleRedeem(1, _newTotalAssets);

        // assert last fee paid id is equal to current batch id
        assertEq(vault.lastFeePaidId(), vault.currentBatch());
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsZero_shouldSettleRedeem()
        public
    {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // assert redeem settle id is less than current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertLt(vault.redeemSettleId(), _currentBatchId);

        // settle redeem
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000;
        vm.prank(oracle);
        vault.settleRedeem(1, _newTotalAssets);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_revertsGivenVaultHasInsufficientBalance(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, 100);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(vault), 0, 100));
        vault.settleRedeem(1, _newTotalAssets);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_shouldSucceed_singleBatch(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, 100);
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_2, 200);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // mint balance for vault
        underlyingToken.mint(address(vault), 1000);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(_currentBatchId - 1, 1, 300);
        emit IERC7540Settlement.SettleRedeem(0, _currentBatchId, 1);
        vault.settleRedeem(1, _newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 700);
        assertEq(vault.totalShares(), 700);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);

        // assert balance of vault is 700
        assertEq(underlyingToken.balanceOf(address(vault)), 700);

        // assert balance of users
        assertEq(underlyingToken.balanceOf(mockUser_1), 100);
        assertEq(underlyingToken.balanceOf(mockUser_2), 200);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_shouldSucceed_multipleBatches(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 2, mockUser_1, 100);
        vault.setBatchRedeem(_currentBatchId - 2, mockUser_2, 200);
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, 500);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000;
        vault.setTotalAssets(1000);
        vault.setTotalShares(1000);

        // mint balance for vault
        underlyingToken.mint(address(vault), 1000);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(_currentBatchId - 2, 1, 300);
        emit IERC7540Settlement.SettleRedeemBatch(_currentBatchId - 1, 1, 500);
        emit IERC7540Settlement.SettleRedeem(1, _currentBatchId, 1);
        vault.settleRedeem(1, _newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 200);
        assertEq(vault.totalShares(), 200);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);

        // assert balance of vault is 200
        assertEq(underlyingToken.balanceOf(address(vault)), 200);

        // assert balance of users
        assertEq(underlyingToken.balanceOf(mockUser_1), 600);
        assertEq(underlyingToken.balanceOf(mockUser_2), 200);
    }
}
