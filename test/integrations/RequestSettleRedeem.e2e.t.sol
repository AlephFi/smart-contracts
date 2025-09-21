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

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
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
contract RequestSettleRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        IAlephVault.ShareClassParams memory _shareClassParams;
        _shareClassParams.minDepositAmount = 10 ether;
        _shareClassParams.minRedeemAmount = 10 ether;
        _initializationParams.userInitializationParams.shareClassParams = _shareClassParams;
        _setUpNewAlephVault(defaultConfigParams, _initializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIsConstant() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);

        // request redeem
        IAlephVaultRedeem.RedeemRequestParams memory params =
            IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 100 ether});
        vm.startPrank(mockUser_1);
        vault.requestRedeem(params);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _settleBatchId, _newTotalAssets);

        // set vault balance
        underlyingToken.mint(address(vault), 100 ether);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSliceSettled(1, mockUser_1, 1, 0, 100 ether, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.RedeemRequestSettled(1, mockUser_1, 1, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(1, 1, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(0, 2, 1);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), 900 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 900 ether);

        // assert user assets are received
        assertEq(vault.redeemableAmount(mockUser_1), 100 ether);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIncreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1200 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);

        // request redeem
        IAlephVaultRedeem.RedeemRequestParams memory params =
            IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether});
        vm.startPrank(mockUser_1);
        vault.requestRedeem(params);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(mockUser_1);
        vault.requestRedeem(params);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _settleBatchId, _newTotalAssets);

        // set vault balance
        underlyingToken.mint(address(vault), 120 ether);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeemBatch(1, 1, 60 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleRedeem(0, 3, 1);
        vault.settleRedeem(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 0), 1080 ether, 2);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 0), 900 ether, 2);

        // assert user shares are burned
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);

        // assert user assets are received
        assertApproxEqAbs(vault.redeemableAmount(mockUser_1), 120 ether, 2);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsDecreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.createNewSeries();
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        vault.setTotalAssets(1, 1000 ether);
        vault.setTotalShares(1, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](2);
        _newTotalAssets[0] = 800 ether;
        _newTotalAssets[1] = 800 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);
        vault.setSharesOf(1, mockUser_1, 300 ether);

        // request redeem
        IAlephVaultRedeem.RedeemRequestParams memory params =
            IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 100 ether});
        vm.startPrank(mockUser_1);
        vault.requestRedeem(params);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        params.estAmountToRedeem = 150 ether;
        vm.startPrank(mockUser_1);
        vault.requestRedeem(params);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _settleBatchId, _newTotalAssets);

        // set vault balance
        underlyingToken.mint(address(vault), 200 ether);

        // settle redeem
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

        // assert total assets and total shares
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 0), 720 ether, 1);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 0), 900 ether, 1);
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 1), 680 ether, 1);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 1), 850 ether, 1);

        // assert user shares are burned
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 150 ether);

        // assert user assets are received
        assertApproxEqAbs(vault.redeemableAmount(mockUser_1), 200 ether, 1);
    }
}
