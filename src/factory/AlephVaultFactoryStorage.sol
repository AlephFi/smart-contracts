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

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * @notice Data layout for the aleph vault factory storage.
 * @param isAuthEnabled Whether the authentication for deployment is enabled.
 * @param beacon The beacon address for the vaults.
 * @param operationsMultisig The operations multisig address.
 * @param oracle The oracle address for the vaults.
 * @param guardian The guardian address for the vaults.
 * @param authSigner The auth signer address.
 * @param accountant The accountant address.
 * @param vaults The vaults deployed by the factory.
 * @param moduleImplementations The module implementations.
 */
struct AlephVaultFactoryStorageData {
    bool isAuthEnabled;
    address beacon;
    address operationsMultisig;
    address oracle;
    address guardian;
    address authSigner;
    address accountant;
    EnumerableSet.AddressSet vaults;
    mapping(bytes4 => address) moduleImplementations;
}

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library AlephVaultFactoryStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.vault.factory")) - 1;

    function load() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        uint256 _position = STORAGE_POSITION;
        assembly {
            sd.slot := _position
        }
    }
}
