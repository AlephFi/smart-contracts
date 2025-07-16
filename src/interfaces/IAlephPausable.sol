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
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
interface IAlephPausable {
    // EVENTS

    event FlowPaused(bytes4 _pausableFlow, address _pauser);
    event FlowUnpaused(bytes4 _pausableFlowFlag, address _unpauser);

    // ERRORS

    error FlowIsCurrentlyPaused();
    error FlowIsCurrentlyUnpaused();

    // EXTERNAL FUNCTIONS

    function pause(bytes4 _pausableFlow) external;
    function unpause(bytes4 _pausableFlow) external;
    function isFlowPaused(bytes4 _pausableFlow) external view returns (bool);
}
