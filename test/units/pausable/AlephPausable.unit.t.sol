// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephPausableTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_pause_revertsWhenFlowAlreadyPaused() public {
        // Flow starts paused after initialization
        vm.prank(manager);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyPaused.selector);
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);
    }

    function test_pause_succeedsWhenFlowNotPaused() public {
        // Unpause first
        vm.prank(manager);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        // Now pause should succeed
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IAlephPausable.FlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW, manager);
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
    }

    function test_pause_revertsWhenUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");
        vm.prank(unauthorized);
        vm.expectRevert();
        vault.pause(PausableFlows.DEPOSIT_REQUEST_FLOW);
    }

    /*//////////////////////////////////////////////////////////////
                        UNPAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_unpause_revertsWhenFlowNotPaused() public {
        // Unpause first
        vm.prank(manager);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        // Try to unpause again - should revert
        vm.prank(manager);
        vm.expectRevert(IAlephPausable.FlowIsCurrentlyUnpaused.selector);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);
    }

    function test_unpause_succeedsWhenFlowPaused() public {
        // Flow starts paused, so unpause should succeed
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IAlephPausable.FlowUnpaused(PausableFlows.DEPOSIT_REQUEST_FLOW, manager);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        assertFalse(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
    }

    function test_unpause_revertsWhenUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");
        vm.prank(unauthorized);
        vm.expectRevert();
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE ALL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_pauseAll_pausesAllFlows() public {
        // Unpause all flows first
        _unpauseVaultFlows();

        // Pause all flows
        vm.prank(guardian);
        vm.expectEmit(false, false, false, true);
        emit IAlephPausable.AllFlowsPaused();
        vault.pauseAll();

        // Verify all flows are paused
        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.REDEEM_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_DEPOSIT_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_REDEEM_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.WITHDRAW_FLOW));
    }

    function test_pauseAll_revertsWhenUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");
        vm.prank(unauthorized);
        vm.expectRevert();
        vault.pauseAll();
    }

    function test_pauseAll_canBeCalledMultipleTimes() public {
        // Unpause all flows first
        _unpauseVaultFlows();

        // First pauseAll
        vm.prank(guardian);
        vault.pauseAll();

        // Second pauseAll should also succeed (no revert for already paused)
        vm.prank(guardian);
        vault.pauseAll();

        // Verify all flows are still paused
        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.REDEEM_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_DEPOSIT_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_REDEEM_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.WITHDRAW_FLOW));
    }

    /*//////////////////////////////////////////////////////////////
                        IS FLOW PAUSED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isFlowPaused_returnsTrueWhenPaused() public {
        // Flow starts paused
        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
    }

    function test_isFlowPaused_returnsFalseWhenUnpaused() public {
        // Unpause flow
        vm.prank(manager);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);

        // Should return false
        assertFalse(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
    }
}

