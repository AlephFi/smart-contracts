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
import {IMigrationManager} from "@aleph-vault/interfaces/IMigrationManager.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract MigrationManager is IMigrationManager, AlephVaultBase, AccessControlUpgradeable {
    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IMigrationManager
    function migrateOperationsMultisig(address _newOperationsMultisig) external {
        if (_newOperationsMultisig == address(0)) {
            revert InvalidOperationsMultisigAddress();
        }
        AlephVaultStorageData storage _sd = _getStorage();
        address _operationsMultisig = _sd.operationsMultisig;
        _sd.operationsMultisig = _newOperationsMultisig;
        _revokeRole(RolesLibrary.OPERATIONS_MULTISIG, _operationsMultisig);
        _revokeRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _operationsMultisig);
        _revokeRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _operationsMultisig);
        _revokeRole(PausableFlows.REDEEM_REQUEST_FLOW, _operationsMultisig);
        _revokeRole(PausableFlows.SETTLE_REDEEM_FLOW, _operationsMultisig);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _newOperationsMultisig);
        _grantRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _newOperationsMultisig);
        _grantRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _newOperationsMultisig);
        _grantRole(PausableFlows.REDEEM_REQUEST_FLOW, _newOperationsMultisig);
        _grantRole(PausableFlows.SETTLE_REDEEM_FLOW, _newOperationsMultisig);
        emit OperationsMultisigMigrated(_newOperationsMultisig);
    }

    /// @inheritdoc IMigrationManager
    function migrateOracle(address _newOracle) external {
        if (_newOracle == address(0)) {
            revert InvalidOracleAddress();
        }
        AlephVaultStorageData storage _sd = _getStorage();
        _revokeRole(RolesLibrary.ORACLE, _sd.oracle);
        _sd.oracle = _newOracle;
        _grantRole(RolesLibrary.ORACLE, _newOracle);
        emit OracleMigrated(_newOracle);
    }

    /// @inheritdoc IMigrationManager
    function migrateGuardian(address _newGuardian) external {
        if (_newGuardian == address(0)) {
            revert InvalidGuardianAddress();
        }
        AlephVaultStorageData storage _sd = _getStorage();
        address _guardian = _sd.guardian;
        _sd.guardian = _newGuardian;
        _revokeRole(RolesLibrary.GUARDIAN, _guardian);
        _revokeRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _guardian);
        _revokeRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _guardian);
        _revokeRole(PausableFlows.REDEEM_REQUEST_FLOW, _guardian);
        _revokeRole(PausableFlows.SETTLE_REDEEM_FLOW, _guardian);
        _grantRole(RolesLibrary.GUARDIAN, _newGuardian);
        _grantRole(PausableFlows.DEPOSIT_REQUEST_FLOW, _newGuardian);
        _grantRole(PausableFlows.SETTLE_DEPOSIT_FLOW, _newGuardian);
        _grantRole(PausableFlows.REDEEM_REQUEST_FLOW, _newGuardian);
        _grantRole(PausableFlows.SETTLE_REDEEM_FLOW, _newGuardian);
        emit GuardianMigrated(_newGuardian);
    }

    /// @inheritdoc IMigrationManager
    function migrateAuthSigner(address _newAuthSigner) external {
        if (_newAuthSigner == address(0)) {
            revert InvalidAuthSignerAddress();
        }
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.authSigner = _newAuthSigner;
        emit AuthSignerMigrated(_newAuthSigner);
    }

    /// @inheritdoc IMigrationManager
    function migrateModules(bytes4 _module, address _newImplementation) external {
        if (_newImplementation == address(0)) {
            revert InvalidModuleAddress();
        }
        _getStorage().moduleImplementations[_module] = _newImplementation;
        emit ModulesMigrated(_module, _newImplementation);
    }
}
