// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.25;
// /*
//   ______   __                      __
//  /      \ /  |                    /  |
// /$$$$$$  |$$ |  ______    ______  $$ |____
// $$ |__$$ |$$ | /      \  /      \ $$      \
// $$    $$ |$$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |
// $$$$$$$$ |$$ |$$    $$ |$$ |  $$ |$$ |  $$ |
// $$ |  $$ |$$ |$$$$$$$$/ $$ |__$$ |$$ |  $$ |
// $$ |  $$ |$$ |$$       |$$    $$/ $$ |  $$ |
// $$/   $$/ $$/  $$$$$$$/ $$$$$$$/  $$/   $$/
//                         $$ |
//                         $$ |
//                         $$/
// */

// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
// import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
// import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
// import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
// import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
// import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
// import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
// import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
// import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
// import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

// /**
//  * @author Othentic Labs LTD.
//  * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
//  */
// contract RequestSettleDepositRedeemTest is BaseTest {
//     function setUp() public override {
//         super.setUp();
//         _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
//         _unpauseVaultFlows();
//         _setAuthSignatures();
//     }

//     function test_requestSettleDeposit_requestSettleRedeem() public {
//         // roll the block forward to make batch available
//         vm.warp(block.timestamp + 1 days + 1);

//         // set up users with tokens
//         underlyingToken.mint(mockUser_1, 1000 ether);
//         underlyingToken.mint(mockUser_2, 1000 ether);

//         // set vault allowance
//         vm.prank(mockUser_1);
//         underlyingToken.approve(address(vault), 1000 ether);
//         vm.prank(mockUser_2);
//         underlyingToken.approve(address(vault), 1000 ether);

//         // requestdeposit
//         uint48 _requestBatchId_1 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 100 ether, authSignature: authSignature_1}));
//         vm.prank(mockUser_2);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_2}));
//         uint256 _totalDepositAmount = 300 ether;

//         // assert deposit requests
//         assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_1), 100 ether);
//         assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_1), 200 ether);
//         assertEq(vault.totalAmountToDepositAt(_requestBatchId_1), _totalDepositAmount);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // first batch to settle
//         uint256 _newTotalAssets = 0;

//         // expected shares to mint per user
//         uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(100 ether, 0, 0);
//         uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(200 ether, 0, 0);

//         // settle deposit
//         vm.startPrank(oracle);
//         vault.settleDeposit(_newTotalAssets);
//         vm.stopPrank();

//         // assert total assets and total shares
//         assertEq(vault.totalAssets(), _newTotalAssets + _totalDepositAmount);
//         assertEq(vault.totalShares(), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

//         // assert user shares are minted
//         assertEq(vault.sharesOf(mockUser_1), _expectedSharesToMint_user1);
//         assertEq(vault.sharesOf(mockUser_2), _expectedSharesToMint_user2);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // request redeem
//         uint48 _requestBatchId_2 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestRedeem(100 ether);
//         vm.prank(mockUser_2);
//         vault.requestRedeem(200 ether);
//         uint256 _totalRedeemShares = 300 ether;

//         // assert redeem requests
//         assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId_2), 100 ether);
//         assertEq(vault.redeemRequestOfAt(mockUser_2, _requestBatchId_2), 200 ether);

//         // assert user shares are burned
//         assertEq(vault.sharesOf(mockUser_1), 0);
//         assertEq(vault.sharesOf(mockUser_2), 0);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // vault makes a profit
//         _newTotalAssets = vault.totalAssets() + 50 ether;
//         uint256 _totalShares = vault.totalShares();
//         uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
//         uint256 _expectedManagementShares = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 2);
//         uint256 _expectedPerformanceShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
//         _totalShares += _expectedManagementShares + _expectedPerformanceShares;

//         // expected assets to withdraw per user
//         uint256 _expectedAssetsToWithdraw_user1 = ERC4626Math.previewRedeem(100 ether, _newTotalAssets, _totalShares);
//         uint256 _expectedAssetsToWithdraw_user2 = ERC4626Math.previewRedeem(200 ether, _newTotalAssets, _totalShares);
//         uint256 _expectedAssetsToWithdraw = _expectedAssetsToWithdraw_user1 + _expectedAssetsToWithdraw_user2;

