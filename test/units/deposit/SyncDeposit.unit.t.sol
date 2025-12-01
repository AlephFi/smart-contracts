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
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract SyncDepositTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();

        // Set up initial settlement to make sync flows valid
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

        // Verify sync is now valid
        assertTrue(vault.isTotalAssetsValid(1));
    }

    /*//////////////////////////////////////////////////////////////
                        SYNC DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_syncDeposit_whenTotalAssetsValid_shouldSucceed() public {
        // Set up user with tokens
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        uint256 _depositAmount = 100 ether;
        uint256 _balanceBefore = underlyingToken.balanceOf(custodian);
        uint256 _sharesBefore = vault.sharesOf(1, 0, mockUser_2);
        uint256 _totalAssetsBefore = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, 0);

        // Calculate expected shares
        uint256 _expectedShares = ERC4626Math.previewDeposit(_depositAmount, _totalSharesBefore, _totalAssetsBefore);

        // Sync deposit
        uint48 _currentBatch = vault.currentBatch();
        uint32 _seriesId = vault.shareSeriesId(1);
        uint256 _expectedTotalAssets = _totalAssetsBefore + _depositAmount;
        uint256 _expectedTotalShares = _totalSharesBefore + _expectedShares;

        vm.prank(mockUser_2);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.SyncDeposit(
            1,
            mockUser_2,
            _depositAmount,
            _expectedShares,
            _seriesId,
            _currentBatch,
            _expectedTotalAssets,
            _expectedTotalShares
        );
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_2
            })
        );

        // Assert shares returned
        assertEq(_shares, _expectedShares);

        // Assert shares minted
        assertEq(vault.sharesOf(1, 0, mockUser_2), _sharesBefore + _expectedShares);
        assertEq(vault.totalSharesPerSeries(1, 0), _totalSharesBefore + _expectedShares);
        assertEq(vault.totalAssetsPerSeries(1, 0), _totalAssetsBefore + _depositAmount);

        // Assert assets transferred to custodian
        assertEq(underlyingToken.balanceOf(custodian), _balanceBefore + _depositAmount);
        assertEq(underlyingToken.balanceOf(address(vault)), 0);
    }

    function test_syncDeposit_revertsWhenTotalAssetsInvalid() public {
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

        // Set up user with tokens
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit should revert
        vm.prank(mockUser_2);
        vm.expectRevert(IAlephVaultDeposit.OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_createsNewSeries_whenHWMAbovePrice() public {
        // Set minUserBalance to 0 to avoid balance checks
        vault.setMinUserBalance(1, 0);

        // Set up performance fee
        vm.prank(manager);
        vault.queuePerformanceFee(1, 2000); // 20% performance fee
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setPerformanceFee(1);

        // Create a scenario where HWM > current price
        // First, make an async deposit request and settle it
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );

        // Roll forward and settle
        vm.warp(block.timestamp + 1 days);
        IAlephVaultSettlement.SettlementParams memory _initialSettlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1)
            )
        });
        _initialSettlementParams.newTotalAssets[0] = 100 ether;
        _initialSettlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _initialSettlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_initialSettlementParams);

        // Roll forward and settle with gains (HWM increases)
        vm.warp(block.timestamp + 1 days);
        // Check current series count before creating settlement params
        uint32 _shareSeriesIdBefore = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdBefore = vault.lastConsolidatedSeriesId(1);
        uint32 _numSeriesBefore = _shareSeriesIdBefore - _lastConsolidatedSeriesIdBefore + 1;
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](_numSeriesBefore),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](_numSeriesBefore)
            )
        });
        _settlementParams.newTotalAssets[0] = 120 ether; // 20% gain
        if (_numSeriesBefore > 1) {
            // If there are multiple series, set assets for all of them
            for (uint32 i = 1; i < _numSeriesBefore; i++) {
                _settlementParams.newTotalAssets[i] = 0; // Other series have no assets yet
            }
        }
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // Now price drops but HWM stays high
        vm.warp(block.timestamp + 1 days);
        _settlementParams.toBatchId = vault.currentBatch();
        // After creating a new series, we need to provide newTotalAssets for all series
        // Check how many series exist now
        uint32 _shareSeriesIdDrop = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdDrop = vault.lastConsolidatedSeriesId(1);
        uint32 _numSeriesDrop = _shareSeriesIdDrop - _lastConsolidatedSeriesIdDrop + 1;
        _settlementParams.newTotalAssets = new uint256[](_numSeriesDrop);
        _settlementParams.newTotalAssets[0] = 110 ether; // Lead series price dropped from 120 to 110
        if (_numSeriesDrop > 1) {
            _settlementParams.newTotalAssets[1] = 50 ether; // New series assets (from sync deposit)
        }
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // New deposit should go to new series (HWM > current price)
        uint32 _shareSeriesIdBeforeSync = vault.shareSeriesId(1);
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        // Verify new series was created
        uint32 _shareSeriesIdAfter = vault.shareSeriesId(1);
        assertEq(_shareSeriesIdAfter, _shareSeriesIdBeforeSync + 1, "New series should be created");

        // Verify shares are in the new series
        uint256 _sharesInNewSeries = vault.sharesOf(1, _shareSeriesIdAfter, mockUser_2);
        assertGt(_sharesInNewSeries, 0, "Shares should be in new series");
    }

    function test_syncDeposit_usesCorrectSeriesId_afterCreateNewSeries() public {
        // Set minUserBalance to 0 to avoid balance checks
        vault.setMinUserBalance(1, 0);

        // Test for race condition fix: series ID should be read after creation
        // Set up performance fee
        vm.prank(manager);
        vault.queuePerformanceFee(1, 2000);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setPerformanceFee(1);

        // Create scenario where new series is needed
        // First, make an async deposit request and settle it
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );

        // Roll forward and settle
        vm.warp(block.timestamp + 1 days);
        IAlephVaultSettlement.SettlementParams memory _initialSettlementParams2 = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1)
            )
        });
        _initialSettlementParams2.newTotalAssets[0] = 100 ether;
        _initialSettlementParams2.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _initialSettlementParams2.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_initialSettlementParams2);

        // Create gains to set HWM
        vm.warp(block.timestamp + 1 days);
        // Check current series count before creating settlement params
        uint32 _shareSeriesIdGains = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdGains = vault.lastConsolidatedSeriesId(1);
        uint32 _numSeriesGains = _shareSeriesIdGains - _lastConsolidatedSeriesIdGains + 1;
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](_numSeriesGains),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](_numSeriesGains)
            )
        });
        _settlementParams.newTotalAssets[0] = 120 ether;
        if (_numSeriesGains > 1) {
            // If there are multiple series, set assets for all of them
            for (uint32 i = 1; i < _numSeriesGains; i++) {
                _settlementParams.newTotalAssets[i] = 0; // Other series have no assets yet
            }
        }
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // Price drops
        vm.warp(block.timestamp + 1 days);
        _settlementParams.toBatchId = vault.currentBatch();
        // After creating a new series, we need to provide newTotalAssets for all series
        uint32 _shareSeriesIdDrop2 = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdDrop2 = vault.lastConsolidatedSeriesId(1);
        uint32 _numSeriesDrop2 = _shareSeriesIdDrop2 - _lastConsolidatedSeriesIdDrop2 + 1;
        _settlementParams.newTotalAssets = new uint256[](_numSeriesDrop2);
        _settlementParams.newTotalAssets[0] = 110 ether; // Lead series price dropped
        if (_numSeriesDrop2 > 1) {
            _settlementParams.newTotalAssets[1] = 50 ether; // New series assets (from sync deposit)
        }
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        uint32 _expectedSeriesId = vault.shareSeriesId(1) + 1;

        // Deposit should create new series and use correct ID
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        // Verify the series ID matches what was created
        uint32 _actualSeriesId = vault.shareSeriesId(1);
        assertEq(_actualSeriesId, _expectedSeriesId, "Series ID should match created series");
        assertGt(vault.sharesOf(1, _actualSeriesId, mockUser_2), 0, "Shares should be in correct series");
    }

    function test_syncDeposit_revertsWhenClassIdIsInvalid() public {
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 0, amount: 100 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_revertsWhenFlowIsPaused() public {
        // Pause deposit flow
        vm.prank(manager);
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_revertsWhenAmountIsZero() public {
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(IAlephVaultDeposit.InsufficientDeposit.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 0, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_revertsWhenAmountLessThanMinDepositAmount() public {
        vault.setMinDepositAmount(1, 100 ether);

        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultDeposit.DepositLessThanMinDepositAmount.selector, 100 ether));
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_revertsWhenAmountExceedsMaxDepositCap() public {
        vault.setMaxDepositCap(1, 200 ether);
        vault.setTotalAssets(0, 200 ether);

        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultDeposit.DepositExceedsMaxDepositCap.selector, 200 ether));
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_revertsWhenAuthSignatureIsInvalid() public {
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // Make invalid signature
        AuthLibrary.AuthSignature memory _invalidSig = authSignature_2;
        _invalidSig.expiryBlock = 0;

        vm.prank(mockUser_2);
        vm.expectRevert(AuthLibrary.AuthSignatureExpired.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: _invalidSig})
        );
    }

    function test_syncDeposit_setsLockInPeriod() public {
        vault.setLockInPeriod(1, 5);

        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        uint48 _currentBatch = vault.currentBatch();

        vm.prank(mockUser_2);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_2})
        );

        // Assert lock-in period is set
        assertEq(vault.userLockInPeriod(1, mockUser_2), _currentBatch + 5);
    }

    function test_syncDeposit_multipleUsers() public {
        // Set up multiple users
        underlyingToken.mint(mockUser_2, 1000 ether);
        underlyingToken.mint(mockUser_1, 1000 ether);

        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        uint256 _amount1 = 100 ether;
        uint256 _amount2 = 200 ether;

        // First sync deposit
        vm.prank(mockUser_2);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: _amount1, authSignature: authSignature_2})
        );

        // Second sync deposit (with updated totalAssets/totalShares)
        vm.prank(mockUser_1);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: _amount2, authSignature: authSignature_1})
        );

        // Assert both users have shares
        assertGt(_shares1, 0);
        assertGt(_shares2, 0);
        assertGt(vault.sharesOf(1, 0, mockUser_2), 0);
        assertGt(vault.sharesOf(1, 0, mockUser_1), 0);

        // Assert total assets increased
        assertEq(vault.totalAssetsPerSeries(1, 0), 100 ether + _amount1 + _amount2);
    }

    function test_isTotalAssetsValid_returnsTrueWhenValid() public view {
        assertTrue(vault.isTotalAssetsValid(1));
    }

    function test_isTotalAssetsValid_returnsFalseWhenExpired() public {
        // Get current batch and last valuation settle ID
        uint48 _currentBatch = vault.currentBatch();
        uint48 _lastValuationSettleId = vault.depositSettleId(); // Should be same as redeemSettleId after setup

        // Expire total assets (sets syncExpirationBatches to 0)
        vm.prank(manager);
        vault.queueSyncExpirationBatches(0);
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setSyncExpirationBatches();

        // If current batch > lastValuationSettleId, it should be false
        // If current batch == lastValuationSettleId, it should still be true (within window of 0)
        // So we need to advance time to make current batch > lastValuationSettleId
        if (_currentBatch <= _lastValuationSettleId) {
            // Advance to next batch
            vm.warp(block.timestamp + 1 days);
        }

        assertFalse(vault.isTotalAssetsValid(1));
    }

    function test_isTotalAssetsValid_returnsFalseWhenNoSettlement() public {
        // Create new vault without settlement
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();

        // Should be false before any settlement
        assertFalse(vault.isTotalAssetsValid(1));
    }

    function test_syncDeposit_consolidatesOutstandingSeries_whenHWMReached() public {
        // Set minUserBalance to 0 to avoid balance checks
        vault.setMinUserBalance(1, 0);

        // Set up performance fee
        vm.prank(manager);
        vault.queuePerformanceFee(1, 2000); // 20% performance fee
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setPerformanceFee(1);

        // Create scenario: HWM was above price, created new series via async, then HWM reached
        // First, create a new series by having HWM > price and making async deposit
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Settle to create new series
        vm.warp(block.timestamp + 1 days);
        uint32 _numSeriesBefore = vault.shareSeriesId(1) - vault.lastConsolidatedSeriesId(1) + 1;
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](_numSeriesBefore),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](_numSeriesBefore)
            )
        });
        _settlementParams.newTotalAssets[0] = vault.totalAssetsPerSeries(1, 0);
        if (_numSeriesBefore > 1) {
            _settlementParams.newTotalAssets[1] = 50 ether;
        }
        _settlementParams.authSignature = _getSettlementAuthSignature(
            AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), _settlementParams.newTotalAssets
        );
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        uint32 _shareSeriesIdBefore = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdBefore = vault.lastConsolidatedSeriesId(1);
        assertGt(_shareSeriesIdBefore, _lastConsolidatedSeriesIdBefore, "Should have outstanding series");

        // Now simulate HWM being reached (price catches up to HWM)
        // Set HWM to current price
        uint256 _currentPrice = vault.pricePerShare(1, 0);
        vault.setHighWaterMark(_currentPrice);

        // Next sync deposit should consolidate outstanding series and go to lead series
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 30 ether, authSignature: authSignature_2})
        );

        // Verify consolidation happened - outstanding series should be consolidated
        uint32 _shareSeriesIdAfter = vault.shareSeriesId(1);
        uint32 _lastConsolidatedSeriesIdAfter = vault.lastConsolidatedSeriesId(1);
        // After consolidation, shareSeriesId should equal lastConsolidatedSeriesId (or be 0)
        assertLe(_shareSeriesIdAfter, _lastConsolidatedSeriesIdAfter, "Series should be consolidated");

        // Verify shares are in lead series
        uint256 _sharesInLead = vault.sharesOf(1, 0, mockUser_2);
        assertGt(_sharesInLead, 0, "Shares should be in lead series after consolidation");
    }

    function test_syncDeposit_reusesExistingActiveSeries() public {
        // Set minUserBalance to 0 to avoid balance checks
        vault.setMinUserBalance(1, 0);

        // Set up performance fee (but don't advance time too much to keep sync valid)
        vm.prank(manager);
        vault.queuePerformanceFee(1, 2000); // 20% performance fee
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(manager);
        vault.setPerformanceFee(1);

        // Ensure sync is still valid by settling if needed
        if (!vault.isTotalAssetsValid(1)) {
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
        }

        // Create scenario: HWM > price, so first deposit creates new series
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // First sync deposit creates new series
        vm.prank(mockUser_1);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint32 _activeSeriesId = vault.shareSeriesId(1);
        assertGt(_activeSeriesId, 0, "Should have active series");

        // Second sync deposit in the same batch should reuse the same active series
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 30 ether, authSignature: authSignature_2})
        );

        // Verify same series ID (no new series created)
        uint32 _shareSeriesIdAfter = vault.shareSeriesId(1);
        assertEq(_shareSeriesIdAfter, _activeSeriesId, "Should reuse existing active series");

        // Verify both users have shares in the same series
        uint256 _shares1 = vault.sharesOf(1, _activeSeriesId, mockUser_1);
        uint256 _shares2 = vault.sharesOf(1, _activeSeriesId, mockUser_2);
        assertGt(_shares1, 0, "User 1 should have shares in active series");
        assertGt(_shares2, 0, "User 2 should have shares in active series");
    }

    function test_syncDeposit_eventIncludesAllParameters() public {
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        uint256 _depositAmount = 100 ether;
        uint48 _currentBatch = vault.currentBatch();
        uint32 _seriesId = vault.shareSeriesId(1);
        uint256 _totalAssetsBefore = vault.totalAssetsPerSeries(1, _seriesId);
        uint256 _totalSharesBefore = vault.totalSharesPerSeries(1, _seriesId);
        uint256 _expectedShares = ERC4626Math.previewDeposit(_depositAmount, _totalSharesBefore, _totalAssetsBefore);
        uint256 _expectedTotalAssets = _totalAssetsBefore + _depositAmount;
        uint256 _expectedTotalShares = _totalSharesBefore + _expectedShares;

        vm.prank(mockUser_2);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultDeposit.SyncDeposit(
            1, mockUser_2, _depositAmount, _expectedShares, _seriesId, _currentBatch, _expectedTotalAssets, _expectedTotalShares
        );
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: _depositAmount, authSignature: authSignature_2})
        );
    }

    function test_syncDeposit_expirationBoundaryExactBatch() public {
        // Test that sync works in the exact batch where expiration batches = 0
        vault.setMinUserBalance(1, 0); // Set to 0 to avoid balance checks

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
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // Should succeed in the same batch
        vm.prank(mockUser_2);
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );
        assertGt(_shares, 0, "Sync deposit should work in exact batch when expirationBatches = 0");
    }
}

