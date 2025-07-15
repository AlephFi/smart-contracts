// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {AlephVaultStorageData} from "../AlephVaultStorage.sol";

/**
 * @dev This library manages the timelock for various storage variables.
 */
library TimelockRegistry {
    struct Timelock {
        uint48 unlockTimestamp;
        bytes newValue;
    }

    error TimelockNotExpired(bytes4 key, uint48 unlockTimestamp);

    bytes4 internal constant MANAGEMENT_FEE = bytes4(keccak256("MANAGEMENT_FEE"));
    bytes4 internal constant PERFORMANCE_FEE = bytes4(keccak256("PERFORMANCE_FEE"));
    bytes4 internal constant PROTOCOL_RATE = bytes4(keccak256("PROTOCOL_RATE"));
    bytes4 internal constant PLATFORM_RATE = bytes4(keccak256("PLATFORM_RATE"));

    function setTimelock(AlephVaultStorageData storage _sd, bytes4 _key) internal returns (bytes memory) {
        Timelock memory _timelock = _sd.timelocks[_key];
        if (_timelock.unlockTimestamp <= Time.timestamp()) {
            revert TimelockNotExpired(_key, _timelock.unlockTimestamp);
        }
        delete _sd.timelocks[_key];
        return _timelock.newValue;
    }
}