//         // set vault balance
//         underlyingToken.mint(address(vault), _expectedAssetsToWithdraw);

//         // settle redeem
//         vm.startPrank(oracle);
//         vault.settleRedeem(_newTotalAssets);
//         vm.stopPrank();

//         // assert total assets and total shares
//         assertEq(vault.totalAssets(), _newTotalAssets - _expectedAssetsToWithdraw);
//         assertEq(vault.totalShares(), _totalShares - _totalRedeemShares);

//         // assert user assets are received
//         assertEq(underlyingToken.balanceOf(mockUser_1), 900 ether + _expectedAssetsToWithdraw_user1);
//         assertEq(underlyingToken.balanceOf(mockUser_2), 800 ether + _expectedAssetsToWithdraw_user2);

//         // assert fees are accumulated
//         assertEq(vault.sharesOf(vault.managementFeeRecipient()), _expectedManagementShares);
//         assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _expectedPerformanceShares);

//         // assert high water mark is new price per share
//         assertApproxEqAbs(vault.highWaterMark(), _newPricePerShare, 1);
//     }

//     function test_requestSettleDeposit_requestSettleDeposit_multipleBatches() public {
//         // roll the block forward to make batch available
//         vm.warp(block.timestamp + 1 days + 1);

//         // set up users with tokens
//         underlyingToken.mint(mockUser_1, 1000 ether);
//         underlyingToken.mint(mockUser_2, 1000 ether);

//         // set vault allowance
//         vm.prank(mockUser_1);
//         underlyingToken.approve(address(vault), 1000 ether);
//         vm.prank(mockUser_2);
//         underlyingToken.approve(address(vault), 1000 ether);

//         // requestdeposit
//         uint48 _requestBatchId_1 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 100 ether, authSignature: authSignature_1}));
//         vm.prank(mockUser_2);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_2}));
//         uint256 _totalDepositAmount_1 = 300 ether;

//         // assert deposit requests
//         assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_1), 100 ether);
//         assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_1), 200 ether);
//         assertEq(vault.totalAmountToDepositAt(_requestBatchId_1), _totalDepositAmount_1);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // requestdeposit
//         uint48 _requestBatchId_2 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 200 ether, authSignature: authSignature_1}));
//         vm.prank(mockUser_2);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 300 ether, authSignature: authSignature_2}));
//         uint256 _totalDepositAmount_2 = 500 ether;

//         // assert deposit requests
//         assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_2), 200 ether);
//         assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_2), 300 ether);
//         assertEq(vault.totalAmountToDepositAt(_requestBatchId_2), _totalDepositAmount_2);

//         // roll the block forward some batches
//         vm.warp(block.timestamp + 3 days);

//         // expected shares to mint per user
//         uint256 _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, 0, 0);
//         uint256 _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(500 ether, 0, 0);

//         // settle deposit
//         vm.startPrank(oracle);
//         vault.settleDeposit(0);
//         vm.stopPrank();

//         // assert total assets and total shares
//         assertEq(vault.totalAssets(), _totalDepositAmount_1 + _totalDepositAmount_2);
//         assertEq(vault.totalShares(), _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

//         // assert user shares are minted
//         assertEq(vault.sharesOf(mockUser_1), _expectedSharesToMint_user1);
//         assertEq(vault.sharesOf(mockUser_2), _expectedSharesToMint_user2);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // requestdeposit
//         uint48 _requestBatchId_3 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 300 ether, authSignature: authSignature_1}));
//         vm.prank(mockUser_2);
//         vault.requestDeposit(IERC7540Deposit.RequestDepositParams({amount: 400 ether, authSignature: authSignature_2}));
//         uint256 _totalDepositAmount_3 = 700 ether;

//         // assert deposit requests
//         assertEq(vault.depositRequestOfAt(mockUser_1, _requestBatchId_3), 300 ether);
//         assertEq(vault.depositRequestOfAt(mockUser_2, _requestBatchId_3), 400 ether);
//         assertEq(vault.totalAmountToDepositAt(_requestBatchId_3), _totalDepositAmount_3);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // request redeem
//         uint48 _requestBatchId_4 = vault.currentBatch();
//         vm.prank(mockUser_1);
//         vault.requestRedeem(300 ether);
//         vm.prank(mockUser_2);
//         vault.requestRedeem(400 ether);
//         uint256 _totalRedeemShares = 700 ether;

