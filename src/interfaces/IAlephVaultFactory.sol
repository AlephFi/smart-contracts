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
    event FeeRecipientSet(address indexed feeRecipient);
    event ManagementFeeSet(uint32 indexed managementFee);
    event PerformanceFeeSet(uint32 indexed performanceFee);
    event ModuleImplementationSet(bytes4 indexed module, address indexed implementation);

    struct InitializationParams {
        address beacon;
        address operationsMultisig;
        address oracle;
        address guardian;
        address authSigner;
        address feeRecipient;
        address alephVaultDepositImplementation;
        address alephVaultRedeemImplementation;
        address alephVaultSettlementImplementation;
        address feeManagerImplementation;
        address migrationManagerImplementation;
    }

    /**
     * @notice Returns if a vault is valid.
     * @param _vault The address of the vault.
     * @return True if the vault is valid, false otherwise.
     */
    function isValidVault(address _vault) external view returns (bool);

    /**
     * @notice Sets if the vault is auth enabled.
     * @param _isAuthEnabled The new status of the KYC authentication.
     */
    function setIsAuthEnabled(bool _isAuthEnabled) external;

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
     * @notice Sets the KYC authentication signer.
     * @param _authSigner The address of the KYC authentication signer.
     */
    function setAuthSigner(address _authSigner) external;

    /**
     * @notice Sets the fee recipient.
     * @param _feeRecipient The address of the fee recipient.
     */
    function setFeeRecipient(address _feeRecipient) external;

    /**
     * @notice Sets the module implementation.
     * @param _module The module.
     * @param _implementation The implementation.
     */
    function setModuleImplementation(bytes4 _module, address _implementation) external;
}
