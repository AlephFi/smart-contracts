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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IFeeRecipient {
    event OperationsMultisigSet(address _operationsMultisig);
    event VaultFactorySet(address _vaultFactory);
    event AlephTreasurySet(address _alephTreasury);
    event VaultTreasurySet(address _vault, address _vaultTreasury);
    event ManagementFeeCutSet(address _vault, uint32 _managementFeeCut);
    event PerformanceFeeCutSet(address _vault, uint32 _performanceFeeCut);
    event FeesCollected(
        address _vault,
        uint256 _managementFeesToCollect,
        uint256 _performanceFeesToCollect,
        uint256 _vaultFee,
        uint256 _alephFee
    );

    error InvalidInitializationParams();
    error InvalidVault();
    error InvalidManager();
    error InvalidVaultTreasury();
    error VaultTreasuryNotSet();
    error FeesNotCollected();

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