//         // assert redeem requests
//         assertEq(vault.redeemRequestOfAt(mockUser_1, _requestBatchId_4), 300 ether);
//         assertEq(vault.redeemRequestOfAt(mockUser_2, _requestBatchId_4), 400 ether);
//         assertEq(vault.totalSharesToRedeemAt(_requestBatchId_4), _totalRedeemShares);

//         // assert user shares are burned
//         assertEq(vault.sharesOf(mockUser_1), 0);
//         assertEq(vault.sharesOf(mockUser_2), 100 ether);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // vault makes a profit
//         uint256 _newTotalAssets = vault.totalAssets() + 50 ether;
//         uint256 _totalShares = vault.totalShares();
//         uint256 _newPricePerShare = _newTotalAssets * vault.PRICE_DENOMINATOR() / _totalShares;
//         uint256 _expectedManagementShares = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 3);
//         uint256 _expectedPerformanceShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
//         _totalShares += _expectedManagementShares + _expectedPerformanceShares;

//         // expected shares to mint per user
//         _expectedSharesToMint_user1 = ERC4626Math.previewDeposit(300 ether, _totalShares, _newTotalAssets);
//         _expectedSharesToMint_user2 = ERC4626Math.previewDeposit(400 ether, _totalShares, _newTotalAssets);

//         // settle deposit
//         vm.startPrank(oracle);
//         vault.settleDeposit(_newTotalAssets);
//         vm.stopPrank();

//         // assert total assets and total shares
//         assertEq(vault.totalAssets(), _newTotalAssets + _totalDepositAmount_3);
//         assertEq(vault.totalShares(), _totalShares + _expectedSharesToMint_user1 + _expectedSharesToMint_user2);

//         // assert user shares are minted
//         assertEq(vault.sharesOf(mockUser_1), _expectedSharesToMint_user1);
//         assertEq(vault.sharesOf(mockUser_2), _expectedSharesToMint_user2 + 100 ether);

//         // roll the block forward to next batch
//         vm.warp(block.timestamp + 1 days);

//         // vault does not make profit
//         _newTotalAssets = vault.totalAssets();
//         _totalShares = vault.totalShares();
//         uint256 _expectedManagementShares_2 = vault.getManagementFeeShares(_newTotalAssets, _totalShares, 1);
//         _totalShares += _expectedManagementShares_2;

//         // expected amount to withdraw per user
//         uint256 _expectedAssetsToWithdraw_user1 = ERC4626Math.previewRedeem(300 ether, _newTotalAssets, _totalShares);
//         uint256 _expectedAssetsToWithdraw_user2 = ERC4626Math.previewRedeem(400 ether, _newTotalAssets, _totalShares);
//         uint256 _expectedAssetsToWithdraw = _expectedAssetsToWithdraw_user1 + _expectedAssetsToWithdraw_user2;

//         // set vault balance
//         underlyingToken.mint(address(vault), _expectedAssetsToWithdraw);

//         // settle redeem
//         vm.startPrank(oracle);
//         vault.settleRedeem(_newTotalAssets);
//         vm.stopPrank();

//         // assert total assets and total shares
//         assertEq(vault.totalAssets(), _newTotalAssets - _expectedAssetsToWithdraw);
//         assertEq(vault.totalShares(), _totalShares - _totalRedeemShares);

//         // assert user assets are received
//         assertEq(underlyingToken.balanceOf(mockUser_1), 400 ether + _expectedAssetsToWithdraw_user1);
//         assertEq(underlyingToken.balanceOf(mockUser_2), 100 ether + _expectedAssetsToWithdraw_user2);

//         // assert fees are accumulated
//         assertEq(
//             vault.sharesOf(vault.managementFeeRecipient()), _expectedManagementShares + _expectedManagementShares_2
//         );
//         assertEq(vault.sharesOf(vault.performanceFeeRecipient()), _expectedPerformanceShares);

//         // assert high water mark is new price per share
//         assertApproxEqAbs(vault.highWaterMark(), _newPricePerShare, 1);
//     }
// }
