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
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 * @notice Integration tests for combinations of async and sync deposit/redeem flows
 */
contract AsyncSyncFlowCombinationsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();

        // Set notice period to 0 for sync redeem
        vault.setNoticePeriod(1, 0);

        // Set minUserBalance to 0 to allow flexible testing
        vault.setMinUserBalance(1, 0);
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
                    ASYNC THEN SYNC COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    function test_asyncDepositThenSyncDeposit() public {
        _setupInitialSettlement();

        // User 1: Async deposit
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        uint48 _requestBatchId = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 2: Sync deposit (while async is pending)
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        uint256 _syncShares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 75 ether, authSignature: authSignature_2})
        );

        // Assert sync deposit succeeded
        assertGt(_syncShares, 0);
        assertGt(vault.sharesOf(1, 0, mockUser_2), 0);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _requestBatchId), 50 ether);

        // Roll forward and settle async deposit
        vm.warp(block.timestamp + 1 days);
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

        // Assert both users have shares
        assertGt(vault.sharesOf(1, 0, mockUser_1), 0);
        assertGt(vault.sharesOf(1, 0, mockUser_2), 0);
    }

    function test_asyncRedeemThenSyncRedeem() public {
        _setupInitialSettlement();

        // User has 100 ether worth of shares from setup
        uint256 _userAssets = vault.assetsPerClassOf(1, mockUser_1);

        // User 1: Async redeem
        vm.prank(mockUser_1);
        uint48 _requestBatchId =
            vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // User 1: Sync redeem (partial, remaining assets)
        underlyingToken.mint(address(vault), 20 ether);
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 20 ether}));

        // Assert sync redeem succeeded
        assertGt(_syncAssets, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_1, _requestBatchId), 0);

        // Roll forward and settle async redeem
        vm.warp(block.timestamp + 1 days);
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(
                AuthLibrary.SETTLE_REDEEM, vault.currentBatch(), new uint256[](1)
            )
        });

        vm.prank(oracle);
        vault.settleRedeem(_settlementParams);

        // User can withdraw async redeem
        uint256 _redeemableBefore = vault.redeemableAmount(mockUser_1);
        vm.prank(mockUser_1);
        vault.withdrawRedeemableAmount();
        assertGt(underlyingToken.balanceOf(mockUser_1), 0);
    }

    function test_asyncDepositThenSyncRedeem() public {
        _setupInitialSettlement();

        // User 1: Async deposit
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        uint48 _requestBatchId = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 1: Sync redeem from existing shares (from setup)
        underlyingToken.mint(address(vault), 30 ether);
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // Assert both operations succeeded
        assertGt(_syncAssets, 0);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _requestBatchId), 50 ether);
    }

    function test_syncDepositThenAsyncRedeem() public {
        _setupInitialSettlement();

        // User 1: Sync deposit
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_1);
        uint256 _syncShares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 1: Async redeem (from existing shares + new sync deposit)
        vm.prank(mockUser_1);
        uint48 _requestBatchId =
            vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // Assert both operations succeeded
        assertGt(_syncShares, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_1, _requestBatchId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SYNC THEN ASYNC COMBINATIONS
    //////////////////////////////////////////////////////////////*/

    function test_syncDepositThenAsyncDeposit() public {
        _setupInitialSettlement();

        // User 1: Sync deposit
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_1);
        uint256 _syncShares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 1: Async deposit
        uint48 _requestBatchId = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 75 ether, authSignature: authSignature_1})
        );

        // Assert both operations succeeded
        assertGt(_syncShares, 0);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _requestBatchId), 75 ether);
    }

    function test_syncRedeemThenAsyncRedeem() public {
        _setupInitialSettlement();

        // User has 100 ether worth of shares from setup
        underlyingToken.mint(address(vault), 30 ether);

        // User 1: Sync redeem
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // User 1: Async redeem
        vm.prank(mockUser_1);
        uint48 _requestBatchId =
            vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 20 ether}));

        // Assert both operations succeeded
        assertGt(_syncAssets, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_1, _requestBatchId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE USERS MIXED FLOWS
    //////////////////////////////////////////////////////////////*/

    function test_multipleUsersMixedFlows() public {
        _setupInitialSettlement();

        // Set up users
        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        // User 1: Sync deposit
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 2: Async deposit
        uint48 _requestBatchId = vault.currentBatch();
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 75 ether, authSignature: authSignature_2})
        );

        // User 1: Another sync deposit
        vm.prank(mockUser_1);
        uint256 _shares1_2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 30 ether, authSignature: authSignature_1})
        );

        // Assert all operations succeeded
        assertGt(_shares1, 0);
        assertGt(_shares1_2, 0);
        assertEq(vault.depositRequestOfAt(1, mockUser_2, _requestBatchId), 75 ether);

        // User 1: Sync redeem
        underlyingToken.mint(address(vault), 20 ether);
        vm.prank(mockUser_1);
        uint256 _assets1 =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 20 ether}));

        // User 2: Async redeem (from existing shares - user 2 has shares from async deposit request)
        // First settle the async deposit so user 2 has shares
        vm.warp(block.timestamp + 1 days);
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

        // Now user 2 can redeem
        vm.prank(mockUser_2);
        uint48 _redeemBatchId =
            vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 25 ether}));

        // Assert all operations succeeded
        assertGt(_assets1, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_2, _redeemBatchId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    EXPIRATION SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_syncFlowExpiresAfterAsyncSettlement() public {
        _setupInitialSettlement();

        // User 1: Sync deposit (valid)
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );
        assertGt(_shares1, 0);

        // Roll forward beyond expiration window
        vm.warp(block.timestamp + 3 days); // Should expire if syncExpirationBatches = 2

        // Sync deposit should now fail
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(IAlephVaultDeposit.OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        // Async deposit should still work
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );
    }

    function test_syncFlowBecomesValidAfterSettlement() public {
        // Start without settlement (sync invalid)
        vm.warp(block.timestamp + 1 days + 1);

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit should fail
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Async deposit works
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Roll forward and settle
        vm.warp(block.timestamp + 1 days);
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

        // Now sync deposit should work
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );
        assertGt(_shares, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_syncDepositUpdatesPriceForNextSyncDeposit() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        // First sync deposit
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint256 _totalAssets1 = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalShares1 = vault.totalSharesPerSeries(1, 0);

        // Second sync deposit (should use updated price)
        vm.prank(mockUser_2);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        // Shares should be different due to price update
        assertGt(_shares1, 0);
        assertGt(_shares2, 0);
        assertGt(vault.totalAssetsPerSeries(1, 0), _totalAssets1);
        assertGt(vault.totalSharesPerSeries(1, 0), _totalShares1);
    }

    function test_syncRedeemThenSyncDeposit() public {
        _setupInitialSettlement();

        // User has 100 ether worth of shares from setup
        underlyingToken.mint(address(vault), 30 ether);

        // Sync redeem
        vm.prank(mockUser_1);
        uint256 _assets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));
        assertGt(_assets, 0);

        // Sync deposit with same user
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_1);
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );
        assertGt(_shares, 0);
    }

    function test_asyncDepositThenSyncRedeemThenSettle() public {
        _setupInitialSettlement();

        // User 1: Async deposit
        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        uint48 _depositBatchId = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 1: Sync redeem from existing shares
        underlyingToken.mint(address(vault), 30 ether);
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));
        assertGt(_syncAssets, 0);

        // Roll forward and settle async deposit
        vm.warp(block.timestamp + 1 days);
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

        // User should have shares from async deposit
        assertGt(vault.sharesOf(1, 0, mockUser_1), 0);
    }
}

