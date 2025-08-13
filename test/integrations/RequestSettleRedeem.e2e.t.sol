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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract RequestSettleRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: 0,
            performanceFee: 0,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });
        _setUpNewAlephVault(defaultConfigParams, _initializationParams);
        _unpauseVaultFlows();
        _setAuthSignatures();
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIsConstant() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1000 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 0);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIncreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1200 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // new price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = Math.ceilDiv(_newTotalAssets * vault.PRICE_DENOMINATOR(), _totalShares);
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 0);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);

        // assert high water mark is new price per share
        assertEq(vault.highWaterMark(), _newPricePerShare);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsDecreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 800 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 0);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIsConstant_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1000 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 10);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares + _params.managementFeeShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);

        // assert management fee is accumulated
        assertEq(vault.sharesOf(vault.managementFeeRecipient()), _params.managementFeeShares);

        // assert performance fee is not accumulated
        assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _params.performanceFeeShares);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIncreases_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1200 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = Math.ceilDiv(_newTotalAssets * vault.PRICE_DENOMINATOR(), _totalShares);
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 10);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_newPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares + _params.managementFeeShares + _params.performanceFeeShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);

        // assert management fee and performance fee are accumulated
        assertEq(vault.sharesOf(vault.managementFeeRecipient()), _params.managementFeeShares);
        assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _params.performanceFeeShares);

        // assert high water mark has increased
        assertEq(vault.highWaterMark(), _newPricePerShare);

        // assert redeem settle id is equal to current batch id
        assertEq(vault.redeemSettleId(), _settleBatchId);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsDecreases_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);
        vault.setLastFeePaidId(vault.currentBatch());

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 800 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user shares to 100
        uint256 _userShares = 100 ether;
        vault.setSharesOf(mockUser_1, _userShares);

        // request redeem
        uint48 _requestBatchId = vault.currentBatch();
        vm.startPrank(mockUser_1);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(mockUser_1, _userShares, _requestBatchId);
        uint48 _redeemBatchId = vault.requestRedeem(_userShares);
        vm.stopPrank();

        // assert redeem batch id
        assertEq(_redeemBatchId, _requestBatchId);

        // assert redeem request
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId), _userShares);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 0);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        SettleRedeemExpectations memory _params =
            _getSettleRedeemExpectations(_newTotalAssets, _totalShares, _userShares, 10);

        // set vault balance
        underlyingToken.mint(address(vault), _params.assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(
            _requestBatchId,
            _params.assetsToWithdraw,
            _userShares,
            _newTotalAssets,
            _totalShares + _params.managementFeeShares,
            _params.expectedPricePerShare
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(
            0,
            _settleBatchId,
            _userShares,
            _params.expectedTotalAssets,
            _params.expectedTotalShares,
            _params.expectedPricePerShare
        );
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _params.expectedTotalAssets);
        assertEq(vault.totalShares(), _params.expectedTotalShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _params.assetsToWithdraw);

        // assert management fee is accumulated
        assertEq(vault.sharesOf(vault.managementFeeRecipient()), _params.managementFeeShares);

        // assert performance fee is not accumulated
        assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _params.performanceFeeShares);
    }

    function test_requestSettleRedeem_multipleBatches() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set up users with shares
        vault.setSharesOf(mockUser_1, 1000 ether);
        vault.setSharesOf(mockUser_2, 1000 ether);

        // set vault balance
        underlyingToken.mint(address(vault), 2000 ether);

        // set total assets and total shares
        vault.setTotalAssets(2000 ether);
        vault.setTotalShares(2000 ether);

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // request redeem with users
        uint48 _requestBatchId_1 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestRedeem(100 ether);
        vm.prank(mockUser_2);
        vault.requestRedeem(200 ether);
        uint256 _totalRedeemShares_1 = 300 ether;

        // assert redeem requests
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId_1), 100 ether);
        assertEq(vault.redeemRequestOfAt(mockUser_2, _requestBatchId_1), 200 ether);
        assertEq(vault.totalSharesToRedeemAt(_requestBatchId_1), _totalRedeemShares_1);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 900 ether);
        assertEq(vault.sharesOf(mockUser_2), 800 ether);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request redeem with users
        uint48 _requestBatchId_2 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestRedeem(200 ether);
        vm.prank(mockUser_2);
        vault.requestRedeem(300 ether);
        uint256 _totalRedeemShares_2 = 500 ether;

        // assert redeem requests
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId_2), 200 ether);
        assertEq(vault.redeemRequestOfAt(mockUser_2, _requestBatchId_2), 300 ether);
        assertEq(vault.totalSharesToRedeemAt(_requestBatchId_2), _totalRedeemShares_2);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 700 ether);
        assertEq(vault.sharesOf(mockUser_2), 500 ether);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // vault makes profit
        uint256 _newTotalAssets = 2200 ether;
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _expectedManagementShares = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 3);
        uint256 _expectedPerformanceShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
        _totalShares += _expectedManagementShares + _expectedPerformanceShares;

        // expected assets to withdraw per user
        uint256 _expectedAssetsToWithdraw_user1 = ERC4626Math.previewRedeem(300 ether, _newTotalAssets, _totalShares);
        uint256 _expectedAssetsToWithdraw_user2 = ERC4626Math.previewRedeem(500 ether, _newTotalAssets, _totalShares);

        // settle redeem
        vm.startPrank(oracle);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(
            vault.totalAssets(), _newTotalAssets - _expectedAssetsToWithdraw_user1 - _expectedAssetsToWithdraw_user2
        );
        assertEq(vault.totalShares(), _totalShares - _totalRedeemShares_1 - _totalRedeemShares_2);

        // assert fees are accumulated
        assertEq(vault.sharesOf(vault.managementFeeRecipient()), _expectedManagementShares);
        assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _expectedPerformanceShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _expectedAssetsToWithdraw_user1);
        assertEq(underlyingToken.balanceOf(mockUser_2), _expectedAssetsToWithdraw_user2);

        // assert high water mark is new price per share
        assertEq(vault.highWaterMark(), _newPricePerShare);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request redeem with users
        uint48 _requestBatchId_3 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestRedeem(400 ether);
        vm.prank(mockUser_2);
        vault.requestRedeem(400 ether);
        uint256 _totalRedeemShares_3 = 800 ether;

        // assert redeem requests
        assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId_3), 400 ether);
        assertEq(vault.redeemRequestOfAt(mockUser_2, _requestBatchId_3), 400 ether);
        assertEq(vault.totalSharesToRedeemAt(_requestBatchId_3), _totalRedeemShares_3);

        // assert user shares are burned
        assertEq(vault.sharesOf(mockUser_1), 300 ether);
        assertEq(vault.sharesOf(mockUser_2), 100 ether);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // vault does not make profit
        _newTotalAssets = vault.totalAssets();
        _totalShares = vault.totalShares();
        uint256 _expectedManagementShares_2 = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 2);
        _totalShares += _expectedManagementShares_2;

        // expected assets to withdraw
        uint256 _expectedAssetsToWithdraw_3_user1 = ERC4626Math.previewRedeem(400 ether, _newTotalAssets, _totalShares);
        uint256 _expectedAssetsToWithdraw_3_user2 = ERC4626Math.previewRedeem(400 ether, _newTotalAssets, _totalShares);

        // settle redeem
        vm.startPrank(oracle);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(
            vault.totalAssets(), _newTotalAssets - _expectedAssetsToWithdraw_3_user1 - _expectedAssetsToWithdraw_3_user2
        );
        assertEq(vault.totalShares(), _totalShares - _totalRedeemShares_3);

        // assert user assets are received
        assertEq(
            underlyingToken.balanceOf(mockUser_1), _expectedAssetsToWithdraw_3_user1 + _expectedAssetsToWithdraw_user1
        );
        assertEq(
            underlyingToken.balanceOf(mockUser_2), _expectedAssetsToWithdraw_3_user2 + _expectedAssetsToWithdraw_user2
        );

        // assert fees are accumulated
        assertEq(
            vault.sharesOf(vault.managementFeeRecipient()), _expectedManagementShares + _expectedManagementShares_2
        );
        assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _expectedPerformanceShares);

        // assert high water mark hasn't updated
        assertEq(vault.highWaterMark(), _newPricePerShare);
    }
}
