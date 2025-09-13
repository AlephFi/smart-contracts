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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IAlephPausable {
    // EVENTS

    event FlowPaused(bytes4 _pausableFlow, address _pauser);
    event FlowUnpaused(bytes4 _pausableFlowFlag, address _unpauser);

    // ERRORS

    error FlowIsCurrentlyPaused();
    error FlowIsCurrentlyUnpaused();

    // EXTERNAL FUNCTIONS

    /**
     * @notice Pauses a specific flow to prevent its execution
     * @param _pausableFlow The flow identifier to pause
     * @dev Only callable by users with the flow-specific role. Reverts if flow is already paused.
     */
    function pause(bytes4 _pausableFlow) external;

    /**
     * @notice Unpauses a specific flow to allow its execution
     * @param _pausableFlow The flow identifier to unpause
     * @dev Only callable by users with the flow-specific role. Reverts if flow is not paused.
     */
    function unpause(bytes4 _pausableFlow) external;

    /**
     * @notice Checks if a specific flow is currently paused
     * @param _pausableFlow The flow identifier to check
     * @return True if the flow is paused, false otherwise
     */
    function isFlowPaused(bytes4 _pausableFlow) external view returns (bool);
}
