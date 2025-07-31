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
    function setUp() public {
        _setUpNewAlephVault(defaultConstructorParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease(address _user, uint256 _redeemShares) public {
        // redeem shares 0 will revert with InsufficientRedeem
        vm.assume(_redeemShares > 0);
        // shares to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_redeemShares < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up user with _redeemShares shares
        vault.setSharesOf(_user, _redeemShares);
        uint256 _userSharesBefore = vault.sharesOf(_user);

        // request redeem
        vm.prank(_user);
        vault.requestRedeem(_redeemShares);

        // assert invariant
        assertLt(vault.totalSharesToRedeemAt(_batchId), vault.totalSharesToRedeemAt(vault.currentBatch()));
        assertGt(_userSharesBefore, vault.sharesOf(_user));
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease_multipleUsers(
        uint8 _iterations,
        bytes32 _redeemSeed
    ) public {
        vm.assume(_iterations > 0);

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users
        for (uint8 i = 0; i < _iterations; i++) {
            address _user = makeAddr(string.concat("user", vm.toString(i)));
            uint256 _redeemShares = uint256(keccak256(abi.encode(_redeemSeed, i))) % type(uint96).max;

            vault.setSharesOf(_user, _redeemShares);
            uint256 _userSharesBefore = vault.sharesOf(_user);

            // request redeem
            vm.prank(_user);
            vault.requestRedeem(_redeemShares);

            // assert invariant
            assertLt(vault.totalSharesToRedeemAt(_batchId), vault.totalSharesToRedeemAt(vault.currentBatch()));
            assertGt(_userSharesBefore, vault.sharesOf(_user));
        }

        // assert invariant
        assertLt(vault.totalSharesToRedeemAt(_batchId), vault.totalSharesToRedeem());
    }

    function test_requestRedeem_totalAmountToRedeemMustAlwaysIncrease_multipleUsers_multipleBatches(
        uint8 _iterations,
        uint8 _batches,
        bytes32 _redeemSeed
    ) public {
        vm.assume(_iterations > 0);
        vm.assume(_iterations < 50);
        vm.assume(_batches > 0);
        vm.assume(_batches < 50);

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up users per batch
        for (uint8 i = 0; i < _batches; i++) {
            // roll the block forward to make batch available
            vm.warp(block.timestamp + 1 days + 1);

            // get total shares to redeem in batch
            uint256 _totalSharesToRedeemBefore = vault.totalSharesToRedeemAt(vault.currentBatch());

            for (uint8 j = 0; j < _iterations; j++) {
                address _user = makeAddr(string.concat("user", vm.toString(j), "_", vm.toString(i)));
                uint256 _redeemShares = uint256(keccak256(abi.encode(_redeemSeed, i, j))) % type(uint96).max;

                vault.setSharesOf(_user, _redeemShares);
                uint256 _userSharesBefore = vault.sharesOf(_user);

                // request redeem
                vm.prank(_user);
                vault.requestRedeem(_redeemShares);

                // assert invariant
                assertGt(_userSharesBefore, vault.sharesOf(_user));
            }

            // assert batch invariant
            assertLt(_totalSharesToRedeemBefore, vault.totalSharesToRedeemAt(vault.currentBatch()));
        }

        // assert vault invariant
        assertLt(vault.totalSharesToRedeemAt(_batchId), vault.totalSharesToRedeem());
    }
}
