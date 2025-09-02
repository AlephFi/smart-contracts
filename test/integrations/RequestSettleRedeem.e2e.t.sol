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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract RequestSettleRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: 0,
                performanceFee: 0,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap
            }),
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
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1000 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);

        // request redeem
        vm.startPrank(mockUser_1);
        vault.requestRedeem(1, 100 ether);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // set vault balance
        underlyingToken.mint(address(vault), 100 ether);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.RedeemRequestSliceSettled(1, mockUser_1, 1, 0, 100 ether, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.RedeemRequestSettled(1, mockUser_1, 1, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(1, 1, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(0, 2, 1);
        vault.settleRedeem(1, _newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 0), 900 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 900 ether);

        // assert user assets are received
        assertEq(underlyingToken.balanceOf(mockUser_1), 100 ether);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsIncreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = 1200 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);

        // request redeem
        vm.startPrank(mockUser_1);
        vault.requestRedeem(1, 50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(mockUser_1);
        vault.requestRedeem(1, 50 ether);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // set vault balance
        underlyingToken.mint(address(vault), 120 ether);

        // settle redeem
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.RedeemRequestSliceSettled(2, mockUser_1, 1, 0, 60 ether, 50 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.RedeemRequestSettled(2, mockUser_1, 1, 60 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeemBatch(2, 1, 60 ether);
        vm.expectEmit(true, true, true, true);
        emit IERC7540Settlement.SettleRedeem(0, 3, 1);
        vault.settleRedeem(1, _newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 0), 1080 ether, 1);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 0), 900 ether, 1);

        // assert user shares are burned
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);

        // assert user assets are received
        assertApproxEqAbs(underlyingToken.balanceOf(mockUser_1), 120 ether, 1);
    }

    function test_requestSettleRedeem_whenNewTotalAssetsDecreases() public {
        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set total assets and total shares
        vault.createNewSeries();
        vault.setTotalAssets(0, 1000 ether);
        vault.setTotalShares(0, 1000 ether);
        vault.setTotalAssets(1, 1000 ether);
        vault.setTotalShares(1, 1000 ether);
        uint256[] memory _newTotalAssets = new uint256[](2);
        _newTotalAssets[0] = 800 ether;
        _newTotalAssets[1] = 800 ether;

        // set user shares to 100
        vault.setSharesOf(0, mockUser_1, 100 ether);
        vault.setSharesOf(1, mockUser_1, 300 ether);

        // request redeem
        vm.startPrank(mockUser_1);
        vault.requestRedeem(1, 100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(mockUser_1);
        vault.requestRedeem(1, 150 ether);
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // set vault balance
        underlyingToken.mint(address(vault), 200 ether);

        // settle redeem
        vm.startPrank(oracle);

        vault.settleRedeem(1, _newTotalAssets);
        vm.stopPrank();

        // assert total assets and total shares
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 0), 720 ether, 1);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 0), 900 ether, 1);
        assertApproxEqAbs(vault.totalAssetsPerSeries(1, 1), 680 ether, 1);
        assertApproxEqAbs(vault.totalSharesPerSeries(1, 1), 850 ether, 1);

        // assert user shares are burned
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 1, mockUser_1), 150 ether);

        // assert user assets are received
        assertApproxEqAbs(underlyingToken.balanceOf(mockUser_1), 200 ether, 1);
    }
}
