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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract RequestRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease(address _user, uint256 _redeemAmount) public {
        // redeem shares 0 will revert with InsufficientRedeem
        vm.assume(_redeemAmount > vault.minRedeemAmount(1));
        // shares to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_redeemAmount < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));
        // don't use user as vault
        vm.assume(_user != address(vault));

        // set user users share
        vault.setTotalAssets(0, _redeemAmount);
        vault.setTotalShares(0, _redeemAmount);
        vault.setSharesOf(0, _user, _redeemAmount);

        // get pending assets to redeem
        uint256 _amountToRedeemBefore = vault.redeemRequestOf(1, _user);

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // request redeem
        IAlephVaultRedeem.RedeemRequestParams memory params = IAlephVaultRedeem.RedeemRequestParams({
            classId: 1,
            shareRequests: new IAlephVaultRedeem.ShareRedeemRequest[](1)
        });
        params.shareRequests[0] = IAlephVaultRedeem.ShareRedeemRequest({seriesId: 0, shares: _redeemAmount});
        vm.prank(_user);
        vault.requestRedeem(params);

        // assert invariant
        assertLt(_amountToRedeemBefore, vault.redeemRequestOf(1, _user));
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease_multipleBatches(
        uint8 _batches,
        address _user,
        bytes32 _redeemSeed
    ) public {
        vm.assume(_batches > 0);
        vm.assume(_batches < 50);
        vm.assume(_user != address(0));
        vm.assume(_user != address(vault));

        // get pending assets to redeem
        uint256 _amountToRedeemBefore = vault.redeemRequestOf(1, _user);
        vault.setTotalAssets(0, uint256(type(uint96).max));
        vault.setTotalShares(0, uint256(type(uint96).max));
        vault.setSharesOf(0, _user, 100 * uint256(type(uint96).max));

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users per batch
        for (uint8 i = 0; i < _batches; i++) {
            // roll the block forward to make batch available
            vm.warp(block.timestamp + 1 days + 1);

            // get total amount to redeem in batch
            uint256 _totalAmountToRedeemBefore = vault.redeemRequestOf(1, _user);
            uint256 _redeemAmount = uint256(keccak256(abi.encode(_redeemSeed, i))) % uint256(type(uint96).max);

            // request redeem
            uint256 _remainingAmount = 100 * uint256(type(uint96).max) - (_redeemAmount + _totalAmountToRedeemBefore);
            if (_redeemAmount == 0) {
                break;
            }
            if (_redeemAmount < vault.minRedeemAmount(1) || _remainingAmount < vault.minUserBalance(1)) {
                continue;
            }
            IAlephVaultRedeem.RedeemRequestParams memory params = IAlephVaultRedeem.RedeemRequestParams({
                classId: 1,
                shareRequests: new IAlephVaultRedeem.ShareRedeemRequest[](1)
            });
            params.shareRequests[0] = IAlephVaultRedeem.ShareRedeemRequest({seriesId: 0, shares: _redeemAmount});
            vm.prank(_user);
            vault.requestRedeem(params);

            // assert batch invariant
            assertLt(_totalAmountToRedeemBefore, vault.redeemRequestOf(1, _user));
        }

        // assert vault invariant
        assertLt(_amountToRedeemBefore, vault.redeemRequestOf(1, _user));
    }
}
