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
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {RolesLibrary} from "./RolesLibrary.sol";
import {AlephVaultDeposit} from "./AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "./AlephVaultRedeem.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVault is IAlephVault, AlephVaultDeposit, AlephVaultRedeem, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    /**
     * @notice Initializes the vault with the given parameters.
     * @param _initalizationParams Struct containing all initialization parameters.
     */
    function initialize(InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    /**
     * @dev Internal function to set up vault storage and roles.
     * @param _initalizationParams Struct containing all initialization parameters.
     */
    function _initialize(InitializationParams calldata _initalizationParams) internal onlyInitializing {
        AlephVaultStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (
            _initalizationParams.admin == address(0) || _initalizationParams.operationsMultisig == address(0)
                || _initalizationParams.oracle == address(0) || _initalizationParams.erc20 == address(0)
                || _initalizationParams.custodian == address(0) || _initalizationParams.batchDuration == 0
                || _initalizationParams.guardian == address(0)
        ) {
            revert InvalidInitializationParams();
        }
        _sd.admin = _initalizationParams.admin;
        _sd.operationsMultisig = _initalizationParams.operationsMultisig;
        _sd.guardian = _initalizationParams.guardian;
        _sd.oracle = _initalizationParams.oracle;
        _sd.erc20 = _initalizationParams.erc20;
        _sd.custodian = _initalizationParams.custodian;
        _sd.batchDuration = _initalizationParams.batchDuration;
        _sd.startTimeStamp = Time.timestamp();
        _grantRole(RolesLibrary.ORACLE, _initalizationParams.oracle);
        _grantRole(RolesLibrary.GUARDIAN, _initalizationParams.guardian);
    }

    /**
     * @notice Returns the current batch ID based on the elapsed time since start.
     * @return The current batch ID.
     */
    function currentBatch() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint48) {
        AlephVaultStorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / _sd.batchDuration;
    }

    /**
     * @notice Returns the total assets currently held by the vault.
     * @return The total assets.
     */
    function totalAssets() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint256) {
        return _getStorage().assets.latest();
    }

    /**
     * @notice Returns the total shares currently issued by the vault.
     * @return The total shares.
     */
    function totalShares() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint256) {
        return _getStorage().shares.latest();
    }

    /**
     * @notice Returns the total assets at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The total assets at the given timestamp.
     */
    function assetsAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().assets.upperLookupRecent(_timestamp);
    }

    /**
     * @notice Returns the total shares at a specific timestamp.
     * @param _timestamp The timestamp to query.
     * @return The total shares at the given timestamp.
     */
    function sharesAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().shares.upperLookupRecent(_timestamp);
    }

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _user The address of the user.
     * @return The number of shares owned by the user.
     */
    function sharesOf(address _user)
        public
        view
        override(AlephVaultRedeem, AlephVaultDeposit, IAlephVault)
        returns (uint256)
    {
        return _getStorage().sharesOf[_user].latest();
    }

    /**
     * @notice Returns the amount of assets claimable by a user based on their shares.
     * @param _user The address of the user.
     * @return The amount of assets claimable by the user.
     */
    function assetsOf(address _user) public view returns (uint256) {
        return ERC4626Math.previewRedeem(sharesOf(_user), totalAssets(), totalShares());
    }

    /**
     * @notice Returns the amount of assets claimable by a user at a specific timestamp.
     * @param _user The address of the user.
     * @param _timestamp The timestamp to query.
     * @return The amount of assets claimable by the user at the given timestamp.
     */
    function assetsOfAt(address _user, uint48 _timestamp) public view returns (uint256) {
        return ERC4626Math.previewRedeem(sharesOfAt(_user, _timestamp), assetsAt(_timestamp), sharesAt(_timestamp));
    }

    /**
     * @notice Returns the number of shares owned by a user at a specific timestamp.
     * @param _user The address of the user.
     * @param _timestamp The timestamp to query.
     * @return The number of shares owned by the user at the given timestamp.
     */
    function sharesOfAt(address _user, uint48 _timestamp) public view returns (uint256) {
        return _getStorage().sharesOf[_user].upperLookupRecent(_timestamp);
    }

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleDeposit(uint256 _newTotalAssets)
        external
        override(AlephVaultDeposit)
        onlyRole(RolesLibrary.ORACLE)
    {
        _settleDeposit(_newTotalAssets);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(uint256 _newTotalAssets) external override(AlephVaultRedeem) onlyRole(RolesLibrary.ORACLE) {
        _settleRedeem(_newTotalAssets);
    }

    /**
     * @dev Returns the storage struct for the vault.
     * @return sd The storage struct.
     */
    function _getStorage()
        internal
        pure
        override(AlephVaultDeposit, AlephVaultRedeem)
        returns (AlephVaultStorageData storage sd)
    {
        return AlephVaultStorage.load();
    }
}
