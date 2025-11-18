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

    function test_syncRedeem_clearsLockInPeriodWhenRedeemingAll() public {
        // Set minUserBalance to 0 so we can redeem all
        vault.setMinUserBalance(1, 0);

        vault.setLockInPeriod(1, 5);
        vault.setUserLockInPeriod(1, vault.currentBatch() + 5, mockUser_1);

        // Redeem all assets
        uint256 _totalAssets = vault.assetsPerClassOf(1, mockUser_1);
        underlyingToken.mint(address(vault), _totalAssets);

        vm.prank(mockUser_1);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: _totalAssets}));

        // Lock-in period should be cleared
        assertEq(vault.userLockInPeriod(1, mockUser_1), 0);
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
}

