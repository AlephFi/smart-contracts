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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
interface IAlephVaultFactory {
    error UnsupportedChain();

    event VaultDeployed(address indexed vault, address indexed manager, string name);

    struct InitializationParams {
        address beacon;
    }

    /**
     * @notice Returns if a vault is valid.
     * @param _vault The address of the vault.
     * @return True if the vault is valid, false otherwise.
     */
    function isValidVault(address _vault) external view returns (bool);

    /**
     * @notice Deploys a new vault.
     * @param _initalizationParams Struct containing all initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.InitializationParams calldata _initalizationParams) external returns (address);
}
