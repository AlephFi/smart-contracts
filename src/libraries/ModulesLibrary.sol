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
library ModulesLibrary {
    bytes4 internal constant ALEPH_VAULT_DEPOSIT = bytes4(keccak256("ALEPH_VAULT_DEPOSIT"));
    bytes4 internal constant ALEPH_VAULT_REDEEM = bytes4(keccak256("ALEPH_VAULT_REDEEM"));
    bytes4 internal constant ALEPH_VAULT_SETTLEMENT = bytes4(keccak256("ALEPH_VAULT_SETTLEMENT"));
    bytes4 internal constant FEE_MANAGER = bytes4(keccak256("FEE_MANAGER"));
}
