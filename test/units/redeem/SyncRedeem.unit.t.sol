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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract SyncRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();

        // Set up initial settlement and user with shares
        _setupInitialSettlement();
    }

    function _setupInitialSettlement() internal {
        // Roll forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // Set up user with tokens
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Make an async deposit request
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );

        // Roll forward to next batch
        vm.warp(block.timestamp + 1 days);

        // Settle deposit to initialize sync expiration
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1)
            )
        });

        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // Set notice period to 0 (required for sync redeem)
        vault.setNoticePeriod(1, 0);

        // Verify sync is now valid
        assertTrue(vault.isTotalAssetsValid(1));
    }

    /*//////////////////////////////////////////////////////////////
                        SYNC REDEEM TESTS
    //////////////////////////////////////////////////////////////*/
    function test_syncRedeem_whenTotalAssetsValid_shouldSucceed() public {
        // Set minUserBalance to 0 so we can redeem 50 ether (user has 100 ether, would leave 50)
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 50 ether;
        uint256 _userBalanceBefore = underlyingToken.balanceOf(mockUser_1);
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));
        uint256 _totalAssetsBefore = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, 0);
        uint256 _userSharesBefore = vault.sharesOf(1, 0, mockUser_1);

        // Fund vault with assets for sync redeem
        underlyingToken.mint(address(vault), _redeemAmount);

        // Sync redeem
        vm.prank(mockUser_1);
        uint256 _assets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));

        // Assert assets returned (may differ slightly from requested due to rounding)
        assertApproxEqRel(_assets, _redeemAmount, 0.01e18); // Allow 1% difference for rounding

        // Assert assets transferred to user
        assertEq(underlyingToken.balanceOf(mockUser_1), _userBalanceBefore + _assets);
        assertEq(underlyingToken.balanceOf(address(vault)), _vaultBalanceBefore + _redeemAmount - _assets);

        // Assert shares burned
        assertLt(vault.sharesOf(1, 0, mockUser_1), _userSharesBefore);
        assertLt(vault.totalSharesPerSeries(1, 0), _totalSharesBefore);
        assertLt(vault.totalAssetsPerSeries(1, 0), _totalAssetsBefore);
    }

    function test_syncRedeem_revertsWhenTotalAssetsInvalid() public {
        // Set minUserBalance to 0 so we can test expiration check
        vault.setMinUserBalance(1, 0);

        // Get current batch and last valuation settle ID
        uint48 _currentBatch = vault.currentBatch();
        uint48 _lastValuationSettleId = vault.depositSettleId();

        // Expire total assets (sets syncExpirationBatches to 0)
        vm.prank(manager);
        vault.queueSyncExpirationBatches(0);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setSyncExpirationBatches();

        // If current batch <= lastValuationSettleId, advance time to make it invalid
        if (_currentBatch <= _lastValuationSettleId) {
            // Advance to next batch
            vm.warp(block.timestamp + 1 days);
        }

        underlyingToken.mint(address(vault), 50 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.OnlyAsyncRedeemAllowed.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));
    }

    function test_syncRedeem_revertsWhenNoticePeriodGreaterThanZero() public {
        // Set notice period to non-zero
        vault.setNoticePeriod(1, 1);

        underlyingToken.mint(address(vault), 50 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.OnlyAsyncRedeemAllowed.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));
    }

    function test_syncRedeem_revertsWhenClassIdIsInvalid() public {
        underlyingToken.mint(address(vault), 50 ether);

        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 0, estAmountToRedeem: 50 ether}));
    }

    function test_syncRedeem_revertsWhenFlowIsPaused() public {
        // Pause redeem flow
        vm.prank(manager);
        vault.pause(PausableFlows.REDEEM_REQUEST_FLOW);

        underlyingToken.mint(address(vault), 50 ether);

        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));
    }

    function test_syncRedeem_revertsWhenAmountIsZero() public {
        underlyingToken.mint(address(vault), 50 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientAssetsToRedeem.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 0}));
    }

    function test_syncRedeem_revertsWhenInsufficientUserAssets() public {
        underlyingToken.mint(address(vault), 200 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientAssetsToRedeem.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 200 ether}));
    }

    function test_syncRedeem_revertsWhenInsufficientVaultBalance() public {
        // Set minUserBalance to 0 so we can test vault balance check
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 50 ether;

        // Don't fund vault
        // underlyingToken.mint(address(vault), _redeemAmount);

        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientVaultBalance.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));
    }

    function test_syncRedeem_doesNotModifyState_whenVaultBalanceInsufficient() public {
        // Bug fix test: Verify that state is not modified before vault balance check
        // Set minUserBalance to 0 so we can test vault balance check
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 50 ether;
        uint256 _userSharesBefore = vault.sharesOf(1, 0, mockUser_1);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, 0);
        uint256 _totalAssetsBefore = vault.totalAssetsPerSeries(1, 0);

        // Don't fund vault - should revert before modifying state
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientVaultBalance.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));

        // Verify state was NOT modified (shares not burned, assets not decreased)
        assertEq(vault.sharesOf(1, 0, mockUser_1), _userSharesBefore, "User shares should not be modified");
        assertEq(vault.totalSharesPerSeries(1, 0), _totalSharesBefore, "Total shares should not be modified");
        assertEq(vault.totalAssetsPerSeries(1, 0), _totalAssetsBefore, "Total assets should not be modified");
    }

    function test_syncRedeem_previewMatchesActualRedeem() public {
        // Bug fix test: Verify that preview calculation matches actual redeem
        // Set minUserBalance to 0 so we can test
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 30 ether;
        underlyingToken.mint(address(vault), _redeemAmount);

        uint256 _userSharesBefore = vault.sharesOf(1, 0, mockUser_1);
        uint256 _totalAssetsBefore = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, 0);

        // Calculate expected assets using preview logic
        uint256 _expectedAssets = 0;
        uint256 _remainingAmount = _redeemAmount;
        uint256 _sharesInSeries = _userSharesBefore;
        uint256 _amountInSeries = ERC4626Math.previewRedeem(_sharesInSeries, _totalAssetsBefore, _totalSharesBefore);
        if (_amountInSeries <= _remainingAmount) {
            _expectedAssets = _amountInSeries;
        } else {
            uint256 _sharesToBurn =
                ERC4626Math.previewWithdraw(_remainingAmount, _totalSharesBefore, _totalAssetsBefore);
            _expectedAssets = _remainingAmount;
        }

        // Perform sync redeem
        vm.prank(mockUser_1);
        uint256 _actualAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));

        // Verify actual assets match expected (allowing for rounding differences)
        assertApproxEqRel(_actualAssets, _expectedAssets, 0.01e18, "Preview should match actual redeem");
    }

    function test_syncRedeem_revertsWhenAmountLessThanMinRedeemAmount() public {
        vault.setMinRedeemAmount(1, 30 ether);

        // User has 100 ether worth of shares, trying to redeem 20 ether
        underlyingToken.mint(address(vault), 20 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultRedeem.RedeemLessThanMinRedeemAmount.selector, 30 ether));
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 20 ether}));
    }

    function test_syncRedeem_revertsWhenUserInLockInPeriod() public {
        // Set minUserBalance to 0 so we can test lock-in period check
        vault.setMinUserBalance(1, 0);

        vault.setLockInPeriod(1, 5);
        uint48 _lockInPeriodBatch = vault.currentBatch() + 10;
        vault.setUserLockInPeriod(1, _lockInPeriodBatch, mockUser_1);

        // Get user's actual assets to redeem (should be less than total to test partial redeem with lock-in)
        uint256 _userAssets = vault.assetsPerClassOf(1, mockUser_1);
        uint256 _redeemAmount = _userAssets / 2; // Redeem half

        underlyingToken.mint(address(vault), _redeemAmount);

        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IAlephVaultRedeem.UserInLockInPeriodNotElapsed.selector, _lockInPeriodBatch)
        );
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));
    }

    function test_syncRedeem_revertsWhenRedeemFallsBelowMinUserBalance() public {
        vault.setMinUserBalance(1, 60 ether);

        // User has 100 ether, trying to redeem 50 ether (would leave 50 < 60)
        underlyingToken.mint(address(vault), 50 ether);

        vm.prank(mockUser_1);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultRedeem.RedeemFallBelowMinUserBalance.selector, 60 ether));
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));
    }

    function test_syncRedeem_revertsWhenUserInLockInPeriodAndRedeemingAll() public {
        // Set minUserBalance to 0 so we can redeem all
        vault.setMinUserBalance(1, 0);

        vault.setLockInPeriod(1, 5);
        uint48 _currentBatch = vault.currentBatch();
        vault.setUserLockInPeriod(1, _currentBatch + 5, mockUser_1);

        // Redeem all assets - should revert due to lock-in period
        uint256 _totalAssets = vault.assetsPerClassOf(1, mockUser_1);
        underlyingToken.mint(address(vault), _totalAssets);

        vm.prank(mockUser_1);
        vm.expectRevert(
            abi.encodeWithSelector(IAlephVaultRedeem.UserInLockInPeriodNotElapsed.selector, _currentBatch + 5)
        );
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _totalAssets}));
    }

    function test_syncRedeem_partialRedeem() public {
        // Set minUserBalance to 0 so we can do partial redeem
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 30 ether;
        uint256 _userSharesBefore = vault.sharesOf(1, 0, mockUser_1);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, 0);

        underlyingToken.mint(address(vault), _redeemAmount);

        vm.prank(mockUser_1);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));

        // Assert shares decreased but not to zero
        assertLt(vault.sharesOf(1, 0, mockUser_1), _userSharesBefore);
        assertGt(vault.sharesOf(1, 0, mockUser_1), 0);
        assertLt(vault.totalSharesPerSeries(1, 0), _totalSharesBefore);
    }

    function test_syncRedeem_eventIncludesAllParameters() public {
        // Set minUserBalance to 0 so we can test
        vault.setMinUserBalance(1, 0);

        uint256 _redeemAmount = 30 ether;
        uint48 _currentBatch = vault.currentBatch();
        uint256 _totalAssetsBefore = vault.totalAssetsPerClass(1);
        uint256 _totalSharesBefore;
        uint32 _shareSeriesId = vault.shareSeriesId(1);
        for (uint32 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            _totalSharesBefore += vault.totalSharesPerSeries(1, _seriesId);
            if (_seriesId == 0) {
                _seriesId = vault.lastConsolidatedSeriesId(1);
            }
        }

        underlyingToken.mint(address(vault), _redeemAmount);

        // Calculate expected assets (will be less than or equal to redeem amount due to rounding)
        uint256 _expectedAssets = _previewRedeemAmount(1, mockUser_1, _redeemAmount);
        uint256 _expectedTotalAssets = _totalAssetsBefore - _expectedAssets;
        uint256 _expectedTotalShares = _totalSharesBefore - ERC4626Math.previewWithdraw(
            _expectedAssets, _totalSharesBefore, _totalAssetsBefore
        );

        vm.prank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.SyncRedeem(
            1, mockUser_1, _redeemAmount, _expectedAssets, _currentBatch, _expectedTotalAssets, _expectedTotalShares
        );
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));
    }

    function test_syncRedeem_expirationBoundaryExactBatch() public {
        // Test that sync works in the exact batch where expiration batches = 0
        vault.setMinUserBalance(1, 0);

        // First ensure we have a recent settlement
        vm.warp(block.timestamp + 1 days);
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1)
            )
        });
        _settlementParams.newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0);
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        uint48 _settlementBatch = vault.currentBatch();

        // Set syncExpirationBatches to 0 (only valid in exact batch)
        vm.prank(manager);
        vault.queueSyncExpirationBatches(0);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setSyncExpirationBatches();

        // Ensure we're still in the same batch as settlement (don't advance time)
        // If we've moved to a new batch, we need to settle again
        if (vault.currentBatch() > _settlementBatch) {
            // Settle again to update the settle ID
            _settlementParams.toBatchId = vault.currentBatch();
            _settlementParams.newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0);
            _settlementParams.authSignature = _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
            );
            vm.prank(oracle);
            vault.settleDeposit(_settlementParams);
        }

        // We should be in the same batch as settlement, sync should still work
        uint256 _redeemAmount = 30 ether;
        underlyingToken.mint(address(vault), _redeemAmount);

        // Should succeed in the same batch
        vm.prank(mockUser_1);
        uint256 _assets = vault.syncRedeem(
            IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount})
        );
        assertGt(_assets, 0, "Sync redeem should work in exact batch when expirationBatches = 0");
    }

    function test_syncRedeem_withMultipleSeriesFIFO() public {
        // Set minUserBalance to 0 so we can test
        vault.setMinUserBalance(1, 0);

        // Create multiple series by setting HWM above price
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        // Make deposits to create multiple series
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_1);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Ensure sync is still valid
        if (!vault.isTotalAssetsValid(1)) {
            vm.warp(block.timestamp + 1 days);
            uint32 _numSeries = vault.shareSeriesId(1) - vault.lastConsolidatedSeriesId(1) + 1;
            IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: vault.currentBatch(),
                newTotalAssets: new uint256[](_numSeries),
                authSignature: _getSettlementAuthSignature(
                    AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](_numSeries)
                )
            });
            _settlementParams.newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0);
            if (_numSeries > 1) {
                _settlementParams.newTotalAssets[1] = vault.totalAssetsPerSeries(1, vault.shareSeriesId(1));
            }
            _settlementParams.authSignature = _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
            );
            vm.prank(oracle);
            vault.settleDeposit(_settlementParams);
        }

        // User now has shares in multiple series (lead + new series)
        uint256 _totalUserAssets = vault.assetsPerClassOf(1, mockUser_1);
        uint256 _redeemAmount = _totalUserAssets / 2; // Redeem half

        underlyingToken.mint(address(vault), _redeemAmount);

        uint256 _sharesBeforeLead = vault.sharesOf(1, 0, mockUser_1);

        vm.prank(mockUser_1);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _redeemAmount}));

        // Verify FIFO: should redeem from lead series first
        uint256 _sharesAfterLead = vault.sharesOf(1, 0, mockUser_1);
        assertLt(_sharesAfterLead, _sharesBeforeLead, "Should redeem from lead series first (FIFO)");
    }

    // Helper function to preview redeem amount
    function _previewRedeemAmount(uint8 _classId, address _user, uint256 _amount) internal view returns (uint256) {
        uint256 _remainingAmount = _amount;
        uint32 _shareSeriesId = vault.shareSeriesId(_classId);
        uint256 _totalAssetsToRedeem = 0;

        for (uint32 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            if (_remainingAmount == 0) break;
            uint256 _sharesInSeries = vault.sharesOf(_classId, _seriesId, _user);
            uint256 _totalAssets = vault.totalAssetsPerSeries(_classId, _seriesId);
            uint256 _totalShares = vault.totalSharesPerSeries(_classId, _seriesId);
            uint256 _amountInSeries = ERC4626Math.previewRedeem(_sharesInSeries, _totalAssets, _totalShares);

            if (_amountInSeries <= _remainingAmount) {
                _totalAssetsToRedeem += _amountInSeries;
                _remainingAmount -= _amountInSeries;
            } else {
                _totalAssetsToRedeem += _remainingAmount;
                _remainingAmount = 0;
            }

            if (_seriesId == 0) {
                _seriesId = vault.lastConsolidatedSeriesId(_classId);
            }
        }

        return _totalAssetsToRedeem;
    }
}

