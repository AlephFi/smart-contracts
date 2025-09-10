// SPDX-License-Identifier: MIT
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
    struct Timelock {
        bool isQueued;
        uint48 unlockTimestamp;
        bytes newValue;
    }

    error TimelockNotQueued(bytes4 key, uint8 classId);
    error TimelockNotExpired(bytes4 key, uint8 classId, uint48 unlockTimestamp);

    bytes4 internal constant MANAGEMENT_FEE = bytes4(keccak256("MANAGEMENT_FEE"));
    bytes4 internal constant PERFORMANCE_FEE = bytes4(keccak256("PERFORMANCE_FEE"));
    bytes4 internal constant FEE_RECIPIENT = bytes4(keccak256("FEE_RECIPIENT"));
    bytes4 internal constant NOTICE_PERIOD = bytes4(keccak256("NOTICE_PERIOD"));
    bytes4 internal constant MAX_DEPOSIT_CAP = bytes4(keccak256("MAX_DEPOSIT_CAP"));
    bytes4 internal constant MIN_DEPOSIT_AMOUNT = bytes4(keccak256("MIN_DEPOSIT_AMOUNT"));

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

    function getKey(bytes4 _key, uint8 _classId) internal pure returns (bytes4 _classKey) {
        _classKey = bytes4(keccak256(abi.encodePacked(_key, _classId)));
    }
}
