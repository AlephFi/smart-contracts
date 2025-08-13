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
library RolesLibrary {
    bytes4 internal constant ORACLE = bytes4(keccak256("ORACLE"));
    bytes4 internal constant GUARDIAN = bytes4(keccak256("GUARDIAN"));
    bytes4 internal constant MANAGER = bytes4(keccak256("MANAGER"));
    bytes4 internal constant OPERATIONS_MULTISIG = bytes4(keccak256("OPERATIONS_MULTISIG"));
    bytes4 internal constant VAULT_FACTORY = bytes4(keccak256("VAULT_FACTORY"));
}
