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

import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IAlephPausable} from "@aleph-vault/interfaces/IAlephPausable.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AlephPausableStorage, AlephPausableStorageData} from "@aleph-vault/AlephPausableStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
abstract contract AlephPausable is IAlephPausable, AccessControlUpgradeable {
    // MODIFIERS

    modifier whenFlowNotPaused(bytes4 _pausableFlow) {
        _revertIfFlowPaused(_pausableFlow);
        _;
    }

    modifier whenFlowPaused(bytes4 _pausableFlow) {
        _revertIfFlowUnpaused(_pausableFlow);
        _;
    }

    // EXTERNAL FUNCTIONS

    /// @inheritdoc IAlephPausable
    function isFlowPaused(bytes4 _pausableFlow) external view returns (bool _isPaused) {
        return _getPausableStorage().flowsPauseStates[_pausableFlow];
    }

    /// @inheritdoc IAlephPausable
    function pause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _pause(_pausableFlow);
    }

    /// @inheritdoc IAlephPausable
    function unpause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _unpause(_pausableFlow);
    }

    // INTERNAL FUNCTIONS

    function _pause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (_sd.flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyPaused();

        _sd.flowsPauseStates[_pausableFlow] = true;
        emit FlowPaused(_pausableFlow, msg.sender);
    }

    function _unpause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (!_sd.flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyUnpaused();

        _sd.flowsPauseStates[_pausableFlow] = false;
        emit FlowUnpaused(_pausableFlow, msg.sender);
    }

    function _revertIfFlowPaused(bytes4 _pausableFlow) internal view {
        if (_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyPaused();
    }

    function _revertIfFlowUnpaused(bytes4 _pausableFlow) internal view {
        if (!_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyUnpaused();
    }

    function __AlephVaultDeposit_init(address _manager, address _guardian, address _operationsMultisig)
        internal
        onlyInitializing
    {
        _getPausableStorage().flowsPauseStates[PausableFlows.DEPOSIT_REQUEST_FLOW] = true;
        _getPausableStorage().flowsPauseStates[PausableFlows.SETTLE_DEPOSIT_FLOW] = true;
        _grantRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _manager);
        _grantRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _guardian);
        _grantRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _operationsMultisig);
        _grantRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _manager);
        _grantRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _guardian);
        _grantRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _operationsMultisig);
    }

    function __AlephVaultRedeem_init(address _manager, address _guardian, address _operationsMultisig)
        internal
        onlyInitializing
    {
        _getPausableStorage().flowsPauseStates[PausableFlows.REDEEM_REQUEST_FLOW] = true;
        _getPausableStorage().flowsPauseStates[PausableFlows.SETTLE_REDEEM_FLOW] = true;
        _grantRole(PausableFlows.REDEEM_REQUEST_FLOW, _manager);
        _grantRole(PausableFlows.REDEEM_REQUEST_FLOW, _guardian);
        _grantRole(PausableFlows.REDEEM_REQUEST_FLOW, _operationsMultisig);
        _grantRole(PausableFlows.SETTLE_REDEEM_FLOW, _manager);
        _grantRole(PausableFlows.SETTLE_REDEEM_FLOW, _guardian);
        _grantRole(PausableFlows.SETTLE_REDEEM_FLOW, _operationsMultisig);
    }

    function _getPausableStorage() internal pure returns (AlephPausableStorageData storage _sd) {
        return AlephPausableStorage.load();
    }
}
