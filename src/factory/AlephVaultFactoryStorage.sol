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

struct AlephVaultFactoryStorageData {
    address beacon;
    address operationsMultisig;
    address oracle;
    address guardian;
    address authSigner;
    address feeRecipient;
    uint32 managementFee;
    uint32 performanceFee;
    mapping(address vault => bool isValid) vaults;
    mapping(bytes4 => address) moduleImplementations;
}

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
library AlephVaultFactoryStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.vault.factory")) - 1;

    function load() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        uint256 position = STORAGE_POSITION;
        assembly {
            sd.slot := position
        }
    }
}
