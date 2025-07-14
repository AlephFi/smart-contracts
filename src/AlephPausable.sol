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

import "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IAlephPausable} from "./interfaces/IAlephPausable.sol";
import {AlephPausableStorage, AlephPausableStorageData} from "./AlephPausableStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
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

    function isFlowPaused(bytes4 _pausableFlow) external view returns (bool _isPaused) {
        return _getPausableStorage().flowsPauseStates[_pausableFlow];
    }

    function pause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _pause(_pausableFlow);
    }

    function unpause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _unpause(_pausableFlow);
    }

    // INTERNAL FUNCTIONS

    function _pause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (_sd.flowsPauseStates[_pausableFlow]) revert PauseFlowIsAlreadyPaused();

        _sd.flowsPauseStates[_pausableFlow] = true;
        emit FlowPaused(_pausableFlow, msg.sender);
    }

    function _unpause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (!_sd.flowsPauseStates[_pausableFlow]) revert UnpausingFlowIsAlreadyUnpaused();

        _sd.flowsPauseStates[_pausableFlow] = false;
        emit FlowUnpaused(_pausableFlow, msg.sender);
    }

    function _revertIfFlowPaused(bytes4 _pausableFlow) internal view {
        if (_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyPaused();
    }

    function _revertIfFlowUnpaused(bytes4 _pausableFlow) internal view {
        if (!_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyUnpaused();
    }

    function _getPausableStorage() internal pure returns (AlephPausableStorageData storage _sd) {
        return AlephPausableStorage.load();
    }
}
