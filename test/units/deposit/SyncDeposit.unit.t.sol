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

    function test_isTotalAssetsValid_externalFunctionCoverage() public view {
        // Test the external function directly for coverage
        // This ensures AlephVaultDeposit.isTotalAssetsValid is covered
        bool _result = vault.isTotalAssetsValid(1);
        // After setup, it should be valid
        assertTrue(_result);
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
            1,
            mockUser_2,
            _depositAmount,
            _expectedShares,
            _seriesId,
            _currentBatch,
            _expectedTotalAssets,
            _expectedTotalShares
        );
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_2
            })
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

