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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library ModulesLibrary {
    /**
     * @notice The module for the aleph vault deposit.
     */
    bytes4 internal constant ALEPH_VAULT_DEPOSIT = bytes4(keccak256("ALEPH_VAULT_DEPOSIT"));
    /**
     * @notice The module for the aleph vault redeem.
     */
    bytes4 internal constant ALEPH_VAULT_REDEEM = bytes4(keccak256("ALEPH_VAULT_REDEEM"));
    /**
     * @notice The module for the aleph vault settlement.
     */
    bytes4 internal constant ALEPH_VAULT_SETTLEMENT = bytes4(keccak256("ALEPH_VAULT_SETTLEMENT"));
    /**
     * @notice The module for the fee manager.
     */
    bytes4 internal constant FEE_MANAGER = bytes4(keccak256("FEE_MANAGER"));
    /**
     * @notice The module for the migration manager.
     */
    bytes4 internal constant MIGRATION_MANAGER = bytes4(keccak256("MIGRATION_MANAGER"));
}
