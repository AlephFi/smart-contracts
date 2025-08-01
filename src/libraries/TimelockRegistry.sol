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
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
library TimelockRegistry {
    struct Timelock {
        uint48 unlockTimestamp;
        bytes newValue;
    }

    error TimelockNotExpired(bytes4 key, uint48 unlockTimestamp);

    bytes4 internal constant MANAGEMENT_FEE = bytes4(keccak256("MANAGEMENT_FEE"));
    bytes4 internal constant PERFORMANCE_FEE = bytes4(keccak256("PERFORMANCE_FEE"));
    bytes4 internal constant FEE_RECIPIENT = bytes4(keccak256("FEE_RECIPIENT"));
    bytes4 internal constant MAX_DEPOSIT_CAP = bytes4(keccak256("MAX_DEPOSIT_CAP"));
    bytes4 internal constant MIN_DEPOSIT_AMOUNT = bytes4(keccak256("MIN_DEPOSIT_AMOUNT"));

    function setTimelock(AlephVaultStorageData storage _sd, bytes4 _key) internal returns (bytes memory) {
        Timelock memory _timelock = _sd.timelocks[_key];
        if (_timelock.unlockTimestamp > Time.timestamp()) {
            revert TimelockNotExpired(_key, _timelock.unlockTimestamp);
        }
        delete _sd.timelocks[_key];
        return _timelock.newValue;
    }
}
