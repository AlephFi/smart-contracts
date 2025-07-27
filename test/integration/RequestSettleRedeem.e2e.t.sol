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
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract RequestSettleRedeemTest is BaseTest {
    function setUp() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: 0,
            performanceFee: 0
        });
        _setUpNewAlephVault(defaultConstructorParams, _initializationParams);
        _unpauseVaultFlows();
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
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);
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
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);

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
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);
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
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        _totalShares += _expectedManagementShares;
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);

        // assert management fee is accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);

        // assert performance fee is not accumulated
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);
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

        // new price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        uint256 _expectedPerformanceShares = vault.getPerformanceFeeSharesAccumulated(
            _newTotalAssets, _totalShares, vault.highWaterMark(), Time.timestamp()
        );
        _totalShares += _expectedManagementShares + _expectedPerformanceShares;
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);

        // assert management fee is accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);

        // assert performance fee is accumulated
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), _expectedPerformanceShares);

        // assert high water mark is new price per share
        assertEq(vault.highWaterMark(), _newPricePerShare);
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
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        _totalShares += _expectedManagementShares;
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);

        // set vault balance
        underlyingToken.mint(address(vault), _assetsToWithdraw);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeemBatch(
            _requestBatchId, _assetsToWithdraw, _userShares, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.SettleRedeem(0, _settleBatchId, _userShares, _newTotalAssets);
        vault.settleRedeem(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets - _assetsToWithdraw);
        assertEq(vault.totalShares(), _totalShares - _userShares);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), _assetsToWithdraw);

        // assert management fee is accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);

        // assert performance fee is not accumulated
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);
    }
}
