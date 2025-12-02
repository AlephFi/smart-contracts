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

import {
    AccessControlUpgradeable
} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {AccountantStorage, AccountantStorageData} from "@aleph-vault/AccountantStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract Accountant is IAccountant, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice The denominator for the fee rates (basis points).
     */
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the vault with the given parameters.
     * @param _initializationParams Struct containing all initialization parameters.
     */
    function initialize(InitializationParams calldata _initializationParams) public initializer {
        _initialize(_initializationParams);
    }

    function _initialize(InitializationParams calldata _initializationParams) internal onlyInitializing {
        AccountantStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (_initializationParams.operationsMultisig == address(0) || _initializationParams.alephTreasury == address(0))
        {
            revert InvalidInitializationParams();
        }
        _sd.operationsMultisig = _initializationParams.operationsMultisig;
        _sd.alephTreasury = _initializationParams.alephTreasury;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initializationParams.operationsMultisig);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAccountant
    function vaultTreasury() external view returns (address) {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, msg.sender);
        return _sd.vaultTreasury[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initializeVaultTreasury(address _vault, address _vaultTreasury)
        external
        onlyRole(RolesLibrary.VAULT_FACTORY)
    {
        if (_vaultTreasury == address(0)) {
            revert InvalidVaultTreasury();
        }
        _getStorage().vaultTreasury[_vault] = _vaultTreasury;
        emit VaultTreasurySet(_vault, _vaultTreasury);
    }

    /// @inheritdoc IAccountant
    function setOperationsMultisig(address _newOperationsMultisig) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        AccountantStorageData storage _sd = _getStorage();
        address _oldOperationsMultisig = _sd.operationsMultisig;
        _sd.operationsMultisig = _newOperationsMultisig;
        _revokeRole(RolesLibrary.OPERATIONS_MULTISIG, _oldOperationsMultisig);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _newOperationsMultisig);
        emit OperationsMultisigSet(_newOperationsMultisig);
    }

    /// @inheritdoc IAccountant
    function setVaultFactory(address _newVaultFactory) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        AccountantStorageData storage _sd = _getStorage();
        address _oldVaultFactory = _sd.vaultFactory;
        _sd.vaultFactory = _newVaultFactory;
        _revokeRole(RolesLibrary.VAULT_FACTORY, _oldVaultFactory);
        _grantRole(RolesLibrary.VAULT_FACTORY, _newVaultFactory);
        emit VaultFactorySet(_newVaultFactory);
    }

    /// @inheritdoc IAccountant
    function setAlephTreasury(address _newAlephTreasury) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().alephTreasury = _newAlephTreasury;
        emit AlephTreasurySet(_newAlephTreasury);
    }

    /// @inheritdoc IAccountant
    function setVaultTreasury(address _vaultTreasury) external {
        AccountantStorageData storage _sd = _getStorage();
        if (_vaultTreasury == address(0)) {
            revert InvalidVaultTreasury();
        }
        _validateVault(_sd, msg.sender);
        _sd.vaultTreasury[msg.sender] = _vaultTreasury;
        emit VaultTreasurySet(msg.sender, _vaultTreasury);
    }

    function setAlephAvs(address _alephAvs) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _grantRole(RolesLibrary.ALEPH_AVS, _alephAvs);
    }

    /// @inheritdoc IAccountant
    function setManagementFeeCut(address _vault, uint32 _managementFeeCut)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _sd.managementFeeCut[_vault] = _managementFeeCut;
        emit ManagementFeeCutSet(_vault, _managementFeeCut);
    }

    /// @inheritdoc IAccountant
    function setPerformanceFeeCut(address _vault, uint32 _performanceFeeCut)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _sd.performanceFeeCut[_vault] = _performanceFeeCut;
        emit PerformanceFeeCutSet(_vault, _performanceFeeCut);
    }

    /// @inheritdoc IAccountant
    function setOperatorFeeCut(address _vault, uint32 _operatorFeeCut)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        if (uint256(_operatorFeeCut) > BPS_DENOMINATOR) {
            revert InvalidOperatorFeeCut();
        }
        _sd.operatorFeeCut[_vault] = _operatorFeeCut;
        emit OperatorFeeCutSet(_vault, _operatorFeeCut);
    }

    /// @inheritdoc IAccountant
    function setOperatorAllocations(address _vault, address _operator, uint256 _allocatedAmount)
        external
        onlyRole(RolesLibrary.ALEPH_AVS)
    {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        if (_allocatedAmount == 0) {
            revert InvalidOperatorAllocation();
        }
        IAccountant.OperatorAllocations storage _operatorAllocations = _sd.operatorAllocatedAmount[_vault];
        _operatorAllocations.operators.add(_operator);
        _operatorAllocations.allocatedAmount[_operator] += _allocatedAmount;
        _operatorAllocations.totalOperatorAllocations += _allocatedAmount;
        emit OperatorAllocationsSet(_vault, _operator, _allocatedAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAccountant
    function collectFees(address _vault) external {
        AccountantStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _validateManager(_vault);
        address _vaultTreasury = _sd.vaultTreasury[_vault];
        if (_vaultTreasury == address(0)) {
            revert VaultTreasuryNotSet();
        }
        address _underlyingToken = IAlephVault(_vault).underlyingToken();
        uint256 _balanceBefore = IERC20(_underlyingToken).balanceOf(address(this));
        (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect) = IFeeManager(_vault).collectFees();
        uint256 _balanceAfter = IERC20(_underlyingToken).balanceOf(address(this));
        if (_balanceAfter - _balanceBefore != _managementFeesToCollect + _performanceFeesToCollect) {
            revert FeesNotCollected();
        }
        (uint256 _vaultFee, uint256 _alephFee, uint256[] memory _operatorsFee) = _splitFees(
            _sd, _vault, _vaultTreasury, _underlyingToken, _managementFeesToCollect, _performanceFeesToCollect
        );
        emit FeesCollected(
            _vault, _managementFeesToCollect, _performanceFeesToCollect, _vaultFee, _alephFee, _operatorsFee
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Splits the fees for the vault and the aleph treasury.
     * @param _sd The storage struct.
     * @param _vault The vault to collect fees from.
     * @param _vaultTreasury The treasury of the vault.
     * @param _underlyingToken The underlying token of the vault.
     * @param _managementFeesToCollect The management fees to collect.
     * @param _performanceFeesToCollect The performance fees to collect.
     * @return _vaultFee The fee for the vault.
     * @return _alephFee The fee for the aleph treasury.
     * @return _operatorsFee The fees for the operators.
     */
    function _splitFees(
        AccountantStorageData storage _sd,
        address _vault,
        address _vaultTreasury,
        address _underlyingToken,
        uint256 _managementFeesToCollect,
        uint256 _performanceFeesToCollect
    ) internal returns (uint256 _vaultFee, uint256 _alephFee, uint256[] memory _operatorsFee) {
        uint256 _alephManagementFee =
            _managementFeesToCollect.mulDiv(uint256(_sd.managementFeeCut[_vault]), BPS_DENOMINATOR, Math.Rounding.Ceil);
        uint256 _alephPerformanceFee = _performanceFeesToCollect.mulDiv(
            uint256(_sd.performanceFeeCut[_vault]), BPS_DENOMINATOR, Math.Rounding.Ceil
        );
        _alephFee = _alephManagementFee + _alephPerformanceFee;
        (_vaultFee, _operatorsFee) = _splitFeesForOperators(
            _sd, _vault, _underlyingToken, _managementFeesToCollect + _performanceFeesToCollect - _alephFee
        );
        IERC20(_underlyingToken).safeTransfer(_vaultTreasury, _vaultFee);
        IERC20(_underlyingToken).safeTransfer(_sd.alephTreasury, _alephFee);
    }

    /**
     * @dev Splits the fees for the operators.
     * @param _sd The storage struct.
     * @param _vault The vault to collect fees from.
     * @param _remainingFees The remaining fees to split.
     * @return _vaultFee The fee for the vault.
     * @return _operatorsFee The fees for the operators.
     */
    function _splitFeesForOperators(
        AccountantStorageData storage _sd,
        address _vault,
        address _underlyingToken,
        uint256 _remainingFees
    ) internal returns (uint256 _vaultFee, uint256[] memory _operatorsFee) {
        IAccountant.OperatorAllocations storage _operatorAllocations = _sd.operatorAllocatedAmount[_vault];
        uint256 _totalOperatorAllocations = _operatorAllocations.totalOperatorAllocations;
        uint256 _length = _operatorAllocations.operators.length();
        _operatorsFee = new uint256[](_length);
        
        // If there are no operators or totalOperatorAllocations is 0, skip operator fee distribution
        // This prevents division by zero and avoids unnecessary calculations
        // All fees go to the vault in this case
        if (_length == 0 || _totalOperatorAllocations == 0) {
            return (_remainingFees, _operatorsFee);
        }
        
        uint32 _operatorFeeCut = _sd.operatorFeeCut[_vault];
        uint256 _totalOperatorFeesToCollect =
            _remainingFees.mulDiv(uint256(_operatorFeeCut), BPS_DENOMINATOR, Math.Rounding.Floor);
        
        for (uint256 i = 0; i < _length; i++) {
            address _operator = _operatorAllocations.operators.at(i);
            uint256 _operatorFee = _totalOperatorFeesToCollect.mulDiv(
                _operatorAllocations.allocatedAmount[_operator], _totalOperatorAllocations, Math.Rounding.Floor
            );
            _operatorsFee[i] = _operatorFee;
            IERC20(_underlyingToken).safeTransfer(_operator, _operatorFee);
        }
        return (_remainingFees - _totalOperatorFeesToCollect, _operatorsFee);
    }

    function _validateVault(AccountantStorageData storage _sd, address _vault) internal view {
        if (!IAlephVaultFactory(_sd.vaultFactory).isValidVault(_vault)) {
            revert InvalidVault();
        }
    }

    function _validateManager(address _vault) internal view {
        if (!AccessControlUpgradeable(_vault).hasRole(RolesLibrary.MANAGER, msg.sender)) {
            revert InvalidManager();
        }
    }

    /**
     * @dev Returns the storage struct for the accountant.
     * @return _sd The storage struct.
     */
    function _getStorage() internal pure returns (AccountantStorageData storage _sd) {
        _sd = AccountantStorage.load();
    }
}
