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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract RequestRedeemTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease(address _user, uint256 _redeemShares) public {
        // redeem shares 0 will revert with InsufficientRedeem
        vm.assume(_redeemShares > 0);
        // shares to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_redeemShares < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));
        // don't use user as vault
        vm.assume(_user != address(vault));

        // get pending assets to redeem
        uint256 _amountToRedeemBefore = vault.totalAmountToRedeemOf(1, _user);

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up user with _redeemShares shares
        vault.setSharesOf(0, _user, _redeemShares);

        // request redeem
        vm.prank(_user);
        vault.requestRedeem(1, _redeemShares);

        // assert invariant
        assertLt(_amountToRedeemBefore, vault.totalAmountToRedeemOf(1, _user));
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
        uint256 _amountToRedeemBefore = vault.totalAmountToRedeemOf(1, _user);
        vault.setSharesOf(0, _user, 100 * uint256(type(uint96).max));

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users per batch
        for (uint8 i = 0; i < _batches; i++) {
            // roll the block forward to make batch available
            vm.warp(block.timestamp + 1 days + 1);

            // get total amount to redeem in batch
            uint256 _totalAmountToRedeemBefore = vault.totalAmountToRedeemOf(1, _user);

            // set up user with shares
            uint256 _redeemShares = uint256(keccak256(abi.encode(_redeemSeed, i))) % type(uint96).max;

            // request redeem
            vm.prank(_user);
            vault.requestRedeem(1, _redeemShares);

            // assert batch invariant
            assertLt(_totalAmountToRedeemBefore, vault.totalAmountToRedeemOf(1, _user));
        }

        // assert vault invariant
        assertLt(_amountToRedeemBefore, vault.totalAmountToRedeemOf(1, _user));
    }
}
