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

import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {IFeeRecipient} from "@aleph-vault/interfaces/IFeeRecipient.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {FeeRecipientStorage, FeeRecipientStorageData} from "@aleph-vault/FeeRecipientStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract FeeRecipient is IFeeRecipient, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant BPS_DENOMINATOR = 10_000;

    /**
     * @notice Initializes the vault with the given parameters.
     * @param _initializationParams Struct containing all initialization parameters.
     */
    function initialize(InitializationParams calldata _initializationParams) public initializer {
        _initialize(_initializationParams);
    }

    function _initialize(InitializationParams calldata _initializationParams) internal onlyInitializing {
        FeeRecipientStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (_initializationParams.operationsMultisig == address(0) || _initializationParams.alephTreasury == address(0))
        {
            revert InvalidInitializationParams();
        }
        _sd.operationsMultisig = _initializationParams.operationsMultisig;
        _sd.alephTreasury = _initializationParams.alephTreasury;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initializationParams.operationsMultisig);
    }

    /// @inheritdoc IFeeRecipient
    function vaultTreasury() external view returns (address) {
        FeeRecipientStorageData storage _sd = _getStorage();
        _validateVault(_sd, msg.sender);
        return _sd.vaultTreasury[msg.sender];
    }

    /// @inheritdoc IFeeRecipient
    function setOperationsMultisig(address _newOperationsMultisig)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        FeeRecipientStorageData storage _sd = _getStorage();
        address _oldOperationsMultisig = _sd.operationsMultisig;
        _sd.operationsMultisig = _newOperationsMultisig;
        _revokeRole(RolesLibrary.OPERATIONS_MULTISIG, _oldOperationsMultisig);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _newOperationsMultisig);
        emit OperationsMultisigSet(_newOperationsMultisig);
    }

    /// @inheritdoc IFeeRecipient
    function setVaultFactory(address _vaultFactory) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().vaultFactory = _vaultFactory;
        emit VaultFactorySet(_vaultFactory);
    }

    /// @inheritdoc IFeeRecipient
    function setAlephTreasury(address _newAlephTreasury) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().alephTreasury = _newAlephTreasury;
        emit AlephTreasurySet(_newAlephTreasury);
    }

    /// @inheritdoc IFeeRecipient
    function setVaultTreasury(address _vaultTreasury) external {
        FeeRecipientStorageData storage _sd = _getStorage();
        if (_vaultTreasury == address(0)) {
            revert InvalidVaultTreasury();
        }
        _validateVault(_sd, msg.sender);
        _sd.vaultTreasury[msg.sender] = _vaultTreasury;
        emit VaultTreasurySet(msg.sender, _vaultTreasury);
    }

    /// @inheritdoc IFeeRecipient
    function setManagementFeeCut(address _vault, uint32 _managementFeeCut)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        FeeRecipientStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _sd.managementFeeCut[_vault] = _managementFeeCut;
        emit ManagementFeeCutSet(_vault, _managementFeeCut);
    }

    /// @inheritdoc IFeeRecipient
    function setPerformanceFeeCut(address _vault, uint32 _performanceFeeCut)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        FeeRecipientStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _sd.performanceFeeCut[_vault] = _performanceFeeCut;
        emit PerformanceFeeCutSet(_vault, _performanceFeeCut);
    }

    /// @inheritdoc IFeeRecipient
    function collectFees(address _vault) external {
        FeeRecipientStorageData storage _sd = _getStorage();
        _validateVault(_sd, _vault);
        _validateManager(_sd, _vault);
        address _vaultTreasury = _sd.vaultTreasury[_vault];
        if (_vaultTreasury == address(0)) {
            revert VaultTreasuryNotSet();
        }
        (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect) = IFeeManager(_vault).collectFees();
        (uint256 _vaultFee, uint256 _alephFee) =
            _splitFees(_sd, _vault, _vaultTreasury, _managementFeesToCollect, _performanceFeesToCollect);
        emit FeesCollected(_vault, _managementFeesToCollect, _performanceFeesToCollect, _vaultFee, _alephFee);
    }

    /**
     * @dev Splits the fees for the vault and the aleph treasury.
     * @param _sd The storage struct.
     * @param _vault The vault to collect fees from.
     * @param _managementFeesToCollect The management fees to collect.
     * @param _performanceFeesToCollect The performance fees to collect.
     * @return _vaultFee The fee for the vault.
     * @return _alephFee The fee for the aleph treasury.
     */
    function _splitFees(
        FeeRecipientStorageData storage _sd,
        address _vault,
        address _vaultTreasury,
        uint256 _managementFeesToCollect,
        uint256 _performanceFeesToCollect
    ) internal returns (uint256 _vaultFee, uint256 _alephFee) {
        address _underlyingToken = IAlephVault(_vault).underlyingToken();
        IERC20(_underlyingToken).safeTransferFrom(
            _vault, address(this), _managementFeesToCollect + _performanceFeesToCollect
        );
        uint256 _alephManagementFee =
            _managementFeesToCollect.mulDiv(uint256(_sd.managementFeeCut[_vault]), BPS_DENOMINATOR, Math.Rounding.Ceil);
        uint256 _alephPerformanceFee = _performanceFeesToCollect.mulDiv(
            uint256(_sd.performanceFeeCut[_vault]), BPS_DENOMINATOR, Math.Rounding.Ceil
        );
        _alephFee = _alephManagementFee + _alephPerformanceFee;
        _vaultFee = _managementFeesToCollect + _performanceFeesToCollect - _alephFee;
        IERC20(_underlyingToken).safeTransfer(_vaultTreasury, _vaultFee);
        IERC20(_underlyingToken).safeTransfer(_sd.alephTreasury, _alephFee);
    }

    function _validateVault(FeeRecipientStorageData storage _sd, address _vault) internal view {
        if (!IAlephVaultFactory(_sd.vaultFactory).isValidVault(_vault)) {
            revert InvalidVault();
        }
    }

    function _validateManager(FeeRecipientStorageData storage _sd, address _vault) internal view {
        if (!AccessControlUpgradeable(_vault).hasRole(RolesLibrary.MANAGER, msg.sender)) {
            revert InvalidManager();
        }
    }

    /**
     * @dev Returns the storage struct for the fee recipient.
     * @return _sd The storage struct.
     */
    function _getStorage() internal pure returns (FeeRecipientStorageData storage _sd) {
        _sd = FeeRecipientStorage.load();
    }
}
