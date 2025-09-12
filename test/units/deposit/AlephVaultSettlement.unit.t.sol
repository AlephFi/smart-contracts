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
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultDepositSettlementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    function test_settleDeposit_revertsGivenCallerIsNotOracle() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // settle deposit
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.ORACLE
            )
        );
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_revertsGivenShareClassIsInvalid() public {
        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephVault.InvalidShareClass.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 0,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_revertsGivenFlowIsPaused() public {
        // pause settle deposit flow
        vm.prank(manager);
        vault.pause(PausableFlows.SETTLE_DEPOSIT_FLOW);

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenToBatchIdIsGreaterThanCurrentBatchId()
        public
    {
        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.InvalidToBatchId.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 1,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenToBatchIdIsEqualToDepositSettleId()
        public
    {
        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.NoDepositsToSettle.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: 0,
                newTotalAssets: new uint256[](1),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_revertsGivenNewTotalAssetsIsInvalid() public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(IAlephVaultSettlement.InvalidNewTotalAssets.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](2),
                authSignature: authSignature_1
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_revertsWhenAuthSignatureIsInvalid() public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // make invalid sig
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_REDEEM, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(AuthLibrary.InvalidAuthSignature.selector);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenLastFeePaidIdIsLessThanCurrentBatchId_shouldCallAccumulateFees(
    ) public {
        // roll the block forward to make future batch available
        vm.warp(block.timestamp + 1 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // assert last fee paid id is less than current batch id
        assertLt(vault.lastFeePaidId(), vault.currentBatch());

        // settle deposit
        vm.prank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );

        // assert last fee paid id is equal to current batch id
        assertEq(vault.lastFeePaidId(), _currentBatchId);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsZero_shouldNotSettleDeposit()
        public
    {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);

        // assert deposit settle id is less than current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertLt(vault.depositSettleId(), _currentBatchId);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.prank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsZero_whenNewTotalAssetsChanges_shouldUpdateTotalAssets(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // check total assets and total shares
        uint256 _totalAssets = vault.totalAssets();
        uint256 _totalShares = vault.totalSharesPerSeries(1, 0);
        uint256[] memory _newTotalAssets = new uint256[](1);
        _newTotalAssets[0] = _totalAssets + 100 ether;

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, _newTotalAssets);

        // settle deposit
        vm.prank(oracle);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: _newTotalAssets,
                authSignature: _authSignature
            })
        );

        // assert total assets and total shares
        assertEq(vault.totalAssets(), _newTotalAssets[0]);
        assertEq(vault.totalSharesPerSeries(1, 0), _totalShares);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_revertsGivenVaultHasInsufficientBalance(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 2 days + 1);
        uint48 _currentBatchId = vault.currentBatch();

        // set batch deposit requests
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 100);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.prank(oracle);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(vault), 0, 100));
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_shouldSucceed_singleBatch_settleInNewSeries(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch deposit requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 100 ether);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_2, 200 ether);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSharesPerSeries(1, 0), 0);

        // set higher water mark for lead series
        vault.setHighWaterMark(2 * vault.PRICE_DENOMINATOR());

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0);

        // mint balance for vault
        underlyingToken.mint(address(vault), 300 ether);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.NewSeriesCreated(1, 1, _currentBatchId);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(_currentBatchId - 1, 1, 1, 300 ether, 300 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(0, _currentBatchId, 1, 1, 300 ether, 300 ether, 300 ether);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssetsPerSeries(1, 1), 300 ether);
        assertEq(vault.totalSharesPerSeries(1, 1), 300 ether);

        // assert user shares
        assertEq(vault.sharesOf(1, 1, mockUser_1), 100 ether);
        assertEq(vault.sharesOf(1, 1, mockUser_2), 200 ether);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);

        // assert balance of custodian is 300
        assertEq(underlyingToken.balanceOf(address(custodian)), 300 ether);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_shouldSucceed_singleBatch_settleInLeadSeries(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 2 days + 1);

        // set batch deposit requests
        uint48 _currentBatchId = vault.currentBatch();
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 100 ether);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_2, 200 ether);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSharesPerSeries(1, 0), 0);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0);

        // mint balance for vault
        underlyingToken.mint(address(vault), 300 ether);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(_currentBatchId - 1, 1, 0, 300 ether, 300 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(0, _currentBatchId, 1, 0, 300 ether, 300 ether, 300 ether);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 300 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 300 ether);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 100 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 200 ether);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);

        // assert balance of custodian is 300
        assertEq(underlyingToken.balanceOf(address(custodian)), 300 ether);
    }

    function test_settleDeposit_whenCallerIsOracle_whenFlowIsUnpaused_whenAmountToSettleIsGreaterThanZero_shouldSucceed_multipleBatches(
    ) public {
        // roll the block forward to make future batches available
        vm.warp(block.timestamp + 3 days + 1);

        // assert current batch id
        uint48 _currentBatchId = vault.currentBatch();
        assertEq(_currentBatchId, 3);

        // set batch deposit requests
        vault.setBatchDeposit(_currentBatchId - 2, mockUser_1, 100 ether);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_1, 200 ether);
        vault.setBatchDeposit(_currentBatchId - 1, mockUser_2, 300 ether);

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSharesPerSeries(1, 0), 0);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 0);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 0);

        // mint balance for vault
        underlyingToken.mint(address(vault), 600 ether);

        // generate auth signature
        AuthLibrary.AuthSignature memory _authSignature =
            _getSettlementAuthSignature(AuthLibrary.SETTLE_DEPOSIT, _currentBatchId, new uint256[](1));

        // settle deposit
        vm.startPrank(oracle);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(1, 1, 0, 100 ether, 100 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDepositBatch(2, 1, 0, 500 ether, 500 ether);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultSettlement.SettleDeposit(0, _currentBatchId, 1, 0, 600 ether, 600 ether, 600 ether);
        vault.settleDeposit(
            IAlephVaultSettlement.SettlementParams({
                classId: 1,
                toBatchId: _currentBatchId,
                newTotalAssets: new uint256[](1),
                authSignature: _authSignature
            })
        );
        vm.stopPrank();

        // assert total assets and total shares
        assertEq(vault.totalAssets(), 600 ether);
        assertEq(vault.totalSharesPerSeries(1, 0), 600 ether);

        // assert user shares
        assertEq(vault.sharesOf(1, 0, mockUser_1), 300 ether);
        assertEq(vault.sharesOf(1, 0, mockUser_2), 300 ether);

        // assert deposit settle id is equal to current batch id
        assertEq(vault.depositSettleId(), _currentBatchId);

        // assert balance of custodian is 600
        assertEq(underlyingToken.balanceOf(address(custodian)), 600 ether);
    }
}
