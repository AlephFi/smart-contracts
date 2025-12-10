// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
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
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library TimelockRegistry {
    /**
     * @notice The key for the minimum deposit amount.
     */
    bytes4 internal constant MIN_DEPOSIT_AMOUNT = bytes4(keccak256("MIN_DEPOSIT_AMOUNT"));
    /**
     * @notice The key for the minimum user balance.
     */
    bytes4 internal constant MIN_USER_BALANCE = bytes4(keccak256("MIN_USER_BALANCE"));
    /**
     * @notice The key for the maximum deposit cap.
     */
    bytes4 internal constant MAX_DEPOSIT_CAP = bytes4(keccak256("MAX_DEPOSIT_CAP"));
    /**
     * @notice The key for the notice period.
     */
    bytes4 internal constant NOTICE_PERIOD = bytes4(keccak256("NOTICE_PERIOD"));
    /**
     * @notice The key for the lock in period.
     */
    bytes4 internal constant LOCK_IN_PERIOD = bytes4(keccak256("LOCK_IN_PERIOD"));
    /**
     * @notice The key for the minimum redeem amount.
     */
    bytes4 internal constant MIN_REDEEM_AMOUNT = bytes4(keccak256("MIN_REDEEM_AMOUNT"));
    /**
     * @notice The key for the management fee.
     */
    bytes4 internal constant MANAGEMENT_FEE = bytes4(keccak256("MANAGEMENT_FEE"));
    /**
     * @notice The key for the performance fee.
     */
    bytes4 internal constant PERFORMANCE_FEE = bytes4(keccak256("PERFORMANCE_FEE"));
    /**
     * @notice The key for the accountant.
     */
    bytes4 internal constant ACCOUNTANT = bytes4(keccak256("ACCOUNTANT"));
    /**
     * @notice The key for the sync expiration batches.
     */
    bytes4 internal constant SYNC_EXPIRATION_BATCHES = bytes4(keccak256("SYNC_EXPIRATION_BATCHES"));

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The error thrown when the timelock is not queued.
     * @param key The key of the timelock.
     * @param classId The class ID of the timelock.
     */
    error TimelockNotQueued(bytes4 key, uint8 classId);
    /**
     * @notice The error thrown when the timelock is not expired.
     * @param key The key of the timelock.
     * @param classId The class ID of the timelock.
     * @param unlockTimestamp The timestamp at which the timelock expires.
     */
    error TimelockNotExpired(bytes4 key, uint8 classId, uint48 unlockTimestamp);

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The details of the timelock.
     * @param isQueued Whether the timelock is queued.
     * @param unlockTimestamp The timestamp at which the timelock expires.
     * @param newValue The new value to be set.
     */
    struct Timelock {
        bool isQueued;
        uint48 unlockTimestamp;
        bytes newValue;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Sets the timelock for the given key and class ID.
     * @param _key The key of the timelock.
     * @param _classId The class ID of the timelock.
     * @param _sd The storage struct.
     * @return The new value of the timelock.
     */
    function setTimelock(bytes4 _key, uint8 _classId, AlephVaultStorageData storage _sd)
        internal
        returns (bytes memory)
    {
        bytes4 _classKey = getKey(_key, _classId);
        Timelock memory _timelock = _sd.timelocks[_classKey];
        if (!_timelock.isQueued) {
            revert TimelockNotQueued(_key, _classId);
        }
        if (_timelock.unlockTimestamp > Time.timestamp()) {
            revert TimelockNotExpired(_key, _classId, _timelock.unlockTimestamp);
        }
        delete _sd.timelocks[_classKey];
        return _timelock.newValue;
    }

    /**
     * @notice Gets the key for the given key and class ID.
     * @param _key The key of the timelock.
     * @param _classId The class ID of the timelock.
     * @return _classKey The key for the given key and class ID.
     */
    function getKey(bytes4 _key, uint8 _classId) internal pure returns (bytes4 _classKey) {
        _classKey = bytes4(keccak256(abi.encodePacked(_key, _classId)));
    }
}
