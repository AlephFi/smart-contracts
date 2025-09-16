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
 * @notice Terms of Service: https://www.aleph.finance/terms-of-service
 */
interface IMigrationManager {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the operations multisig is migrated.
     * @param operationsMultisig The new operations multisig.
     */
    event OperationsMultisigMigrated(address indexed operationsMultisig);

    /**
     * @notice Emitted when the oracle is migrated.
     * @param oracle The new oracle.
     */
    event OracleMigrated(address indexed oracle);

    /**
     * @notice Emitted when the guardian is migrated.
     * @param guardian The new guardian.
     */
    event GuardianMigrated(address indexed guardian);

    /**
     * @notice Emitted when the authentication signer is migrated.
     * @param authSigner The new authentication signer.
     */
    event AuthSignerMigrated(address indexed authSigner);

    /**
     * @notice Emitted when the modules are migrated.
     * @param module The module.
     * @param implementation The new implementation.
     */
    event ModulesMigrated(bytes4 indexed module, address indexed implementation);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the operations multisig address is invalid.
     */
    error InvalidOperationsMultisigAddress();

    /**
     * @notice Emitted when the oracle address is invalid.
     */
    error InvalidOracleAddress();

    /**
     * @notice Emitted when the guardian address is invalid.
     */
    error InvalidGuardianAddress();

    /**
     * @notice Emitted when the authentication signer address is invalid.
     */
    error InvalidAuthSignerAddress();

    /**
     * @notice Emitted when the module address is invalid.
     */
    error InvalidModuleAddress();

    /*//////////////////////////////////////////////////////////////
                            MIGRATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Migrates the operations multisig.
     * @param _newOperationsMultisig The new operations multisig.
     */
    function migrateOperationsMultisig(address _newOperationsMultisig) external;

    /**
     * @notice Migrates the oracle.
     * @param _newOracle The new oracle.
     */
    function migrateOracle(address _newOracle) external;

    /**
     * @notice Migrates the guardian.
     * @param _newGuardian The new guardian.
     */
    function migrateGuardian(address _newGuardian) external;

    /**
     * @notice Migrates the authentication signer.
     * @param _newAuthSigner The new authentication signer.
     */
    function migrateAuthSigner(address _newAuthSigner) external;

    /**
     * @notice Migrates the module implementation.
     * @param _module The module.
     * @param _newImplementation The new implementation.
     */
    function migrateModules(bytes4 _module, address _newImplementation) external;
}
