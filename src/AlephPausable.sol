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
    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Modifier to check if a flow is not paused
     * @param _pausableFlow The flow identifier
     */
    modifier whenFlowNotPaused(bytes4 _pausableFlow) {
        _revertIfFlowPaused(_pausableFlow);
        _;
    }

    /**
     * @notice Modifier to check if a flow is paused
     * @param _pausableFlow The flow identifier
     */
    modifier whenFlowPaused(bytes4 _pausableFlow) {
        _revertIfFlowUnpaused(_pausableFlow);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephPausable
    function isFlowPaused(bytes4 _pausableFlow) external view returns (bool _isPaused) {
        return _getPausableStorage().flowsPauseStates[_pausableFlow];
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSING FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephPausable
    function pause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _pause(_pausableFlow);
    }

    /// @inheritdoc IAlephPausable
    function unpause(bytes4 _pausableFlow) external onlyRole(_pausableFlow) {
        _unpause(_pausableFlow);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal function to pause a flow
     * @param _pausableFlow The flow identifier
     */
    function _pause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (_sd.flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyPaused();

        _sd.flowsPauseStates[_pausableFlow] = true;
        emit FlowPaused(_pausableFlow, msg.sender);
    }

    /**
     * @dev Internal function to unpause a flow
     * @param _pausableFlow The flow identifier
     */
    function _unpause(bytes4 _pausableFlow) internal {
        AlephPausableStorageData storage _sd = _getPausableStorage();
        if (!_sd.flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyUnpaused();

        _sd.flowsPauseStates[_pausableFlow] = false;
        emit FlowUnpaused(_pausableFlow, msg.sender);
    }

    /**
     * @dev Internal function to revert if a flow is paused
     * @param _pausableFlow The flow identifier
     */
    function _revertIfFlowPaused(bytes4 _pausableFlow) internal view {
        if (_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyPaused();
    }

    /**
     * @dev Internal function to revert if a flow is unpaused
     * @param _pausableFlow The flow identifier
     */
    function _revertIfFlowUnpaused(bytes4 _pausableFlow) internal view {
        if (!_getPausableStorage().flowsPauseStates[_pausableFlow]) revert FlowIsCurrentlyUnpaused();
    }

    /**
     * @dev Internal function to initialize the deposit flow
     * @param _manager The manager address
     * @param _guardian The guardian address
     * @param _operationsMultisig The operations multisig address
     */
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

    /**
     * @dev Internal function to initialize the redeem flow
     * @param _manager The manager address
     * @param _guardian The guardian address
     * @param _operationsMultisig The operations multisig address
     */
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
        _grantRole(PausableFlows.WITHDRAW_FLOW, _guardian);
    }

    /**
     * @dev Internal function to get the pausable storage
     * @return _sd The pausable storage
     */
    function _getPausableStorage() internal pure returns (AlephPausableStorageData storage _sd) {
        _sd = AlephPausableStorage.load();
    }
}
