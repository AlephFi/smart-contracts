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

import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";

struct AlephVaultStorageData {
    string name;
    string metadataUri;
    bool isAuthEnabled;
    uint8 shareClassesId;
    uint48 startTimeStamp;
    address manager;
    address oracle;
    address guardian;
    address authSigner;
    address underlyingToken;
    address custodian;
    address feeRecipient;
    mapping(uint8 classId => IAlephVault.ShareClass) shareClasses;
    mapping(bytes4 => TimelockRegistry.Timelock) timelocks;
    mapping(bytes4 => address) moduleImplementations;
}

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
library AlephVaultStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.vault")) - 1;

    function load() internal pure returns (AlephVaultStorageData storage sd) {
        uint256 position = STORAGE_POSITION;
        assembly {
            sd.slot := position
        }
    }
}
