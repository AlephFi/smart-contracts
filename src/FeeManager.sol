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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {TimelockRegistry} from "./libraries/TimelockRegistry.sol";
import {AlephVaultStorageData} from "./AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract FeeManager is IFeeManager {
    uint32 public immutable MAXIMUM_MANAGEMENT_FEE;
    uint32 public immutable MAXIMUM_PERFORMANCE_FEE;
    uint48 public immutable MANAGEMENT_FEE_TIMELOCK;
    uint48 public immutable PERFORMANCE_FEE_TIMELOCK;

    /**
     * @dev Returns the storage struct for the vault.
     */
    function _getStorage() internal pure virtual returns (AlephVaultStorageData storage sd);

    /// @inheritdoc IFeeManager
    function queueManagementFee(uint32 _managementFee) external virtual;

    /// @inheritdoc IFeeManager
    function queuePerformanceFee(uint32 _performanceFee) external virtual;

    /// @inheritdoc IFeeManager
    function setManagementFee() external virtual;

    /// @inheritdoc IFeeManager
    function setPerformanceFee() external virtual;

    /**
     * @dev Internal function to queue a new management fee.
     * @param _managementFee The new management fee to be set.
     */
    function _queueManagementFee(uint32 _managementFee) internal {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE) {
            revert InvalidManagementFee();
        }
        _getStorage().timelocks[TimelockRegistry.MANAGEMENT_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MANAGEMENT_FEE_TIMELOCK,
            newValue: abi.encode(_managementFee)
        });
        emit NewManagementFeeQueued(_managementFee);
    }

    /**
     * @dev Internal function to queue a new performance fee.
     * @param _performanceFee The new performance fee to be set.
     */
    function _queuePerformanceFee(uint32 _performanceFee) internal {
        if (_performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee();
        }
        _getStorage().timelocks[TimelockRegistry.PERFORMANCE_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + PERFORMANCE_FEE_TIMELOCK,
            newValue: abi.encode(_performanceFee)
        });
        emit NewPerformanceFeeQueued(_performanceFee);
    }

    /**
     * @dev Internal function to set the management fee.
     */
    function _setManagementFee() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint32 _managementFee = abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MANAGEMENT_FEE), (uint32));
        _sd.managementFee = _managementFee;
        emit NewManagementFeeSet(_managementFee);
    }

    /**
     * @dev Internal function to set the performance fee.
     */
    function _setPerformanceFee() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint32 _performanceFee =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.PERFORMANCE_FEE), (uint32));
        _sd.performanceFee = _performanceFee;
        emit NewPerformanceFeeSet(_performanceFee);
    }
}
