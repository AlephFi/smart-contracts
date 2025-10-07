// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
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
        _shareClassParams.minDepositAmount = 10 ether;
        _shareClassParams.minRedeemAmount = 10 ether;
        _initializationParams.userInitializationParams.shareClassParams = _shareClassParams;
        _setUpNewAlephVault(defaultConfigParams, _initializationParams);
        _unpauseVaultFlows();
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLE REDEEM TESTS
    //////////////////////////////////////////////////////////////*/
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

    function test_settleRedeem_revertWhenClassIdIsInvalid() public {
        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 0,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_revertsGivenFlowIsPaused() public {
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

    function test_settleRedeem_revertsWhenToBatchIdIsGreaterThanCurrentBatchId() public {
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

    function test_settleRedeem_revertsWhenNoticePeriodHasNotExpired() public {
        // set notice period
        vault.setNoticePeriod(1, 1);

        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.NoRedeemsToSettle.selector);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 1,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleRedeem_revertsWhenToBatchIdIsEqualToRedeemSettleId() public {
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

    function test_settleRedeem_revertsGivenNewTotalAssetsIsInvalid() public {
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

    function test_settleRedeem_revertsWhenAuthSignatureIsInvalid() public {
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

    function test_settleRedeem_whenLastFeePaidIdIsLessThanCurrentBatchId_shouldCallAccumulateFees() public {
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

    function test_settleRedeem_whenSharesToSettleIsZero_shouldSettleRedeem() public {
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

    function test_settleRedeem_whenSharesToSettleIsZero_revertsWhenVaultDoesNotHaveSufficientBalance() public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // set deposit request
        vault.setBatchDeposit(0, mockUser_1, 100 ether);

        // set new total assets
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, _newTotalAssets);

        // settle redeem
        vm.prank(oracle);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultSettlement.InsufficientAssetsToSettle.selector, 100 ether));
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );
    }

    function test_settleRedeem_whenSharesToSettleIsGreaterThanZero_shouldSucceed_singleBatch() public {
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
            1, 0, _currentBatchId - 1, mockUser_1, 500 ether, 500 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            1, 1, _currentBatchId - 1, mockUser_1, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            1, 0, _currentBatchId - 1, mockUser_2, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(1, _currentBatchId - 1, 1000 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(1, 0, _currentBatchId);
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

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 250 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 250 ether);
        assertEq(vault.sharesOf(1, 1, mockUser_2), 500 ether);

        // assert balance of users
        assertEq(vault.redeemableAmount(mockUser_1), 750 ether);
        assertEq(vault.redeemableAmount(mockUser_2), 250 ether);
    }

    function test_settleRedeem_whenSharesToSettleIsGreaterThanZero_shouldSucceed_multipleBatches() public {
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
            1, 0, _currentBatchId - 2, mockUser_1, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            1, 0, _currentBatchId - 2, mockUser_2, 500 ether, 500 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(1, _currentBatchId - 2, 750 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            1, 0, _currentBatchId - 1, mockUser_1, 250 ether, 250 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(
            1, 1, _currentBatchId - 1, mockUser_1, 125 ether, 125 ether
        );
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(1, _currentBatchId - 1, 375 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(1, 0, _currentBatchId);
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

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 375 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0 ether);
        assertEq(vault.sharesOf(1, 1, mockUser_2), 500 ether);

        // assert balance of users
        assertEq(vault.redeemableAmount(mockUser_1), 625 ether);
        assertEq(vault.redeemableAmount(mockUser_2), 500 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            FORCE REDEEM TESTS
    //////////////////////////////////////////////////////////////*/
    function test_forceRedeem_revertsGivenCallerIsNotManager() public {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // force redeem
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.forceRedeem(mockUser_1);
    }

    function test_forceRedeem_revertsWhenVaultDoesNotHaveSufficientBalanceToSettlePendingDepositsAndWithdrawls()
        public
    {
        // set deposit request
        vault.setBatchDeposit(0, mockUser_1, 100 ether);

        // force redeem
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultSettlement.InsufficientAssetsToSettle.selector, 100 ether));
        vault.forceRedeem(mockUser_1);
    }

    function test_forceRedeem_whenVaultHasSufficientBalanceToSettlePendingDepositsAndWithdrawls_shouldSucceed()
        public
    {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set deposit request
        vault.setBatchDeposit(0, mockUser_1, 100 ether);
        vault.setBatchDeposit(1, mockUser_1, 200 ether);
        vault.setBatchRedeem(2, mockUser_1, 100 ether);
        vault.setBatchRedeem(3, mockUser_1, 300 ether);

        // set total assets and total shares
        vault.createNewSeries();
        vault.setTotalAssets(0, 200 ether);
        vault.setTotalShares(0, 200 ether);
        vault.setTotalAssets(1, 200 ether);
        vault.setTotalShares(1, 200 ether);
        vault.setSharesOf(0, mockUser_1, 200 ether);
        vault.setSharesOf(1, mockUser_1, 200 ether);

        // mint balance for vault
        underlyingToken.mint(address(vault), 700 ether);

        // force redeem
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.ForceRedeem(3, mockUser_1, 700 ether);
        vault.forceRedeem(mockUser_1);

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), 0);
        assertEq(vault.totalAssetsPerSeries(1, 1), 0);
        assertEq(vault.totalSharesPerSeries(1, 0), 0);
        assertEq(vault.totalSharesPerSeries(1, 1), 0);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 0);

        // assert balance of users
        assertEq(vault.redeemableAmount(mockUser_1), 700 ether);

        // assert user deposit requests are deleted
        assertEq(vault.depositRequestOf(1, mockUser_1), 0);

        // assert user redeem requests are deleted
        assertEq(vault.redeemRequestOf(1, mockUser_1), 0);
    }
}
