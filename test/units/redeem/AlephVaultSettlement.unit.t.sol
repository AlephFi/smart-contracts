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
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeemSettlementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        IAlephVault.ShareClassParams memory _shareClassParams;
        _initializationParams.userInitializationParams.shareClassParams = _shareClassParams;
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
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_revertsGivenFlowIsPaused() public {
        // pause settle redeem flow
        vm.prank(manager);
        vault.pause(PausableFlows.SETTLE_REDEEM_FLOW);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenNoticePeriodHasNotExpired() public {
        // set notice period
        vault.setNoticePeriod(1, 1);

        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.InvalidToBatchId.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 1,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenToBatchIdIsEqualToRedeemSettleId()
        public
    {
        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.NoRedeemsToSettle.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_revertsGivenNewTotalAssetsIsInvalid() public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.InvalidNewTotalAssets.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](2),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenAuthSignatureIsInvalid() public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // make invalid sig
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(AuthLibrary.InvalidAuthSignature.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenLastFeePaidIdIsLessThanCurrentBatchId_shouldCallAccumulateFees(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // assert last fee paid id is less than current batch id
        assertLt(vault.lastFeePaidId(), _currentBatchId);

        // set new total assets
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.prank(oracle);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );

        // assert last fee paid id is equal to current batch id
        assertEq(vault.lastFeePaidId(), _currentBatchId);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsZero_shouldSettleRedeem()
        public
    {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // assert redeem settle id is less than current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertLt(vault.redeemSettleId(), _currentBatchId);

        // set new total assets
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.prank(oracle);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_revertsGivenVaultHasInsufficientBalance(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        vault.setSharesOf(0, mockUser_1, 1000 ether);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, vault.TOTAL_SHARE_UNITS() / 2);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(vault), 0, 500 ether)
        );
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_shouldSucceed_singleBatch(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, 3 * vault.TOTAL_SHARE_UNITS() / 4);
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_2, vault.TOTAL_SHARE_UNITS() / 4);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](2);
        _newTotalAssets[0] = 1000 ether;
        _newTotalAssets[1] = 1000 ether;
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        vault.setSharesOf(0, mockUser_1, 500 ether);
        vault.setSharesOf(0, mockUser_2, 500 ether);
        vault.createNewSeries();
        vault.setTotalAssets(1, 1000 ether);
        vault.setTotalShares(1, 1000 ether);
        vault.setSharesOf(1, mockUser_1, 500 ether);
        vault.setSharesOf(1, mockUser_2, 500 ether);

        // mint balance for vault
        underlyingToken.mint(address(vault), 2000 ether);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 1, mockUser_1, 1, 0, 500 ether, 500 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 1, mockUser_1, 1, 1, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 1, mockUser_2, 1, 0, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(_currentBatchId - 1, 1, 1000 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(0, _currentBatchId, 1);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), 250 ether);
        assertEq(vault.totalAssetsPerSeries(1, 1), 750 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 250 ether);
        assertEq(vault.totalSharesPerSeries(1, 1), 750 ether);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);

        // assert balance of vault is 1000
        assertEq(underlyingToken.balanceOf(address(vault)), 1000 ether);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 250 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 250 ether);
        assertEq(vault.sharesOf(1, 1, mockUser_2), 500 ether);

        // assert balance of users
        assertEq(underlyingToken.balanceOf(mockUser_1), 750 ether);
        assertEq(underlyingToken.balanceOf(mockUser_2), 250 ether);
    }

    function test_settleRedeem_whenCallerIsOracle_whenFlowIsUnpaused_whenSharesToSettleIsGreaterThanZero_shouldSucceed_multipleBatches(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set batch redeem requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchRedeem(_currentBatchId - 2, mockUser_1, vault.TOTAL_SHARE_UNITS() / 4);
        vault.setBatchRedeem(_currentBatchId - 2, mockUser_2, vault.TOTAL_SHARE_UNITS() / 2);
        vault.setBatchRedeem(_currentBatchId - 1, mockUser_1, vault.TOTAL_SHARE_UNITS() / 2);

        // set total assets and total shares
        uint256[] memory _newTotalAssets = new uint256[](2);
        _newTotalAssets[0] = 1000 ether;
        _newTotalAssets[1] = 1000 ether;
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        vault.setSharesOf(0, mockUser_1, 500 ether);
        vault.setSharesOf(0, mockUser_2, 500 ether);
        vault.createNewSeries();
        vault.setTotalAssets(1, 1000 ether);
        vault.setTotalShares(1, 1000 ether);
        vault.setSharesOf(1, mockUser_1, 500 ether);
        vault.setSharesOf(1, mockUser_2, 500 ether);

        // mint balance for vault
        underlyingToken.mint(address(vault), 2000 ether);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 2, mockUser_1, 1, 0, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 2, mockUser_2, 1, 0, 500 ether, 500 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(_currentBatchId - 2, 1, 750 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 1, mockUser_1, 1, 0, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            _currentBatchId - 1, mockUser_1, 1, 1, 125 ether, 125 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(_currentBatchId - 1, 1, 375 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(0, _currentBatchId, 1);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), 0 ether);
        assertEq(vault.totalAssetsPerSeries(1, 1), 875 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 0 ether);
        assertEq(vault.totalSharesPerSeries(1, 1), 875 ether);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _currentBatchId);

        // assert balance of vault is 200
        assertEq(underlyingToken.balanceOf(address(vault)), 875 ether);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 375 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0 ether);
        assertEq(vault.sharesOf(1, 1, mockUser_2), 500 ether);

        // assert balance of users
        assertEq(underlyingToken.balanceOf(mockUser_1), 625 ether);
        assertEq(underlyingToken.balanceOf(mockUser_2), 500 ether);
    }
}
