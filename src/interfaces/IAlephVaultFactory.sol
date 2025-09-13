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

import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IAlephVaultFactory {
    error InvalidInitializationParams();
    error InvalidParam();
    error UnsupportedChain();

    event VaultDeployed(address indexed vault, address indexed manager, string name, string configId);
    event IsAuthEnabledSet(bool indexed isAuthEnabled);
    event OperationsMultisigSet(address indexed operationsMultisig);
    event OracleSet(address indexed oracle);
    event GuardianSet(address indexed guardian);
    event AuthSignerSet(address indexed authSigner);
    event ManagementFeeSet(uint32 indexed managementFee);
    event PerformanceFeeSet(uint32 indexed performanceFee);
    event ModuleImplementationSet(bytes4 indexed module, address indexed implementation);

    struct InitializationParams {
        address beacon;
        address operationsMultisig;
        address oracle;
        address guardian;
        address authSigner;
        address accountant;
        address alephVaultDepositImplementation;
        address alephVaultRedeemImplementation;
        address alephVaultSettlementImplementation;
        address feeManagerImplementation;
        address migrationManagerImplementation;
    }

    /**
     * @notice Checks if an address is a valid vault deployed by this factory
     * @param _vault The address to check
     * @return True if the vault was deployed by this factory, false otherwise
     */
    function isValidVault(address _vault) external view returns (bool);

    /**
     * @notice Sets whether authentication is enabled for vault deployment
     * @param _isAuthEnabled True to enable authentication, false to disable
     * @dev Only callable by OPERATIONS_MULTISIG role
     */
    function setIsAuthEnabled(bool _isAuthEnabled) external;

    /**
     * @notice Updates the operations multisig address for the factory and all deployed vaults
     * @param _operationsMultisig The new operations multisig address
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setOperationsMultisig(address _operationsMultisig) external;

    /**
     * @notice Deploys a new vault.
     * @param _userInitializationParams Struct containing all user initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.UserInitializationParams calldata _userInitializationParams)
        external
        returns (address);

    /**
     * @notice Updates the oracle address for all deployed vaults
     * @param _oracle The new oracle address
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setOracle(address _oracle) external;

    /**
     * @notice Updates the guardian address for all deployed vaults
     * @param _guardian The new guardian address
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setGuardian(address _guardian) external;

    /**
     * @notice Updates the authentication signer address for vault deployment
     * @param _authSigner The new authentication signer address
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setAuthSigner(address _authSigner) external;

    /**
     * @notice Updates a module implementation address for all deployed vaults
     * @param _module The module identifier to update
     * @param _implementation The new implementation address for the module
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setModuleImplementation(bytes4 _module, address _implementation) external;
}
