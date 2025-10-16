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
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a vault is deployed.
     * @param vault The address of the deployed vault.
     * @param manager The address of the manager.
     * @param name The name of the vault.
     * @param configId The config ID of the vault.
     */
    event VaultDeployed(address indexed vault, address indexed manager, string name, string configId);

    /**
     * @notice Emitted when the operations multisig is set.
     * @param operationsMultisig The new operations multisig.
     */
    event OperationsMultisigSet(address indexed operationsMultisig);

    /**
     * @notice Emitted when the oracle is set.
     * @param oracle The new oracle.
     */
    event OracleSet(address indexed oracle);

    /**
     * @notice Emitted when the guardian is set.
     * @param guardian The new guardian.
     */
    event GuardianSet(address indexed guardian);

    /**
     * @notice Emitted when the authentication signer is set.
     * @param authSigner The new authentication signer.
     */
    event AuthSignerSet(address indexed authSigner);

    /**
     * @notice Emitted when the management fee is set.
     * @param managementFee The new management fee.
     */
    event ManagementFeeSet(uint32 indexed managementFee);

    /**
     * @notice Emitted when the performance fee is set.
     * @param performanceFee The new performance fee.
     */
    event PerformanceFeeSet(uint32 indexed performanceFee);

    /**
     * @notice Emitted when the module implementation is set.
     * @param module The module identifier.
     * @param implementation The new implementation.
     */
    event ModuleImplementationSet(bytes4 indexed module, address indexed implementation);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the initialization params are invalid.
     */
    error InvalidInitializationParams();

    /**
     * @notice Emitted when the parameter is invalid.
     */
    error InvalidParam();

    /**
     * @notice Emitted when the chain is unsupported.
     */
    error UnsupportedChain();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initialization params.
     * @param beacon The beacon address of the vault.
     * @param operationsMultisig The operations multisig address.
     * @param oracle The oracle address.
     * @param guardian The guardian address.
     * @param authSigner The authentication signer address.
     * @param accountant The accountant proxy address.
     * @param alephVaultDepositImplementation The aleph vault deposit implementation address.
     * @param alephVaultRedeemImplementation The aleph vault redeem implementation address.
     * @param alephVaultSettlementImplementation The aleph vault settlement implementation address.
     * @param feeManagerImplementation The fee manager implementation address.
     * @param migrationManagerImplementation The migration manager implementation address.
     */
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

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Checks if an address is a valid vault deployed by this factory
     * @param _vault The address to check
     * @return True if the vault was deployed by this factory, false otherwise
     */
    function isValidVault(address _vault) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Updates the operations multisig address for the factory and all deployed vaults
     * @param _operationsMultisig The new operations multisig address
     * @dev Only callable by OPERATIONS_MULTISIG role. Updates all deployed vaults.
     */
    function setOperationsMultisig(address _operationsMultisig) external;

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

    /*//////////////////////////////////////////////////////////////
                            DEPLOY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploys a new vault.
     * @param _userInitializationParams Struct containing all user initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.UserInitializationParams calldata _userInitializationParams)
        external
        returns (address);
}
