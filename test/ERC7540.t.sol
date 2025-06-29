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
import {ERC7540} from "../src/ERC7540.sol";
import {IERC7540} from "../src/interfaces/IERC7540.sol";
import {ExposedERC7540} from "./exposes/ExposedERC7540.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TestToken} from "./exposes/TestToken.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

contract ERC7540Test is Test {
    using SafeERC20 for IERC20;

    ExposedERC7540 public erc7540;
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    uint48 public batchDuration = 2000;
    address public manager = makeAddr("manager");
    address public operationsMultisig = makeAddr("operationsMultisig");
    address public operator = makeAddr("operator");
    address public custodian = makeAddr("custodian");
    address public oracle = makeAddr("oracle");

    TestToken public erc20 = new TestToken();

    function setUp() public {
        erc20.mint(user, 1000);
        erc20.mint(user2, 1000);
        erc7540 = new ExposedERC7540();
        erc7540.initialize(
            IERC7540.InitializationParams({
                manager: manager,
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                erc20: address(erc20),
                custodian: custodian,
                batchDuration: batchDuration
            })
        );
    }

    function test_noBatchAvailable() public {
        vm.prank(user);
        uint256 _amount = 100;
        erc20.approve(address(erc7540), _amount);
        vm.expectRevert(IERC7540Deposit.NoBatchAvailable.selector);
        erc7540.requestDeposit(_amount);
    }

    function test_settleDeposit_oneBatch() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _currentBatchId = erc7540.currentBatch();
        assertEq(_currentBatchId, 1);
        uint256 _amount1 = 100;
        uint256 _amount2 = 300;
        vm.startPrank(user);
        erc20.approve(address(erc7540), _amount1);
        erc7540.requestDeposit(_amount1);
        assertEq(erc7540.pendingDepositRequest(_currentBatchId), _amount1);
        assertEq(erc7540.sharesOf(user), 0);
        assertEq(erc7540.totalAssets(), 0);
        assertEq(erc7540.totalShares(), 0);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20.approve(address(erc7540), _amount2);
        erc7540.requestDeposit(_amount2);
        assertEq(erc7540.pendingDepositRequest(_currentBatchId), _amount2);
        assertEq(erc7540.sharesOf(user2), 0);
        assertEq(erc7540.sharesOf(user), 0);
        assertEq(erc7540.totalAssets(), 0);
        assertEq(erc7540.totalShares(), 0);

        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _newcurrentBatchId = erc7540.currentBatch();
        assertEq(_newcurrentBatchId, 2);
        vm.stopPrank();
        vm.prank(oracle);
        erc7540.settleDeposit(0);
        assertEq(erc7540.sharesOf(user), _amount1);
        assertEq(erc7540.sharesOf(user2), _amount2);
        assertEq(erc7540.totalAssets(), _amount1 + _amount2);
        assertEq(erc7540.totalShares(), _amount1 + _amount2);

        // expect revert when calling pendingDepositRequest after settleDeposit
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettled.selector);
        erc7540.pendingDepositRequest(_currentBatchId);
        vm.stopPrank();
    }

    function test_currentBatch() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint48 _currentBatchId = erc7540.currentBatch();
        console.log("currentBatchId", _currentBatchId);
        assertEq(_currentBatchId, 1);
    }

    function test_requestMoreThanOneInTheSameBatchDeposit() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint256 _amount = 100;
        vm.startPrank(user);
        erc20.approve(address(erc7540), _amount * 2);
        erc7540.requestDeposit(_amount);
        vm.expectRevert(IERC7540Deposit.OnlyOneRequestPerBatchAllowed.selector);
        erc7540.requestDeposit(_amount);
        vm.stopPrank();
    }

    function test_requestDeposit() public {
        vm.warp(block.timestamp + batchDuration); // Move forward by one batch
        uint256 _amount = 100;
        vm.startPrank(user);
        erc20.approve(address(erc7540), _amount * 2);
        erc7540.requestDeposit(_amount);
        vm.stopPrank();
    }

    function test_settleDeposit_multipleBatches() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = erc7540.currentBatch();
        assertEq(batch1, 1);

        uint256 amount1a = 100;
        uint256 amount1b = 200;
        vm.startPrank(user);
        erc20.approve(address(erc7540), amount1a);
        erc7540.requestDeposit(amount1a);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20.approve(address(erc7540), amount1b);
        erc7540.requestDeposit(amount1b);
        vm.stopPrank();

        // --- Batch 2 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = erc7540.currentBatch();
        assertEq(batch2, 2);

        uint256 amount2a = 300;
        uint256 amount2b = 400;
        vm.startPrank(user);
        erc20.approve(address(erc7540), amount2a);
        erc7540.requestDeposit(amount2a);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20.approve(address(erc7540), amount2b);
        erc7540.requestDeposit(amount2b);
        vm.stopPrank();

        // --- Settle both batches at once ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch3 = erc7540.currentBatch();
        assertEq(batch3, 3);

        // For this test, we assume the oracle value is the sum of all deposits
        uint256 newTotalAssets = amount1a + amount1b + amount2a + amount2b;
        vm.prank(oracle);
        erc7540.settleDeposit(0);

        // Check shares and stake
        assertEq(erc7540.sharesOf(user), amount1a + amount2a);
        assertEq(erc7540.sharesOf(user2), amount1b + amount2b);
        assertEq(erc7540.totalAssets(), newTotalAssets);
        assertEq(erc7540.totalShares(), newTotalAssets);

        // Check that pendingDepositRequest reverts for both batches
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettled.selector);
        erc7540.pendingDepositRequest(batch1);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettled.selector);
        erc7540.pendingDepositRequest(batch2);
        vm.stopPrank();
    }

    function test_settleDeposit_multipleSequential() public {
        // --- Batch 1 ---
        vm.warp(block.timestamp + batchDuration);
        uint48 batch1 = erc7540.currentBatch();
        assertEq(batch1, 1);

        uint256 amount1a = 100;
        uint256 amount1b = 200;
        vm.startPrank(user);
        erc20.approve(address(erc7540), amount1a);
        erc7540.requestDeposit(amount1a);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20.approve(address(erc7540), amount1b);
        erc7540.requestDeposit(amount1b);
        vm.stopPrank();

        // Settle batch 1
        vm.warp(block.timestamp + batchDuration);
        uint48 batch2 = erc7540.currentBatch();
        assertEq(batch2, 2);

        // Oracle value after batch 1 deposits
        uint256 totalAssetsAfterBatch1 = amount1a + amount1b;
        vm.prank(oracle);
        erc7540.settleDeposit(0);

        // Check shares and stake after batch 1
        assertEq(erc7540.sharesOf(user), amount1a);
        assertEq(erc7540.sharesOf(user2), amount1b);
        assertEq(erc7540.totalAssets(), totalAssetsAfterBatch1);
        assertEq(erc7540.totalShares(), totalAssetsAfterBatch1);

        // --- Batch 2 ---
        uint256 amount2a = 300;
        uint256 amount2b = 400;
        vm.startPrank(user);
        erc20.approve(address(erc7540), amount2a);
        erc7540.requestDeposit(amount2a);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20.approve(address(erc7540), amount2b);
        erc7540.requestDeposit(amount2b);
        vm.stopPrank();

        // Settle batch 2
        vm.warp(block.timestamp + batchDuration);
        uint48 batch3 = erc7540.currentBatch();
        assertEq(batch3, 3);

        // Oracle value after batch 2 deposits
        uint256 totalAssetsAfterBatch2 = amount1a + amount1b + amount2a + amount2b;
        uint256 _profit = 30;
        vm.prank(oracle);
        erc7540.settleDeposit(totalAssetsAfterBatch1 + _profit);
        console.log("erc7540.sharesOf(user)", erc7540.sharesOf(user));
        console.log("erc7540.sharesOf(user2)", erc7540.sharesOf(user2));
        console.log("erc7540.totalAssets()", erc7540.totalAssets());
        console.log("erc7540.totalShares()", erc7540.totalShares());
        assertEq(erc7540.totalAssets(), totalAssetsAfterBatch2 + _profit);
        assertEq(erc7540.totalShares(), erc7540.sharesOf(user) + erc7540.sharesOf(user2));

        // Check that pendingDepositRequest reverts for both batches
        vm.startPrank(user);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettled.selector);
        erc7540.pendingDepositRequest(batch1);
        vm.expectRevert(IERC7540Deposit.BatchAlreadySettled.selector);
        erc7540.pendingDepositRequest(batch2);
        vm.stopPrank();
    }
}
