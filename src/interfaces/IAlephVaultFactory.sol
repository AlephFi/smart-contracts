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
    error InvalidInitializationParams();
    error InvalidParam();
    error UnsupportedChain();

    event VaultDeployed(address indexed vault, address indexed manager, string name, string configId);

    struct InitializationParams {
        address beacon;
        address oracle;
        address guardian;
        address feeRecipient;
        uint32 managementFee;
        uint32 performanceFee;
    }

    /**
     * @notice Returns if a vault is valid.
     * @param _vault The address of the vault.
     * @return True if the vault is valid, false otherwise.
     */
    function isValidVault(address _vault) external view returns (bool);

    /**
     * @notice Deploys a new vault.
     * @param _userInitializationParams Struct containing all user initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.UserInitializationParams calldata _userInitializationParams)
        external
        returns (address);

    /**
     * @notice Sets the oracle.
     * @param _oracle The address of the oracle.
     */
    function setOracle(address _oracle) external;

    /**
     * @notice Sets the guardian.
     * @param _guardian The address of the guardian.
     */
    function setGuardian(address _guardian) external;

    /**
     * @notice Sets the fee recipient.
     * @param _feeRecipient The address of the fee recipient.
     */
    function setFeeRecipient(address _feeRecipient) external;

    /**
     * @notice Sets the management fee.
     * @param _managementFee The management fee.
     */
    function setManagementFee(uint32 _managementFee) external;

    /**
     * @notice Sets the performance fee.
     * @param _performanceFee The performance fee.
     */
    function setPerformanceFee(uint32 _performanceFee) external;
}
