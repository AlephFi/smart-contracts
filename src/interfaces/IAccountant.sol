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
interface IAccountant {
    /**
     * @notice Emitted when the operations multisig is set.
     * @param _operationsMultisig The new operations multisig.
     */
    event OperationsMultisigSet(address _operationsMultisig);

    /**
     * @notice Emitted when the vault factory is set.
     * @param _vaultFactory The new vault factory.
     */
    event VaultFactorySet(address _vaultFactory);

    /**
     * @notice Emitted when the aleph treasury is set.
     * @param _alephTreasury The new aleph treasury.
     */
    event AlephTreasurySet(address _alephTreasury);

    /**
     * @notice Emitted when the vault treasury is set.
     * @param _vault The vault.
     * @param _vaultTreasury The new vault treasury.
     */
    event VaultTreasurySet(address _vault, address _vaultTreasury);

    /**
     * @notice Emitted when the management fee cut is set.
     * @param _vault The vault.
     * @param _managementFeeCut The new management fee cut.
     */
    event ManagementFeeCutSet(address _vault, uint32 _managementFeeCut);

    /**
     * @notice Emitted when the performance fee cut is set.
     * @param _vault The vault.
     * @param _performanceFeeCut The new performance fee cut.
     */
    event PerformanceFeeCutSet(address _vault, uint32 _performanceFeeCut);

    /**
     * @notice Emitted when fees are collected.
     * @param _vault The vault.
     * @param _managementFeesToCollect The management fees to collect.
     * @param _performanceFeesToCollect The performance fees to collect.
     * @param _vaultFee The vault fee split
     * @param _alephFee The aleph fee split
     */
    event FeesCollected(
        address _vault,
        uint256 _managementFeesToCollect,
        uint256 _performanceFeesToCollect,
        uint256 _vaultFee,
        uint256 _alephFee
    );

    /**
     * @notice Emitted when the initialization params are invalid.
     */
    error InvalidInitializationParams();

    /**
     * @notice Emitted when the vault is invalid.
     */
    error InvalidVault();

    /**
     * @notice Emitted when the manager is invalid.
     */
    error InvalidManager();

    /**
     * @notice Emitted when the vault treasury is invalid.
     */
    error InvalidVaultTreasury();

    /**
     * @notice Emitted when the vault treasury is not set.
     */
    error VaultTreasuryNotSet();

    /**
     * @notice Emitted when fees are not collected.
     */
    error FeesNotCollected();

    /**
     * @notice Initialization params.
     * @param _operationsMultisig The operations multisig.
     * @param _alephTreasury The aleph treasury.
     */
    struct InitializationParams {
        address operationsMultisig;
        address alephTreasury;
    }

    /**
     * @notice Returns the vault treasury of the caller.
     * @return The vault treasury.
     */
    function vaultTreasury() external view returns (address);

    /**
     * @notice Initializes the vault treasury.
     * @param _vault The vault to initialize the treasury for.
     * @param _vaultTreasury The new vault treasury.
     */
    function initializeVaultTreasury(address _vault, address _vaultTreasury) external;

    /**
     * @notice Sets the operations multisig.
     * @param _operationsMultisig The new operations multisig.
     */
    function setOperationsMultisig(address _operationsMultisig) external;

    /**
     * @notice Sets the vault factory.
     * @param _vaultFactory The new vault factory.
     */
    function setVaultFactory(address _vaultFactory) external;

    /**
     * @notice Sets the aleph treasury.
     * @param _alephTreasury The new aleph treasury.
     */
    function setAlephTreasury(address _alephTreasury) external;

    /**
     * @notice Sets the vault treasury.
     * @param _vaultTreasury The new vault treasury.
     */
    function setVaultTreasury(address _vaultTreasury) external;

    /**
     * @notice Sets the management fee cut.
     * @param _vault The vault to set the management fee cut for.
     * @param _managementFeeCut The new management fee cut.
     */
    function setManagementFeeCut(address _vault, uint32 _managementFeeCut) external;

    /**
     * @notice Sets the performance fee cut.
     * @param _vault The vault to set the performance fee cut for.
     * @param _performanceFeeCut The new performance fee cut.
     */
    function setPerformanceFeeCut(address _vault, uint32 _performanceFeeCut) external;

    /**
     * @notice Collects all pending fees from a given vault.
     * @param _vault The vault to collect fees from.
     */
    function collectFees(address _vault) external;
}
