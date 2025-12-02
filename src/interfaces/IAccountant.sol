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
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IAccountant {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the operations multisig is set.
     * @param operationsMultisig The new operations multisig.
     */
    event OperationsMultisigSet(address operationsMultisig);

    /**
     * @notice Emitted when the vault factory is set.
     * @param vaultFactory The new vault factory.
     */
    event VaultFactorySet(address vaultFactory);

    /**
     * @notice Emitted when the aleph treasury is set.
     * @param alephTreasury The new aleph treasury.
     */
    event AlephTreasurySet(address alephTreasury);

    /**
     * @notice Emitted when the vault treasury is set.
     * @param vault The vault.
     * @param vaultTreasury The new vault treasury.
     */
    event VaultTreasurySet(address vault, address vaultTreasury);

    /**
     * @notice Emitted when the management fee cut is set.
     * @param vault The vault.
     * @param managementFeeCut The new management fee cut.
     */
    event ManagementFeeCutSet(address vault, uint32 managementFeeCut);

    /**
     * @notice Emitted when the performance fee cut is set.
     * @param vault The vault.
     * @param performanceFeeCut The new performance fee cut.
     */
    event PerformanceFeeCutSet(address vault, uint32 performanceFeeCut);

    /**
     * @notice Emitted when the operator fee cut is set.
     * @param vault The vault.
     * @param operatorFeeCut The new operator fee cut.
     */
    event OperatorFeeCutSet(address vault, uint32 operatorFeeCut);

    /**
     * @notice Emitted when the operator allocations are set.
     * @param vault The vault.
     * @param operator The operator.
     * @param allocatedAmount The allocated amount.
     */
    event OperatorAllocationsSet(address vault, address operator, uint256 allocatedAmount);

    /**
     * @notice Emitted when operator fees are distributed to an operator.
     * @param vault The vault.
     * @param operator The operator receiving the fee.
     * @param operatorFee The fee amount distributed to the operator.
     */
    event OperatorFeeDistributed(address vault, address operator, uint256 operatorFee);

    /**
     * @notice Emitted when fees are collected.
     * @param vault The vault.
     * @param managementFeesToCollect The management fees to collect.
     * @param performanceFeesToCollect The performance fees to collect.
     * @param vaultFee The vault fee split
     * @param alephFee The aleph fee split
     * @param operatorsFee The fees for the operators.
     */
    event FeesCollected(
        address vault,
        uint256 managementFeesToCollect,
        uint256 performanceFeesToCollect,
        uint256 vaultFee,
        uint256 alephFee,
        uint256[] operatorsFee
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
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
     * @notice Emitted when the operator fee cut is invalid.
     */
    error InvalidOperatorFeeCut();

    /**
     * @notice Emitted when the operator allocation input is invalid.
     */
    error InvalidOperatorAllocation();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initialization params.
     * @param operationsMultisig The operations multisig.
     * @param alephTreasury The aleph treasury.
     */
    struct InitializationParams {
        address operationsMultisig;
        address alephTreasury;
    }

    /**
     * @notice Operator allocations.
     * @param totalOperatorAllocations The total operator allocations.
     * @param operators The operators.
     * @param allocatedAmount The allocated amount by each operator.
     */
    struct OperatorAllocations {
        uint256 totalOperatorAllocations;
        EnumerableSet.AddressSet operators;
        mapping(address operator => uint256 allocatedAmount) allocatedAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the vault treasury of the caller.
     * @return The vault treasury.
     */
    function vaultTreasury() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
     * @notice Sets the aleph avs.
     * @param _alephAvs The new aleph avs.
     */
    function setAlephAvs(address _alephAvs) external;

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
     * @notice Sets the operator fee cut.
     * @param _vault The vault to set the operator fee cut for.
     * @param _operatorFeeCut The new operator fee cut.
     */
    function setOperatorFeeCut(address _vault, uint32 _operatorFeeCut) external;

    /**
     * @notice Sets the operator allocations.
     * @param _vault The vault to set the operator allocations for.
     * @param _operator The operator to set the allocations for.
     * @param _allocatedAmount The new allocated amount.
     */
    function setOperatorAllocations(address _vault, address _operator, uint256 _allocatedAmount) external;

    /*//////////////////////////////////////////////////////////////
                            FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Collects all pending fees from a given vault.
     * @param _vault The vault to collect fees from.
     */
    function collectFees(address _vault) external;
}
