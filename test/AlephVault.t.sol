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

import {Test, console} from "forge-std/Test.sol";
import {AlephVault} from "../src/AlephVault.sol";
import {IAlephVault} from "../src/interfaces/IAlephVault.sol";
import {ExposedVault} from "./exposes/ExposedVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TestToken} from "./exposes/TestToken.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {IERC7540Redeem} from "../src/interfaces/IERC7540Redeem.sol";
import {IAlephVaultFactory} from "../src/interfaces/IAlephVaultFactory.sol";
import {PausableFlowsLibrary} from "../src/PausableFlowsLibrary.sol";
import {IAlephPausable} from "../src/interfaces/IAlephPausable.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultTest is Test {
    using SafeERC20 for IERC20;

    ExposedVault public vault;
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    uint48 public batchDuration = 1 days;
    address public manager = makeAddr("manager");
    address public operationsMultisig = makeAddr("operationsMultisig");
    address public operator = makeAddr("operator");
    address public custodian = makeAddr("custodian");
    address public oracle = makeAddr("oracle");
    address public guardian = makeAddr("guardian");

    TestToken public underlyingToken = new TestToken();

    function setUp() public {
        vm.chainId(560_048);
        underlyingToken.mint(user, 1000);
        underlyingToken.mint(user2, 1000);
        underlyingToken.mint(manager, 10_000);
        vault = new ExposedVault(
            IAlephVault.ConstructorParams({operationsMultisig: operationsMultisig, oracle: oracle, guardian: guardian})
        );
        vault.initialize(
            IAlephVault.InitializationParams({
                name: "test",
                manager: manager,
                underlyingToken: address(underlyingToken),
                custodian: custodian
            })
        );
        vm.startPrank(manager);
        vault.unpause(PausableFlowsLibrary.DEPOSIT_REQUEST_FLOW);
        vault.unpause(PausableFlowsLibrary.REDEEM_REQUEST_FLOW);
        vm.stopPrank();
    }

    function test_pauseAndUnpauseRedeemRequestFlow() public {
        assertEq(vault.isFlowPaused(PausableFlowsLibrary.REDEEM_REQUEST_FLOW), false);
        vm.prank(manager);
        vault.pause(PausableFlowsLibrary.REDEEM_REQUEST_FLOW);
        assertEq(vault.isFlowPaused(PausableFlowsLibrary.REDEEM_REQUEST_FLOW), true);
        vm.prank(user);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.requestRedeem(100);
    }

    function test_pauseAndUnpauseDepositRequestFlow() public {
        assertEq(vault.isFlowPaused(PausableFlowsLibrary.DEPOSIT_REQUEST_FLOW), false);
        vm.prank(manager);
        vault.pause(PausableFlowsLibrary.DEPOSIT_REQUEST_FLOW);
        assertEq(vault.isFlowPaused(PausableFlowsLibrary.DEPOSIT_REQUEST_FLOW), true);
        vm.prank(user);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.requestDeposit(100);
        vm.stopPrank();
    }

    function test_noBatchAvailable() public {
        vm.prank(user);
        uint256 _amount = 100;
        underlyingToken.approve(address(vault), _amount);
        vm.expectRevert(IERC7540Deposit.NoBatchAvailableForDeposit.selector);
        vault.requestDeposit(_amount);
    }

    function test_settleDeposit_oneBatch() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _currentBatchId = vault.currentBatch();
        assertEq(_currentBatchId, 1);
        uint256 _amount1 = 100;
        uint256 _amount2 = 300;
        userDepositRequest(user, _amount1);
        vm.startPrank(user);
        assertEq(vault.pendingDepositRequest(_currentBatchId), _amount1);
        assertEq(vault.sharesOf(user), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalShares(), 0);
        vm.stopPrank();
        userDepositRequest(user2, _amount2);
        vm.startPrank(user2);
        assertEq(vault.pendingDepositRequest(_currentBatchId), _amount2);
        assertEq(vault.sharesOf(user2), 0);
        assertEq(vault.sharesOf(user), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalShares(), 0);

        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _newcurrentBatchId = vault.currentBatch();
        assertEq(_newcurrentBatchId, 2);
        vm.stopPrank();
        vm.prank(oracle);
        vault.settleDeposit(0);
        assertEq(vault.sharesOf(user), _amount1);
        assertEq(vault.sharesOf(user2), _amount2);
        assertEq(vault.totalAssets(), _amount1 + _amount2);
        assertEq(vault.totalShares(), _amount1 + _amount2);

        // expect revert when calling pendingDepositRequest after settleDeposit
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettledForDeposit.selector);
        vault.pendingDepositRequest(_currentBatchId);
        vm.stopPrank();
    }

    function test_currentBatch() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _currentBatchId = vault.currentBatch();
        console.log("currentBatchId", _currentBatchId);
        assertEq(_currentBatchId, 1);
    }

    function test_requestMoreThanOneInTheSameBatchDeposit() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint256 _amount = 100;
        vm.startPrank(user);
        underlyingToken.approve(address(vault), _amount * 2);
        vault.requestDeposit(_amount);
        vm.expectRevert(IERC7540Deposit.OnlyOneRequestPerBatchAllowedForDeposit.selector);
        vault.requestDeposit(_amount);
        vm.stopPrank();
    }

    function test_requestDeposit() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        userDepositRequest(user, 100);
    }

    function test_settleDeposit_multipleBatches() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);

        uint256 amount1a = 100;
        uint256 amount1b = 200;
        userDepositRequest(user, amount1a);
        userDepositRequest(user2, amount1b);

        // --- Batch 2 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        uint256 amount2a = 300;
        uint256 amount2b = 400;
        userDepositRequest(user, amount2a);
        userDepositRequest(user2, amount2b);

        // --- Settle both batches at once ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch3 = vault.currentBatch();
        assertEq(batch3, 3);

        // For this test, we assume the oracle value is the sum of all deposits
        uint256 newTotalAssets = amount1a + amount1b + amount2a + amount2b;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // Check shares and stake
        assertEq(vault.sharesOf(user), amount1a + amount2a);
        assertEq(vault.sharesOf(user2), amount1b + amount2b);
        assertEq(vault.totalAssets(), newTotalAssets);
        assertEq(vault.totalShares(), newTotalAssets);

        // Check that pendingDepositRequest reverts for both batches
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettledForDeposit.selector);
        vault.pendingDepositRequest(batch1);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettledForDeposit.selector);
        vault.pendingDepositRequest(batch2);
        vm.stopPrank();
    }

    function test_settleDeposit_multipleSequential() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);

        uint256 amount1a = 100;
        uint256 amount1b = 200;
        userDepositRequest(user, amount1a);
        userDepositRequest(user2, amount1b);

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a + amount1b;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // Check shares and stake after batch 1
        assertEq(vault.sharesOf(user), amount1a);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);

        // --- Batch 2 ---
        uint256 amount2a = 300;
        uint256 amount2b = 400;
        userDepositRequest(user, amount2a);
        userDepositRequest(user2, amount2b);

        // Settle batch 2
        vm.warp(block.timestamp + batchDuration);
        uint48 batch3 = vault.currentBatch();
        assertEq(batch3, 3);

        // Oracle value after batch 2 deposits
        uint256 totalAssetsAfterBatch2 = amount1a + amount1b + amount2a + amount2b;
        uint256 _profit = 30;
        vm.prank(oracle);
        vault.settleDeposit(totalAssetsAfterBatch1 + _profit);
        console.log("vault.sharesOf(user)", vault.sharesOf(user));
        console.log("vault.sharesOf(user2)", vault.sharesOf(user2));
        console.log("vault.totalAssets()", vault.totalAssets());
        console.log("vault.totalShares()", vault.totalShares());
        assertEq(vault.totalAssets(), totalAssetsAfterBatch2 + _profit);
        assertEq(vault.totalShares(), vault.sharesOf(user) + vault.sharesOf(user2));

        // Check that pendingDepositRequest reverts for both batches
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettledForDeposit.selector);
        vault.pendingDepositRequest(batch1);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettledForDeposit.selector);
        vault.pendingDepositRequest(batch2);
        vm.stopPrank();
    }

    function test_requestRedeem_and_settleRedeem() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);
        uint256 balanceBeforeOfUser = underlyingToken.balanceOf(user);
        uint256 amount1a = 100;
        uint256 amount1b = 200;
        userDepositRequest(user, amount1a);
        userDepositRequest(user2, amount1b);

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a + amount1b;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // Check shares and stake after batch 1
        assertEq(vault.sharesOf(user), amount1a);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);

        vm.startPrank(user);
        vault.requestRedeem(amount1a);
        assertEq(vault.pendingRedeemRequest(batch2), amount1a);
        assertEq(vault.sharesOf(user), 0);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);
        assertEq(vault.pendingTotalAssetsToRedeem(), amount1a);
        assertEq(vault.pendingTotalSharesToRedeem(), amount1a);
        vm.stopPrank();

        vm.startPrank(manager);
        underlyingToken.approve(address(vault), amount1a);
        underlyingToken.transfer(address(vault), amount1a);
        vm.stopPrank();

        vm.warp(block.timestamp + batchDuration);
        vm.prank(oracle);
        vault.settleRedeem(totalAssetsAfterBatch1);
        assertEq(vault.sharesOf(user), 0);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1 - amount1a);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1 - amount1a);
        assertEq(vault.pendingTotalAssetsToRedeem(), 0);
        assertEq(vault.pendingTotalSharesToRedeem(), 0);
        assertEq(underlyingToken.balanceOf(user), balanceBeforeOfUser);
    }

    function test_requestRedeem_and_settleRedeem_noFundsInVault() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);
        uint256 balanceBeforeOfUser = underlyingToken.balanceOf(user);
        uint256 amount1a = 100;
        uint256 amount1b = 200;
        userDepositRequest(user, amount1a);
        userDepositRequest(user2, amount1b);

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a + amount1b;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // Check shares and stake after batch 1
        assertEq(vault.sharesOf(user), amount1a);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);

        vm.startPrank(user);
        vault.requestRedeem(amount1a);
        assertEq(vault.pendingRedeemRequest(batch2), amount1a);
        assertEq(vault.sharesOf(user), 0);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);
        assertEq(vault.pendingTotalAssetsToRedeem(), amount1a);
        assertEq(vault.pendingTotalSharesToRedeem(), amount1a);
        vm.stopPrank();

        vm.warp(block.timestamp + batchDuration);
        vm.startPrank(oracle);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(vault), 0, amount1a)
        );
        vault.settleRedeem(totalAssetsAfterBatch1);
        vm.stopPrank();
    }

    function test_requestRedeem_and_settleRedeem_partialRedeem() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);
        uint256 balanceBeforeOfUser = underlyingToken.balanceOf(user);
        uint256 amount1a = 100;
        uint256 amount1b = 200;
        userDepositRequest(user, amount1a);
        userDepositRequest(user2, amount1b);

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a + amount1b;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // Check shares and stake after batch 1
        assertEq(vault.sharesOf(user), amount1a);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);

        vm.startPrank(user);
        uint256 amountToRedeem = amount1a / 2;
        vault.requestRedeem(amountToRedeem);
        assertEq(vault.pendingRedeemRequest(batch2), amountToRedeem);
        assertEq(vault.sharesOf(user), amount1a - amountToRedeem);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1);
        assertEq(vault.pendingTotalAssetsToRedeem(), amountToRedeem);
        assertEq(vault.pendingTotalSharesToRedeem(), amountToRedeem);
        vm.stopPrank();

        vm.startPrank(manager);
        underlyingToken.approve(address(vault), amountToRedeem);
        underlyingToken.transfer(address(vault), amountToRedeem);
        vm.stopPrank();

        vm.warp(block.timestamp + batchDuration);
        vm.prank(oracle);
        vault.settleRedeem(totalAssetsAfterBatch1);
        assertEq(vault.sharesOf(user), amount1a - amountToRedeem);
        assertEq(vault.sharesOf(user2), amount1b);
        assertEq(vault.totalAssets(), totalAssetsAfterBatch1 - amountToRedeem);
        assertEq(vault.totalShares(), totalAssetsAfterBatch1 - amountToRedeem);
        assertEq(vault.pendingTotalAssetsToRedeem(), 0);
        assertEq(vault.pendingTotalSharesToRedeem(), 0);
        assertEq(underlyingToken.balanceOf(user), balanceBeforeOfUser - amountToRedeem);
    }

    function test_partialRedeemInSameBatch() public {
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = vault.currentBatch();
        assertEq(batch1, 1);
        uint256 balanceBeforeOfUser = underlyingToken.balanceOf(user);
        uint256 amount1a = 100;
        userDepositRequest(user, amount1a);

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = vault.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a;
        vm.prank(oracle);
        vault.settleDeposit(0);

        // User redeems part, then tries to redeem more in same batch
        vm.warp(block.timestamp + batchDuration);
        vm.startPrank(user);
        uint256 amountToRedeem = amount1a / 2;
        vault.requestRedeem(amountToRedeem);
        vm.expectRevert(IERC7540Redeem.OnlyOneRequestPerBatchAllowedForRedeem.selector);
        vault.requestRedeem(amountToRedeem);
        vm.stopPrank();
    }

    function test_setMetadataUri() public {
        vm.startPrank(manager);
        string memory _metadataUri = "metadataUri";
        vm.expectEmit(address(vault));
        emit IAlephVault.MetadataUriSet(_metadataUri);
        vault.setMetadataUri(_metadataUri);
        assertEq(vault.metadataUri(), _metadataUri);
        vm.stopPrank();
    }

    function userDepositRequest(address _user, uint256 _amount) private {
        vm.startPrank(_user);
        underlyingToken.approve(address(vault), _amount);
        vault.requestDeposit(_amount);
        vm.stopPrank();
    }
}
