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
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
interface IMigrationManager {
    event OperationsMultisigMigrated(address indexed operationsMultisig);
    event OracleMigrated(address indexed oracle);
    event GuardianMigrated(address indexed guardian);
    event AuthSignerMigrated(address indexed authSigner);
    event ModulesMigrated(bytes4 indexed module, address indexed implementation);

    error InvalidOperationsMultisigAddress();
    error InvalidOracleAddress();
    error InvalidGuardianAddress();
    error InvalidAuthSignerAddress();
    error InvalidModuleAddress();

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
