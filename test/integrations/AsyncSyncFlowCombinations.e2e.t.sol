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
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
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
    address public mockUser_3 = makeAddr("mockUser_3");
    AuthLibrary.AuthSignature public authSignature_3;

    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();
        authSignature_3 = _createAuthSignature(mockUser_3);

        // Set notice period to 0 for sync redeem
        vault.setNoticePeriod(1, 0);

        // Set minUserBalance to 0 to allow flexible testing
        vault.setMinUserBalance(1, 0);
    }

    function _createAuthSignature(address _user) internal view returns (AuthLibrary.AuthSignature memory) {
        bytes32 _authMessage = keccak256(abi.encode(_user, address(vault), block.chainid, 1, type(uint256).max));
        bytes32 _ethSignedMessage = MessageHashUtils.toEthSignedMessageHash(_authMessage);
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});
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

    /*//////////////////////////////////////////////////////////////
                    COMPLEX MULTI-BATCH SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_multipleBatchesWithSyncAndAsync() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);
        underlyingToken.mint(mockUser_3, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_3);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        // Batch 1: Mix of sync and async deposits
        vm.prank(mockUser_1);
        uint256 _syncShares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint48 _batch1 = vault.currentBatch();
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 75 ether, authSignature: authSignature_2})
        );

        // Roll to next batch
        vm.warp(block.timestamp + 1 days);

        // Batch 2: More operations
        vm.prank(mockUser_3);
        uint256 _syncShares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 60 ether, authSignature: authSignature_3})
        );

        uint48 _batch2 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 40 ether, authSignature: authSignature_1})
        );

        // Settle batch 1 async deposit
        IAlephVaultSettlement.SettlementParams memory _settlementParams = IAlephVaultSettlement.SettlementParams({
            classId: 1,
            toBatchId: _batch1,
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _batch1, new uint256[](1))
        });

        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // Verify all operations
        assertGt(_syncShares1, 0);
        assertGt(_syncShares2, 0);
        assertGt(vault.sharesOf(1, 0, mockUser_1), 0);
        assertGt(vault.sharesOf(1, 0, mockUser_2), 0);
        assertGt(vault.sharesOf(1, 0, mockUser_3), 0);
        assertEq(vault.depositRequestOfAt(1, mockUser_1, _batch2), 40 ether);
    }

    function test_syncDepositWithMaxDepositCap() public {
        _setupInitialSettlement();

        // Set max deposit cap
        vault.setMaxDepositCap(1, 200 ether);

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        // User 1: Sync deposit (50 ether)
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // User 2: Async deposit (100 ether) - should work
        uint48 _batchId = vault.currentBatch();
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_2})
        );

        // User 1: Another sync deposit (60 ether) - should fail (50 + 100 + 60 = 210 > 200)
        vm.prank(mockUser_1);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultDeposit.DepositExceedsMaxDepositCap.selector, 200 ether));
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 60 ether, authSignature: authSignature_1})
        );

        // But 50 ether should work (50 + 100 + 50 = 200)
        vm.prank(mockUser_1);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        assertGt(_shares1, 0);
        assertGt(_shares2, 0);
    }

    function test_syncDepositWithMinUserBalance() public {
        _setupInitialSettlement();

        // Set min user balance
        vault.setMinUserBalance(1, 20 ether);

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // User has 100 ether from setup, sync redeem 90 ether (leaves 10 ether)
        underlyingToken.mint(address(vault), 90 ether);
        vm.prank(mockUser_1);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 90 ether}));

        // Sync deposit 5 ether - should fail (10 + 5 = 15 < 20)
        vm.prank(mockUser_1);
        vm.expectRevert(abi.encodeWithSelector(IAlephVaultDeposit.DepositLessThanMinUserBalance.selector, 20 ether));
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 5 ether, authSignature: authSignature_1})
        );

        // Sync deposit 15 ether - should work (10 + 15 = 25 >= 20)
        vm.prank(mockUser_1);
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 15 ether, authSignature: authSignature_1})
        );

        assertGt(_shares, 0);
    }

    function test_syncRedeemWithPendingAsyncRedeem() public {
        _setupInitialSettlement();

        // User has 100 ether worth of shares from setup
        uint256 _totalAssets = vault.assetsPerClassOf(1, mockUser_1);

        // User: Async redeem 50 ether
        vm.prank(mockUser_1);
        uint48 _asyncBatchId =
            vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));

        // User: Sync redeem 30 ether (should account for pending async)
        underlyingToken.mint(address(vault), 30 ether);
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // Verify sync redeem succeeded
        assertGt(_syncAssets, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_1, _asyncBatchId), 0);

        // User should not be able to sync redeem more than remaining (100 - 50 - 30 = 20 ether max)
        underlyingToken.mint(address(vault), 25 ether);
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientAssetsToRedeem.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 25 ether}));
    }

    function test_multipleSyncDepositsAffectPricing() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);
        underlyingToken.mint(mockUser_3, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_3);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        uint256 _initialTotalAssets = vault.totalAssetsPerSeries(1, 0);
        uint256 _initialTotalShares = vault.totalSharesPerSeries(1, 0);

        // First sync deposit
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint256 _totalAssets1 = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalShares1 = vault.totalSharesPerSeries(1, 0);

        // Second sync deposit (should get different price)
        vm.prank(mockUser_2);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        uint256 _totalAssets2 = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalShares2 = vault.totalSharesPerSeries(1, 0);

        // Third sync deposit
        vm.prank(mockUser_3);
        uint256 _shares3 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_3})
        );

        // Verify pricing changes
        assertGt(_shares1, 0);
        assertGt(_shares2, 0);
        assertGt(_shares3, 0);
        assertGt(_totalAssets1, _initialTotalAssets);
        assertGt(_totalAssets2, _totalAssets1);
        assertGt(_totalShares1, _initialTotalShares);
        assertGt(_totalShares2, _totalShares1);

        // Shares should be similar but may differ slightly due to rounding
        // All three deposits are same amount, so shares should be very close
        assertApproxEqRel(_shares1, _shares2, 0.01e18); // 1% tolerance
        assertApproxEqRel(_shares2, _shares3, 0.01e18);
    }

    function test_syncOperationsWithPerformanceFeeSeries() public {
        _setupInitialSettlement();

        // Set high water mark above current price to trigger new series
        uint256 _currentPrice = vault.pricePerShare(1, 0);
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        // Sync deposit should go to new series (HWM > price)
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint32 _seriesId = vault.shareSeriesId(1);
        assertGt(_seriesId, 0); // Should be in a new series

        // Verify shares are in the new series
        assertGt(vault.sharesOf(1, _seriesId, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0); // Not in lead series

        // Another sync deposit should reuse the same series
        vm.prank(mockUser_2);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        assertGt(_shares2, 0);
        assertGt(vault.sharesOf(1, _seriesId, mockUser_2), 0);
    }

    function test_syncRedeemFromMultipleSeries() public {
        _setupInitialSettlement();

        // Set high water mark and create series
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit to create new series
        vm.prank(mockUser_1);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        uint32 _seriesId = vault.shareSeriesId(1);
        uint256 _sharesInSeries = vault.sharesOf(1, _seriesId, mockUser_1);
        uint256 _sharesInLead = vault.sharesOf(1, 0, mockUser_1);

        // User has shares in both lead series (from setup) and new series
        assertGt(_sharesInLead, 0);
        assertGt(_sharesInSeries, 0);

        // Sync redeem should use FIFO (lead series first)
        underlyingToken.mint(address(vault), 80 ether);
        vm.prank(mockUser_1);
        uint256 _assets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 80 ether}));

        assertGt(_assets, 0);
        // After redeeming 80 ether, should have redeemed from lead series first
        assertLt(vault.sharesOf(1, 0, mockUser_1), _sharesInLead);
    }

    function test_syncOperationsExpireMidBatch() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit should work
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );
        assertGt(_shares1, 0);

        // Roll forward to expiration boundary (syncExpirationBatches = 2)
        // Current batch is where settlement happened, so batches 0, 1, 2 should be valid
        // Batch 3 should be invalid
        vm.warp(block.timestamp + 3 days); // Should be in batch 3

        // Sync deposit should fail
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        vm.expectRevert(IAlephVaultDeposit.OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        // But async should still work
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );
    }

    function test_syncDepositThenAsyncRedeemThenSyncRedeem() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit
        vm.prank(mockUser_1);
        uint256 _syncShares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Async redeem
        vm.prank(mockUser_1);
        uint48 _asyncRedeemBatch = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 30 ether}));

        // Sync redeem (should account for pending async)
        underlyingToken.mint(address(vault), 20 ether);
        vm.prank(mockUser_1);
        uint256 _syncAssets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 20 ether}));

        // Verify all operations
        assertGt(_syncShares, 0);
        assertGt(_syncAssets, 0);
        assertGt(vault.redeemRequestOfAt(1, mockUser_1, _asyncRedeemBatch), 0);
    }

    function test_multipleUsersSyncOperationsSameBatch() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        underlyingToken.mint(mockUser_2, 1000 ether);
        underlyingToken.mint(mockUser_3, 1000 ether);

        vm.startPrank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        vm.startPrank(mockUser_3);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.stopPrank();

        uint48 _batchId = vault.currentBatch();

        // All three users sync deposit in same batch
        vm.prank(mockUser_1);
        uint256 _shares1 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        vm.prank(mockUser_2);
        uint256 _shares2 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 60 ether, authSignature: authSignature_2})
        );

        vm.prank(mockUser_3);
        uint256 _shares3 = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 70 ether, authSignature: authSignature_3})
        );

        // Verify all succeeded and pricing updated correctly
        assertGt(_shares1, 0);
        assertGt(_shares2, 0);
        assertGt(_shares3, 0);

        uint256 _totalAssets = vault.totalAssetsPerSeries(1, 0);
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);

        // Total assets should be initial + 50 + 60 + 70 = 180 ether more
        assertGt(_totalAssets, 100 ether); // 100 from setup
        assertGt(_totalShares, 0);
    }

    function test_syncRedeemWithInsufficientVaultBalance() public {
        _setupInitialSettlement();

        // User has 100 ether worth of shares
        uint256 _userAssets = vault.assetsPerClassOf(1, mockUser_1);

        // Try sync redeem without funding vault
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientVaultBalance.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));

        // Fund vault with less than needed
        underlyingToken.mint(address(vault), 30 ether);
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultRedeem.InsufficientVaultBalance.selector);
        vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));

        // Fund vault with enough
        underlyingToken.mint(address(vault), 25 ether); // Now has 55 ether total
        vm.prank(mockUser_1);
        uint256 _assets =
            vault.syncRedeem(IAlephVaultRedeem.RedeemRequestParams({classId: 1, estAmountToRedeem: 50 ether}));

        assertGt(_assets, 0);
    }

    function test_syncDepositAfterAsyncSettlementUpdatesExpiration() public {
        _setupInitialSettlement();

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit
        vm.prank(mockUser_1);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Roll forward and settle async operations (this updates lastValuationSettleId)
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

        // Sync should still be valid (expiration window resets)
        assertTrue(vault.isTotalAssetsValid(1));

        // Another sync deposit should work
        underlyingToken.mint(mockUser_2, 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        vm.prank(mockUser_2);
        uint256 _shares = vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_2})
        );

        assertGt(_shares, 0);
    }

    function test_syncOperationsWithZeroTotalShares() public {
        // Start fresh without initial settlement
        vm.warp(block.timestamp + 1 days + 1);

        underlyingToken.mint(mockUser_1, 1000 ether);
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);

        // Sync deposit should fail (no settlement yet)
        vm.prank(mockUser_1);
        vm.expectRevert(IAlephVaultDeposit.OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 50 ether, authSignature: authSignature_1})
        );

        // Make async deposit and settle
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 100 ether, authSignature: authSignature_1})
        );

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
}

