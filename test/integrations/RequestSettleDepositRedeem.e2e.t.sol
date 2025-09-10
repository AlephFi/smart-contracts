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
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract RequestSettleDepositRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();
    }

    function test_requestSettleDeposit_requestSettleRedeem() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users with tokens
        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        // set vault allowance
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // requestdeposit
        uint48 _requestBatchId_1 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount = 300 ether;

        // assert deposit requests
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _requestBatchId_1), 100 ether);
        assertEq(vault.depositRequestOfAt(1, mockUser_2, _requestBatchId_1), 200 ether);
        assertEq(vault.totalAmountToDepositAt(1, _requestBatchId_1), _totalDepositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1))
        });

        // expected shares to mint per user
        uint256 _expectedSharesToMint_user1 = 100 ether;
        uint256 _expectedSharesToMint_user2 = 200 ether;

        // settle deposit
        vm.startPrank(oracle);
        vault.settleDeposit(_settlementParams);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), _totalDepositAmount);
        assertEq(vault.totalSharesPerSeries(1, 0), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

        // assert user shares are minted
        assertEq(vault.sharesOf(1, 0, mockUser_1), _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(1, 0, mockUser_2), _expectedSharesToMint_user2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request redeem
        uint48 _requestBatchId_2 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestRedeem(1, 100 ether);
        vm.prank(mockUser_2);
        vault.requestRedeem(1, 200 ether);
        uint256 _totalAmountToRedeem = 300 ether;

        // assert redeem requests
        assertEq(vault.redeemRequestOfAt(1, mockUser_1, _requestBatchId_2), vault.TOTAL_SHARE_UNITS());
        assertEq(vault.redeemRequestOfAt(1, mockUser_2, _requestBatchId_2), vault.TOTAL_SHARE_UNITS());

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // vault makes a profit
        _settlementParams.newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0) + 50 ether;
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256 _expectedManagementShares =
            vault.getManagementFeeShares(_settlementParams.newTotalAssets[0], _totalShares, 2);
        uint256 _expectedPerformanceShares =
            vault.getPerformanceFeeShares(_settlementParams.newTotalAssets[0], _totalShares);
        _totalShares += _expectedManagementShares + _expectedPerformanceShares;

        // expected assets to withdraw per user
        uint256 _expectedAssetsToWithdraw_user1 =
            ERC4626Math.previewRedeem(100 ether, _settlementParams.newTotalAssets[0], _totalShares);
        uint256 _expectedAssetsToWithdraw_user2 =
            ERC4626Math.previewRedeem(200 ether, _settlementParams.newTotalAssets[0], _totalShares);
        uint256 _expectedAssetsToWithdraw = _expectedAssetsToWithdraw_user1 + _expectedAssetsToWithdraw_user2;

        // set vault balance
        underlyingToken.mint(address(vault), _expectedAssetsToWithdraw);

        // settle redeem
        _settlementParams.toBatchId = vault.currentBatch();
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_REDEEM, _settlementParams.toBatchId, _settlementParams.newTotalAssets
        );
        vm.startPrank(oracle);
        vault.settleRedeem(_settlementParams);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), _settlementParams.newTotalAssets[0] - _expectedAssetsToWithdraw);
        assertEq(vault.totalSharesPerSeries(1, 0), _totalShares - 300 ether);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), 900 ether + _expectedAssetsToWithdraw_user1);
        assertEq(underlyingToken.balanceOf(mockUser_2), 800 ether + _expectedAssetsToWithdraw_user2);

        // assert fees are accumulated
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _expectedManagementShares);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), _expectedPerformanceShares);
    }

    function test_requestSettleDeposit_requestSettleRedeem_multipleBatches() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users with tokens
        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        // set vault allowance
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // requestdeposit
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_1 = 300 ether;

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // requestdeposit
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_2 = 500 ether;

        // roll the block forward some batches
        vm.warp(block.timestamp + 3 days);

        // expected shares to mint per user
        uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(500 ether, 0, 0);

        uint256[] memory _newTotalAssets = new uint256[](1);

        // settle deposit
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);
        vm.startPrank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), _totalDepositAmount_1 + _totalDepositAmount_2);
        assertEq(vault.totalSharesPerSeries(1, 0), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

        // assert user shares are minted
        assertEq(vault.sharesOf(1, 0, mockUser_1), _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(1, 0, mockUser_2), _expectedSharesToMint_user2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // requestdeposit
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 400 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_3 = 700 ether;

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request redeem
        vm.prank(mockUser_1);
        vault.requestRedeem(1, 300 ether);
        vm.prank(mockUser_2);
        vault.requestRedeem(1, 400 ether);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // vault makes a profit
        _newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0) + 50 ether;
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256 _expectedManagementShares = vault.getManagementFeeShares(_newTotalAssets[0], _totalShares, 3);
        uint256 _expectedPerformanceShares = vault.getPerformanceFeeShares(_newTotalAssets[0], _totalShares);
        _totalShares += _expectedManagementShares + _expectedPerformanceShares;

        // expected shares to mint per user
        _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, _totalShares, _newTotalAssets[0]);
        _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(400 ether, _totalShares, _newTotalAssets[0]);

        // settle deposit
        _settleBatchId = vault.currentBatch();
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);
        vm.startPrank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), _newTotalAssets[0] + _totalDepositAmount_3);
        assertEq(
            vault.totalSharesPerSeries(1, 0), _totalShares + _expectedSharesToMint_user1 + _expectedSharesToMint_user2
        );

        // assert user shares are minted
        assertEq(vault.sharesOf(1, 0, mockUser_1), 300 ether + _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 500 ether + _expectedSharesToMint_user2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // vault does not make profit
        _newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0);
        _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256 _expectedManagementShares_2 = vault.getManagementFeeShares(_newTotalAssets[0], _totalShares, 1);
        _totalShares += _expectedManagementShares_2;

        // expected amount to withdraw per user
        uint256 _expectedAssetsToWithdraw_user1 = vault.assetsOf(1, 0, mockUser_1);
        uint256 _expectedAssetsToWithdraw_user2 = 4 * vault.assetsOf(1, 0, mockUser_2) / 5;
        uint256 _expectedAssetsToWithdraw = _expectedAssetsToWithdraw_user1 + _expectedAssetsToWithdraw_user2;

        // set vault balance
        underlyingToken.mint(address(vault), _expectedAssetsToWithdraw);

        // settle redeem
        _settleBatchId = vault.currentBatch();
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _settleBatchId, _newTotalAssets);
        vm.startPrank(oracle);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets
        assertApproxEqRel(vault.totalAssetsPerSeries(1, 0), _newTotalAssets[0] - _expectedAssetsToWithdraw, 1e16);

        // assert user assets are received
        assertApproxEqRel(underlyingToken.balanceOf(mockUser_1), 400 ether + _expectedAssetsToWithdraw_user1, 1e14);
        assertApproxEqRel(underlyingToken.balanceOf(mockUser_2), 100 ether + _expectedAssetsToWithdraw_user2, 1e14);

        // assert fees are accumulated
        assertEq(
            vault.sharesOf(1, 0, vault.managementFeeRecipient()),
            _expectedManagementShares + _expectedManagementShares_2
        );
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), _expectedPerformanceShares);
    }
}
