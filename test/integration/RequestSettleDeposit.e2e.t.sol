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

import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract RequestSettleDepositTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: 0,
            performanceFee: 0
        });
        _setUpNewAlephVault(defaultConstructorParams, _initializationParams);
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

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // initial price per share
        uint256 _initialPricePerShare = vault.PRICE_DENOMINATOR();
        uint256 _initialSharesToMint = ERC4626Math.previewDeposit(_depositAmount, 0, 0);
        uint256 _expectedTotalAssets = _depositAmount;
        uint256 _expectedTotalShares = _initialSharesToMint;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(_requestBatchId, _depositAmount, _initialSharesToMint, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_initialPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _initialPricePerShare
        );
        vault.settleDeposit(0);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _initialSharesToMint);

        // assert high water mark is 1
        assertEq(vault.highWaterMark(), _initialPricePerShare);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsConstant() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1000 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        uint256 _expectedPricePerShare = vault.PRICE_DENOMINATOR();

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _expectedPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert high water mark is same
        assertEq(vault.highWaterMark(), _expectedPricePerShare);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIncreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 1200 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // new price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_newPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _newPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert high water mark is new price per share
        assertEq(vault.highWaterMark(), _newPricePerShare);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsDecreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 3 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(1000 ether);
        vault.setTotalShares(1000 ether);
        uint256 _newTotalAssets = 800 ether;

        // set high water mark
        vault.setHighWaterMark(vault.PRICE_DENOMINATOR());

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // new price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        uint256 _expectedPricePerShare = _expectedTotalAssets * vault.PRICE_DENOMINATOR() / _expectedTotalShares;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _expectedPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsZero_withFees() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set up user 1 with 100 tokens
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _settleBatchId = vault.currentBatch();

        // initial price per share
        uint256 _initialPricePerShare = vault.PRICE_DENOMINATOR();
        uint256 _initialSharesToMint = ERC4626Math.previewDeposit(_depositAmount, 0, 0);
        uint256 _expectedTotalAssets = _depositAmount;
        uint256 _expectedTotalShares = _initialSharesToMint;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(_requestBatchId, _depositAmount, _initialSharesToMint, 0, 0);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_initialPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _initialPricePerShare
        );
        vault.settleDeposit(0);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _initialSharesToMint);

        // assert fee is not accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), 0);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);

        // assert high water mark is 1
        assertEq(vault.highWaterMark(), _initialPricePerShare);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIsConstant_withFees() public {
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

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        _totalShares += _expectedManagementShares;
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        uint256 _expectedPricePerShare = _expectedTotalAssets * vault.PRICE_DENOMINATOR() / _expectedTotalShares;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _expectedPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert management fee is accumulated but performance fee is not
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);

        // assert high water mark is same
        assertEq(vault.highWaterMark(), vault.PRICE_DENOMINATOR());

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsIncreases_withFees() public {
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

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        uint256 _expectedPerformanceShares =
            vault.getPerformanceFeeSharesAccumulated(_newTotalAssets, _totalShares, vault.highWaterMark());
        _totalShares += _expectedManagementShares + _expectedPerformanceShares;
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        uint256 _expectedPricePerShare = _expectedTotalAssets * vault.PRICE_DENOMINATOR() / _expectedTotalShares;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(_newPricePerShare);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _expectedPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert management fee and performance fee are accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), _expectedPerformanceShares);

        // assert high water mark has increased
        assertEq(vault.highWaterMark(), _newPricePerShare);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_whenNewTotalAssetsDecreases_withFees() public {
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

        // set user 1 balance to 100
        uint256 _depositAmount = 100 ether;
        vm.startPrank(mockUser_1);
        underlyingToken.mint(address(mockUser_1), _depositAmount);

        // set vault allowance to 100
        underlyingToken.approve(address(vault), _depositAmount);

        // request deposit batch id
        uint48 _requestBatchId = vault.currentBatch();

        // request deposit
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.DepositRequest(mockUser_1, _depositAmount, _requestBatchId);
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: authSignature_1})
        );
        vm.stopPrank();

        // assert deposit batch id
        assertEq(_depositBatchId, _requestBatchId);

        // assert deposit request
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId), _depositAmount);

        // roll the block forward to some batches later
        vm.warp(block.timestamp + 10 days);
        uint48 _settleBatchId = vault.currentBatch();

        // same price per share
        uint256 _totalShares = vault.totalShares();
        uint256 _expectedManagementShares = vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 10);
        _totalShares += _expectedManagementShares;
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        uint256 _expectedPricePerShare = _expectedTotalAssets * vault.PRICE_DENOMINATOR() / _expectedTotalShares;

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDepositBatch(
            _requestBatchId, _depositAmount, _newSharesToMint, _newTotalAssets, _totalShares
        );
        vm.expectEmit(true, true, true, true);
        emit IERC7540Deposit.SettleDeposit(
            0, _settleBatchId, _depositAmount, _expectedTotalAssets, _expectedTotalShares, _expectedPricePerShare
        );
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _expectedTotalAssets);
        assertEq(vault.totalShares(), _expectedTotalShares);

        // assert user shares
        assertEq(vault.sharesOf(mockUser_1), _newSharesToMint);

        // assert management fee is accumulated but performance fee is not
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementShares);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), 0);

        // assert high water mark has not changed
        assertEq(vault.highWaterMark(), vault.PRICE_DENOMINATOR());

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _settleBatchId);

        // assert balance of custodian is 100
        assertEq(underlyingToken.balanceOf(address(custodian)), _depositAmount);
    }

    function test_requestDeposit_settleDeposit_multipleBatches() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set fees
        vault.setManagementFee(200); // 2%
        vault.setPerformanceFee(2000); // 20%

        // set up users with tokens
        underlyingToken.mint(address(mockUser_1), 1000 ether);
        underlyingToken.mint(address(mockUser_2), 1000 ether);

        // set vault allowance to 2000
        vm.prank(mockUser_1);
        underlyingToken.approve(address(vault), 1000 ether);
        vm.prank(mockUser_2);
        underlyingToken.approve(address(vault), 1000 ether);

        // request deposit with users
        uint48 _requestBatchId_1 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 100 ether, authSignature: authSignature_1}));
        vm.prank(mockUser_2);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_2}));
        uint256 _totalDepositAmount_1 = 300 ether;

        // assert deposit requests
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_1), 100 ether);
        assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_1), 200 ether);
        assertEq(vault.totalAmountToDepositAt(_requestBatchId_1), _totalDepositAmount_1);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request deposit with users
        uint48 _requestBatchId_2 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_1}));
        vm.prank(mockUser_2);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 300 ether, authSignature: authSignature_2}));
        uint256 _totalDepositAmount_2 = 500 ether;

        // assert deposit requests
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_2), 200 ether);
        assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_2), 300 ether);
        assertEq(vault.totalAmountToDepositAt(_requestBatchId_2), _totalDepositAmount_2);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // assert deposit requests
        uint256 _totalDepositAmount = _totalDepositAmount_1 + _totalDepositAmount_2;
        assertEq(vault.depositRequestOf(mockUser_1), 300 ether);
        assertEq(vault.depositRequestOf(mockUser_2), 500 ether);
        assertEq(vault.totalAmountToDeposit(), _totalDepositAmount);

        // first batch settle
        uint256 _newTotalAssets = 0;

        // expected shares to mint per user
        uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
        uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(500 ether, 0, 0);

        // settle deposit
        vm.startPrank(oracle);
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets + _totalDepositAmount);
        assertEq(vault.totalShares(), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

        // assert users shares
        assertEq(vault.sharesOf(mockUser_1), _expectedSharesToMint_user1);
        assertEq(vault.sharesOf(mockUser_2), _expectedSharesToMint_user2);

        // assert high water mark is 1
        assertEq(vault.highWaterMark(), vault.PRICE_DENOMINATOR());

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // request deposit with users
        uint48 _requestBatchId_3 = vault.currentBatch();
        vm.prank(mockUser_1);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 300 ether, authSignature: authSignature_1}));
        vm.prank(mockUser_2);
        vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_2}));
        uint256 _totalDepositAmount_3 = 500 ether;

        // assert deposit requests
        assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_3), 300 ether);
        assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_3), 200 ether);
        assertEq(vault.totalAmountToDepositAt(_requestBatchId_3), _totalDepositAmount_3);

        // roll the block forward some batches later
        vm.warp(block.timestamp + 10 days);

        // vault manager made a profit
        _newTotalAssets = 1000 ether;
        uint256 _totalShares = vault.totalShares();
        uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
        uint256 _expectedManagementFeeShares =
            vault.getManagementFeeSharesAccumulated(_newTotalAssets, _totalShares, 11);
        uint256 _expectedPerformanceFeeShares =
            vault.getPerformanceFeeSharesAccumulated(_newTotalAssets, _totalShares, vault.highWaterMark());
        _totalShares += _expectedManagementFeeShares + _expectedPerformanceFeeShares;

        // expected shares to mint
        uint256 _expectedSharesToMint_3_user1 = ERC4626Math.previewDeposit(300 ether, _totalShares, _newTotalAssets);
        uint256 _expectedSharesToMint_3_user2 = ERC4626Math.previewDeposit(200 ether, _totalShares, _newTotalAssets);

        // settle deposit
        vm.startPrank(oracle);
        vault.settleDeposit(_newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets + _totalDepositAmount_3);
        assertEq(vault.totalShares(), _totalShares + _expectedSharesToMint_3_user1 + _expectedSharesToMint_3_user2);

        // assert users shares
        assertEq(vault.sharesOf(mockUser_1), _expectedSharesToMint_user1 + _expectedSharesToMint_3_user1);
        assertEq(vault.sharesOf(mockUser_2), _expectedSharesToMint_user2 + _expectedSharesToMint_3_user2);

        // assert fees are accumulated
        assertEq(vault.sharesOf(vault.MANAGEMENT_FEE_RECIPIENT()), _expectedManagementFeeShares);
        assertEq(vault.sharesOf(vault.PERFORMANCE_FEE_RECIPIENT()), _expectedPerformanceFeeShares);

        // assert high water mark has increased
        assertEq(vault.highWaterMark(), _newPricePerShare);
    }
}
