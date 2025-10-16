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
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
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
contract RequestSettleDepositTest is BaseTest {
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

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsZero() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up user 1 with 100 tokens
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // get settle deposit expectations
        SettleDepositExpectations memory _params = _getSettleDepositExpectations(false, 0, 0, _depositAmount, 0);

        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, new uint256[](1));

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // assert high water mark is 1
        assertEq(vault.highWaterMark(1, 0), _params.expectedPricePerShare);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsConstant() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // same price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(false, _newTotalAssets[0], _totalShares, _depositAmount, 0);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // assert high water mark is same
        assertEq(vault.highWaterMark(1, 0), vault.PRICE_DENOMINATOR());

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIncreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1200 ether;

        // set user balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // new price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256 _newPricePerShare = Math.ceilDiv(_newTotalAssets[0] * vault.PRICE_DENOMINATOR(), _totalShares);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(false, _newTotalAssets[0], _totalShares, _depositAmount, 0);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // // assert high water mark is new price per share
        // assertEq(vault.highWaterMark(1, 0), _newPricePerShare);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsDecreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 800 ether;

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // new price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(false, _newTotalAssets[0], _totalShares, _depositAmount, 0);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsZero_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set up user 1 with 100 tokens
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, new uint256[](1));

        // get settle deposit expectations
        SettleDepositExpectations memory _params = _getSettleDepositExpectations(false, 0, 0, _depositAmount, 0);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // assert fee is not accumulated
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _params.managementFeeShares);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), _params.performanceFeeShares);

        // assert high water mark is 1
        assertEq(vault.highWaterMark(1, 0), _params.expectedPricePerShare);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsConstant_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // same price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(true, _newTotalAssets[0], _totalShares, _depositAmount, 10);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 1, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 1, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssetsPerSeries(1, 1), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 1), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 1, mockUser_1), _params.newSharesToMint);

        // assert management fee is accumulated but performance fee is not
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _params.managementFeeShares);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), 0);

        // assert high water mark is same
        assertEq(vault.highWaterMark(1, 0), vault.PRICE_DENOMINATOR());

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIncreases_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1200 ether;

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // same price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(false, _newTotalAssets[0], _totalShares, _depositAmount, 10);
        uint256 _newPricePerShare = Math.ceilDiv(
            _newTotalAssets[0] * vault.PRICE_DENOMINATOR(),
            _totalShares + _params.managementFeeShares + _params.performanceFeeShares
        );

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(1, 0, _settleBatchId, _newPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 0, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 0, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 0), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _params.newSharesToMint);

        // assert management fee and performance fee are accumulated
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _params.managementFeeShares);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), _params.performanceFeeShares);

        // assert high water mark has increased
        assertEq(vault.highWaterMark(1, 0), _newPricePerShare);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsDecreases_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 800 ether;

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        uint48 _requestBatchId = vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({
                classId: 1, amount: _depositAmount, authSignature: authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // same price per share
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        SettleDepositExpectations memory _params =
            _getSettleDepositExpectations(true, _newTotalAssets[0], _totalShares, _depositAmount, 10);

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.NewSeriesCreated(1, 1, _settleBatchId);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 1, _requestBatchId, _depositAmount, _params.newSharesToMint);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(
            1, 1, 0, _settleBatchId, _depositAmount, _params.expectedTotalAssets, _params.expectedTotalShares
        );
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
        assertEq(vault.totalAssetsPerSeries(1, 1), _params.expectedTotalAssets);
        assertEq(vault.totalSharesPerSeries(1, 1), _params.expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(1, 1, mockUser_1), _params.newSharesToMint);

        // assert management fee is accumulated but performance fee is not
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _params.managementFeeShares);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), _params.performanceFeeShares);

        // assert high water mark has not changed
        assertEq(vault.highWaterMark(1, 0), vault.PRICE_DENOMINATOR());

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_multipleBatches_consolidation() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set up users with tokens
        underlyingToken.mint(address(mockUser_1), 1000 ether);
        underlyingToken.mint(address(mockUser_2), 1000 ether);

        // set vault allowance to 2000
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // request deposit with users
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

        // request deposit with users
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_2 = 500 ether;

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // first batch settle
        uint256[] memory _newTotalAssets = new uint256[](1);

        // expected shares to mint per user
        uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(500 ether, 0, 0);

        // get settlement auth signature
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // settle deposit
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
        assertEq(vault.totalAssetsPerSeries(1, 0), _newTotalAssets[0] + _totalDepositAmount_1 + _totalDepositAmount_2);
        assertEq(vault.totalSharesPerSeries(1, 0), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

        // assert users shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(1, 0, mockUser_2), _expectedSharesToMint_user2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request deposit with users
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_3 = 500 ether;

        // roll the block forward some batches later
        vm.warp(block.timestamp + 10 days);

        // vault manager did not make a profit
        _newTotalAssets[0] = 700 ether;
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256 _expectedManagementFeeShares = vault.getManagementFeeShares(_newTotalAssets[0], _totalShares, 11);
        _totalShares += _expectedManagementFeeShares;

        // expected shares to mint
        uint256 _expectedSharesToMint_3_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_3_user2 = ERC4626Math.previewDeposit(200 ether, 0, 0);

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
        assertEq(vault.totalAssetsPerSeries(1, 0), _newTotalAssets[0]);
        assertEq(vault.totalSharesPerSeries(1, 0), _totalShares);
        assertEq(vault.totalAssetsPerSeries(1, 1), _totalDepositAmount_3);
        assertEq(vault.totalSharesPerSeries(1, 1), _expectedSharesToMint_3_user1 + _expectedSharesToMint_3_user2);

        // assert users shares
        assertEq(vault.sharesOf(1, 1, mockUser_1), _expectedSharesToMint_3_user1);
        assertEq(vault.sharesOf(1, 1, mockUser_2), _expectedSharesToMint_3_user2);

        // assert fees are accumulated
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), _expectedManagementFeeShares);

        // roll the block forward some batches later
        vm.warp(block.timestamp + 10 days);

        // vault manager made a profit
        uint256[] memory _newTotalAssets_2 = new uint256[](2);
        _newTotalAssets_2[0] = 1050 ether; // 50% profit
        _newTotalAssets_2[1] = 750 ether; // 50% profit

        // settle deposit
        _settleBatchId = vault.currentBatch();
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets_2);
        vm.startPrank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets_2,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 0), _newTotalAssets_2[0] + _newTotalAssets_2[1], 5);
        assertGt(vault.totalSharesPerSeries(1, 0), _totalShares);

        // assert users shares
        assertGt(vault.sharesOf(1, 0, mockUser_1), _expectedSharesToMint_user1);
        assertGt(vault.sharesOf(1, 0, mockUser_2), _expectedSharesToMint_user2);
    }

    function test_requestDeposit_settleDeposit_multipleBatches_newSeriesAfterConsolidation() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(1, 200); // 2%
        vault.setPerformanceFee(1, 2000); // 20%

        // set last consolidated series id to 3
        vault.setLastConsolidatedSeriesId(3);
        vault.setHighWaterMark(11 * vault.PRICE_DENOMINATOR() / 10);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);

        // set up users with tokens
        underlyingToken.mint(address(mockUser_1), 1000 ether);
        underlyingToken.mint(address(mockUser_2), 1000 ether);

        // set vault allowance to 2000
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // request deposit with users
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

        // request deposit with users
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_2 = 500 ether;

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // first batch settle
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // expected shares to mint per user
        uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(500 ether, 0, 0);

        // get settlement auth signature
        uint48 _settleBatchId = vault.currentBatch();
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets);

        // settle deposit
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
        assertEq(vault.totalAssetsPerSeries(1, 4), _totalDepositAmount_1 + _totalDepositAmount_2);
        assertEq(vault.totalSharesPerSeries(1, 4), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

        // assert users shares
        assertEq(vault.sharesOf(1, 4, mockUser_1), _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(1, 4, mockUser_2), _expectedSharesToMint_user2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request deposit with users
        vm.prank(mockUser_1);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 300 ether, authSignature: authSignature_1})
        );
        vm.prank(mockUser_2);
        vault.requestDeposit(
            IAlephVaultDeposit.RequestDepositParams({classId: 1, amount: 200 ether, authSignature: authSignature_2})
        );
        uint256 _totalDepositAmount_3 = 500 ether;

        // roll the block forward some batches later
        vm.warp(block.timestamp + 10 days);

        // vault manager did not make a profit
        uint256[] memory _newTotalAssets_2 = new uint256[](2);
        _newTotalAssets_2[0] = 800 ether;
        _newTotalAssets_2[1] = 700 ether;

        // expected shares to mint
        uint256 _expectedSharesToMint_3_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_3_user2 = ERC4626Math.previewDeposit(200 ether, 0, 0);

        // settle deposit
        _settleBatchId = vault.currentBatch();
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets_2);
        vm.startPrank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets_2,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 5), _totalDepositAmount_3);
        assertEq(vault.totalSharesPerSeries(1, 5), _expectedSharesToMint_3_user1 + _expectedSharesToMint_3_user2);

        // assert users shares
        assertEq(vault.sharesOf(1, 5, mockUser_1), _expectedSharesToMint_3_user1);
        assertEq(vault.sharesOf(1, 5, mockUser_2), _expectedSharesToMint_3_user2);

        // roll the block forward some batches later
        vm.warp(block.timestamp + 10 days);

        // vault manager made a profit
        uint256[] memory _newTotalAssets_3 = new uint256[](3);
        _newTotalAssets_3[0] = 1500 ether; // 50% profit
        _newTotalAssets_3[1] = 1050 ether; // 50% profit
        _newTotalAssets_3[2] = 750 ether; // 50% profit

        // settle deposit
        _settleBatchId = vault.currentBatch();
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _settleBatchId, _newTotalAssets_3);
        vm.startPrank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _settleBatchId,
                newTotalAssets: _newTotalAssets_3,
                authSignature: _settlementAuthSignature
            })
        );
        vm.stopPrank();

        // assert total assets
        assertApproxEqAbs(
            vault.totalAssetsPerSeries(1, 0), _newTotalAssets_3[0] + _newTotalAssets_3[1] + _newTotalAssets_3[2], 5
        );

        // assert users shares
        assertGt(vault.sharesOf(1, 0, mockUser_1), _expectedSharesToMint_user1);
        assertGt(vault.sharesOf(1, 0, mockUser_2), _expectedSharesToMint_user2);
    }
}
