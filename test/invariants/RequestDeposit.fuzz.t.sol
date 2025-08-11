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
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract RequestDepositTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConstructorParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_requestDeposit_totalAmountToDepositMustAlwaysIncrease(address _user, uint256 _depositAmount) public {
        // deposit amount 0 will revert with InsufficientDeposit
        vm.assume(_depositAmount > 0);
        // token amount to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_depositAmount < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));
        // don't use user as vault
        vm.assume(_user != address(vault));

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up user 1 with _depositAmount tokens
        vm.startPrank(_user);
        underlyingToken.mint(address(_user), _depositAmount);

        // set vault allowance to _depositAmount
        underlyingToken.approve(address(vault), _depositAmount);

        // get user and vault balance before deposit
        uint256 _userBalanceBefore = underlyingToken.balanceOf(_user);
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));

        // get  auth signature
        AuthLibrary.AuthSignature memory _authSignature = _getAuthSignature(_user, type(uint256).max);

        // request deposit
        uint48 _depositBatchId = vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: _authSignature})
        );
        vm.stopPrank();

        // assert invariant
        assertLt(vault.totalAmountToDepositAt(_batchId), vault.totalAmountToDepositAt(_depositBatchId));
        assertLt(_vaultBalanceBefore, underlyingToken.balanceOf(address(vault)));
        assertGt(_userBalanceBefore, underlyingToken.balanceOf(_user));
    }

    function test_requestDeposit_totalAmountToDepositMustAlwaysIncrease_multipleUsers(
        uint8 _iterations,
        bytes32 _depositSeed
    ) public {
        vm.assume(_iterations > 0);

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // get vault balance before deposits
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));

        // set up users
        for (uint8 i = 0; i < _iterations; i++) {
            address _user = makeAddr(string.concat("user", vm.toString(i)));
            uint256 _depositAmount = uint256(keccak256(abi.encode(_depositSeed, i))) % type(uint96).max;

            vm.startPrank(_user);
            underlyingToken.mint(address(_user), _depositAmount);
            underlyingToken.approve(address(vault), _depositAmount);

            // get user balance before deposit
            uint256 _userBalanceBefore = underlyingToken.balanceOf(_user);

            // get  auth signature
            AuthLibrary.AuthSignature memory _authSignature = _getAuthSignature(_user, type(uint256).max);

            // request deposit
            vault.requestDeposit(
                IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: _authSignature})
            );
            vm.stopPrank();

            // assert user invariant
            assertGt(_userBalanceBefore, underlyingToken.balanceOf(_user));
            assertLt(vault.totalAmountToDepositAt(_batchId), vault.totalAmountToDepositAt(vault.currentBatch()));
        }

        // assert vault invariant
        assertLt(vault.totalAmountToDepositAt(_batchId), vault.totalAmountToDeposit());
        assertGt(underlyingToken.balanceOf(address(vault)), _vaultBalanceBefore);
    }

    function test_requestDeposit_totalAmountToDepositMustAlwaysIncrease_multipleUsers_multipleBatches(
        uint8 _iterations,
        uint8 _batches,
        bytes32 _depositSeed
    ) public {
        vm.assume(_iterations > 0);
        vm.assume(_iterations < 50);
        vm.assume(_batches > 0);
        vm.assume(_batches < 50);

        // get batch id
        uint48 _batchId = vault.currentBatch();

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // get vault balance before deposits
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));

        // set up users per batch
        for (uint8 i = 0; i < _batches; i++) {
            // roll the block forward to make batch available
            vm.warp(block.timestamp + 1 days + 1);

            // get total deposits in batch
            uint256 _totalDepositsBefore = vault.totalAmountToDepositAt(vault.currentBatch());

            for (uint8 j = 0; j < _iterations; j++) {
                address _user = makeAddr(string.concat("user", vm.toString(j), "_", vm.toString(i)));
                uint256 _depositAmount = uint256(keccak256(abi.encode(_depositSeed, i, j))) % type(uint96).max;

                vm.startPrank(_user);
                underlyingToken.mint(address(_user), _depositAmount);
                underlyingToken.approve(address(vault), _depositAmount);

                // get user balance before deposit
                uint256 _userBalanceBefore = underlyingToken.balanceOf(_user);

                // get  auth signature
                AuthLibrary.AuthSignature memory _authSignature = _getAuthSignature(_user, type(uint256).max);

                // request deposit
                vault.requestDeposit(
                    IERC7540Deposit.RequestDepositParams({amount: _depositAmount, authSignature: _authSignature})
                );
                vm.stopPrank();

                // assert user invariant
                assertGt(_userBalanceBefore, underlyingToken.balanceOf(_user));
            }

            // assert batch invariant
            assertLt(_totalDepositsBefore, vault.totalAmountToDepositAt(vault.currentBatch()));
        }

        // assert vault invariant
        assertLt(vault.totalAmountToDepositAt(_batchId), vault.totalAmountToDeposit());
        assertGt(underlyingToken.balanceOf(address(vault)), _vaultBalanceBefore);
    }
}
