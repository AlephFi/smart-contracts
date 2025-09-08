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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract RequestSettleDepositTest is BaseTest {
    using Math for uint256;

    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
        vault.setMinDepositAmount(0);
        vault.setMaxDepositCap(0);
    }

    /// total shares will only increase if management fee is set and/or performance fee is set and new highwater mark is reached
    function test_settleDeposit_withoutNewDeposit_totalSharesMustAlwaysIncrease_vaultBalanceMustNeverIncrease(
        address _user,
        uint256 _depositAmount,
        uint256 _newTotalAssets
    ) public {
        // deposit amount value needs to be large enough for management shares to mint
        vm.assume(_depositAmount > 1e18);
        // token amount to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_depositAmount < type(uint96).max);
        // new total assets must be greater than 0 (we'll manually settle first batch)
        vm.assume(_newTotalAssets > 0);
        // new total assets to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_newTotalAssets < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));
        // don't use user as vault
        vm.assume(_user != address(vault));

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(_user);
        underlyingToken.mint(address(_user), _depositAmount);
        underlyingToken.approve(address(vault), _depositAmount);
        AuthLibrary.AuthSignature memory _authSignature = _getDepositAuthSignature(_user, type(uint256).max);
        vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({classId: 1, amount: _depositAmount, authSignature: _authSignature})
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _currentBatchId = vault.currentBatch();

        // settle first batch
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _settlementAuthSignature
            })
        );

        // get user and vault balance before deposit
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));
        uint256 _vaultSharesBefore = vault.totalShares();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        _currentBatchId = vault.currentBatch();

        // settle second batch
        uint256[] memory _newTotalAssetsArr = new uint256[](1);
        _newTotalAssetsArr[0] = _newTotalAssets;
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, _newTotalAssetsArr);
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssetsArr,
                authSignature: _settlementAuthSignature
            })
        );

        // assert invariant
        assertLt(_vaultSharesBefore, vault.totalShares());
        assertGe(_vaultBalanceBefore, underlyingToken.balanceOf(address(vault)));
    }

    function test_settleDeposit_withNewDeposit_totalSharesMustAlwaysIncrease_vaultBalanceMustNeverIncrease(
        address _user,
        uint256 _depositAmount,
        uint256 _newTotalAssets
    ) public {
        // deposit amount value needs to be large enough for management shares to mint
        vm.assume(_depositAmount > 1e18);
        // token amount to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_depositAmount < type(uint96).max);
        // new total assets must be greater than 0 (we'll manually settle first batch)
        vm.assume(_newTotalAssets > 0);
        // new total assets to not exceed 2^96 to avoid overflow from multiplication of same data type
        vm.assume(_newTotalAssets < type(uint96).max);
        // don't use zero address
        vm.assume(_user != address(0));
        // don't use user as vault
        vm.assume(_user != address(vault));

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        vm.startPrank(_user);
        underlyingToken.mint(address(_user), _depositAmount * 2);
        underlyingToken.approve(address(vault), _depositAmount * 2);
        AuthLibrary.AuthSignature memory _authSignature = _getDepositAuthSignature(_user, type(uint256).max);
        vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({classId: 1, amount: _depositAmount, authSignature: _authSignature})
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _currentBatchId = vault.currentBatch();

        // settle first batch
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _settlementAuthSignature
            })
        );

        // request deposit
        vm.prank(_user);
        vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({classId: 1, amount: _depositAmount, authSignature: _authSignature})
        );

        // get vault state before deposit
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));
        uint256 _vaultSharesBefore = vault.totalShares();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        _currentBatchId = vault.currentBatch();

        // settle second batch
        uint256[] memory _newTotalAssetsArr = new uint256[](1);
        _newTotalAssetsArr[0] = _newTotalAssets;

        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, _newTotalAssetsArr);
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssetsArr,
                authSignature: _settlementAuthSignature
            })
        );

        // assert invariant
        assertLt(_vaultSharesBefore, vault.totalSharesPerSeries(1, 0));
        assertGe(_vaultBalanceBefore, underlyingToken.balanceOf(address(vault)));
        if (_newTotalAssets <= _depositAmount) {
            assertLt(0, vault.totalSharesPerSeries(1, 1));
        }
    }

    function test_settleDeposit_totalSharesMustAlwaysIncrease_vaultBalanceMustNeverIncrease_multipleUsers(
        uint8 _iterations,
        bytes32 _depositSeed,
        uint256 _newTotalAssets
    ) public {
        vm.assume(_iterations > 0);
        vm.assume(_newTotalAssets > 0);
        vm.assume(_newTotalAssets < type(uint96).max);

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up first settle cycle
        address _firstUser = makeAddr("user");
        uint256 _firstDepositAmount = uint256(keccak256(abi.encode(_depositSeed, 0))) % type(uint96).max;

        vm.startPrank(_firstUser);
        underlyingToken.mint(_firstUser, _firstDepositAmount);
        underlyingToken.approve(address(vault), _firstDepositAmount);
        AuthLibrary.AuthSignature memory _authSignature_1 = _getDepositAuthSignature(_firstUser, type(uint256).max);
        vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({
                classId: 1,
                amount: _firstDepositAmount,
                authSignature: _authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        uint48 _currentBatchId = vault.currentBatch();

        // settle first batch
        AuthLibrary.AuthSignature memory _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _settlementAuthSignature
            })
        );

        // set up second settle cycle
        for (uint8 i = 0; i < _iterations; i++) {
            address _user = makeAddr(string.concat("user", vm.toString(i)));
            uint256 _depositAmount = uint256(keccak256(abi.encode(_depositSeed, i))) % type(uint96).max;

            vm.startPrank(_user);
            underlyingToken.mint(_user, _depositAmount);
            underlyingToken.approve(address(vault), _depositAmount);
            AuthLibrary.AuthSignature memory _authSignature = _getDepositAuthSignature(_user, type(uint256).max);
            vault.requestDeposit(
                IERC7540Deposit.RequestDepositParams({classId: 1, amount: _depositAmount, authSignature: _authSignature})
            );
            vm.stopPrank();
        }

        // get vault state before deposits
        uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));
        uint256 _leadSeriesSharesBefore = vault.totalSharesPerSeries(1, 0);

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);
        _currentBatchId = vault.currentBatch();

        // settle second batch
        uint256[] memory _newTotalAssetsArr = new uint256[](1);
        _newTotalAssetsArr[0] = _newTotalAssets;
        _settlementAuthSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, _newTotalAssetsArr);
        vm.prank(oracle);
        vault.settleDeposit(
            IERC7540Settlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssetsArr,
                authSignature: _settlementAuthSignature
            })
        );

        // assert invariant
        assertLt(_leadSeriesSharesBefore, vault.totalSharesPerSeries(1, 0));
        assertGe(_vaultBalanceBefore, underlyingToken.balanceOf(address(vault)));
        if (_newTotalAssets <= _firstDepositAmount) {
            assertLt(0, vault.totalSharesPerSeries(1, 1));
        }
    }

    function test_settleDeposit_totalSharesMustAlwaysIncrease_vaultBalanceMustNeverIncrease_multipleUsers_multipleBatches(
        uint8 _iterations,
        uint8 _batches,
        bytes32 _depositSeed,
        bytes32 _newTotalAssetsSeed
    ) public {
        vm.assume(_iterations > 0);
        vm.assume(_batches > 0);
        vm.assume(_iterations < 30);
        vm.assume(_batches < 30);

        // roll the block forward to make batch available
        vm.warp(block.timestamp + 1 days + 1);

        // set up first settle cycle
        address _firstUser = makeAddr("user");
        uint256 _firstDepositAmount = uint256(keccak256(abi.encode(_depositSeed, 0))) % type(uint96).max;

        vm.startPrank(_firstUser);
        underlyingToken.mint(_firstUser, _firstDepositAmount);
        underlyingToken.approve(address(vault), _firstDepositAmount);
        AuthLibrary.AuthSignature memory _authSignature_1 = _getDepositAuthSignature(_firstUser, type(uint256).max);
        vault.requestDeposit(
            IERC7540Deposit.RequestDepositParams({
                classId: 1,
                amount: _firstDepositAmount,
                authSignature: _authSignature_1
            })
        );
        vm.stopPrank();

        // roll the block forward to next batch
        vm.warp(block.timestamp + 1 days);

        // settle first batch
        IERC7540Settlement.SettlementParams memory _settlementParams = IERC7540Settlement.SettlementParams({
            classId: 1,
            toBatchId: vault.currentBatch(),
            newTotalAssets: new uint256[](1),
            authSignature: _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, vault.currentBatch(), new uint256[](1))
        });
        vm.prank(oracle);
        vault.settleDeposit(_settlementParams);

        // set up next settlement cycles
        for (uint8 i = 0; i < _batches; i++) {
            // roll the block forward to next batch
            vm.warp(block.timestamp + 1 days);

            // set up users deposits per batch
            uint256 _totalDeposits;
            for (uint8 j = 0; j < _iterations; j++) {
                bool _withNewDeposit = uint256(keccak256(abi.encode(_depositSeed, i, j))) % 2 == 0;
                if (_withNewDeposit) {
                    // set up new deposit
                    address _user = makeAddr(string.concat("user", vm.toString(j), "_", vm.toString(i)));
                    uint256 _depositAmount = uint256(keccak256(abi.encode(_depositSeed, i, j))) % type(uint96).max;
                    _totalDeposits += _depositAmount;

                    vm.startPrank(_user);
                    underlyingToken.mint(_user, _depositAmount);
                    underlyingToken.approve(address(vault), _depositAmount);
                    AuthLibrary.AuthSignature memory _authSignature = _getDepositAuthSignature(_user, type(uint256).max);
                    vault.requestDeposit(
                        IERC7540Deposit.RequestDepositParams({
                            classId: 1,
                            amount: _depositAmount,
                            authSignature: _authSignature
                        })
                    );
                    vm.stopPrank();
                }
            }

            // roll the block forward to next batch
            vm.warp(block.timestamp + 1 days);
            _settlementParams.toBatchId = vault.currentBatch();

            // settle batch
            uint256 _newTotalAssets = uint256(keccak256(abi.encode(_newTotalAssetsSeed, i))) % type(uint96).max;
            bool _settleBatch = _newTotalAssets % 2 == 0;
            if (_settleBatch) {
                uint8 _lastConsolidatedSeriesId = vault.lastConsolidatedSeriesId();
                uint8 _activeSeries = vault.shareSeriesId() - _lastConsolidatedSeriesId + 1;
                uint256 _leadSeriesAssetsBefore = vault.totalAssetsPerSeries(1, 0);
                uint256 _vaultBalanceBefore = underlyingToken.balanceOf(address(vault));

                uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
                uint256 _scalingFactor = _newTotalAssets.mulDiv(_priceDenominator, _leadSeriesAssetsBefore);
                uint256[] memory _newTotalAssetsArr = new uint256[](_activeSeries);
                uint256[] memory _vaultSharesBefore = new uint256[](_activeSeries + 1);
                _newTotalAssetsArr[0] = _newTotalAssets;
                _vaultSharesBefore[0] = vault.totalSharesPerSeries(1, 0);
                for (uint8 k = 1; k < _activeSeries; k++) {
                    _newTotalAssetsArr[k] = vault.totalAssetsPerSeries(1, k + _lastConsolidatedSeriesId).mulDiv(
                        _scalingFactor, _priceDenominator
                    );
                    _vaultSharesBefore[k] = vault.totalSharesPerSeries(1, k + _lastConsolidatedSeriesId);
                }

                _settlementParams.newTotalAssets = _newTotalAssetsArr;
                _settlementParams.authSignature = _getSettlementAuthSignature(
                    AuthLibrary.SETTLE_DEPOSIT, _settlementParams.toBatchId, _newTotalAssetsArr
                );
                vm.prank(oracle);
                vault.settleDeposit(_settlementParams);

                // assert invariant
                assertLe(_vaultSharesBefore[0], vault.totalSharesPerSeries(1, 0));
                assertGe(_vaultBalanceBefore, underlyingToken.balanceOf(address(vault)));
                if (_scalingFactor <= _priceDenominator && _totalDeposits > 0) {
                    for (uint8 k = 1; k <= _activeSeries; k++) {
                        assertLt(_vaultSharesBefore[k], vault.totalSharesPerSeries(1, k + _lastConsolidatedSeriesId));
                    }
                }
            }
        }
    }
}
