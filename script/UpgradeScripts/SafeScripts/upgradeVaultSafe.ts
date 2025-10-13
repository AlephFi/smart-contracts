import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    runForgeScript,
    getModuleKey,
    createSafeTransaction,
    proposeSafeTransaction,
    BEACON_ABI,
    FACTORY_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Run forge script to deploy new implementation
    runForgeScript('DeployAlephVaultImplementation');

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Create Vaule Safe transactions
    const vaultUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.vaultBeaconAddress,
        abi: BEACON_ABI,
        functionName: 'upgradeTo',
        functionArgs: [chainConfig.vaultImplementationAddress]
    });

    // Create Module Safe transactions
    const vaultDepositUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.factoryProxyAddress,
        abi: FACTORY_ABI,
        functionName: 'setModuleImplementation',
        functionArgs: [getModuleKey('ALEPH_VAULT_DEPOSIT'), chainConfig.vaultDepositImplementationAddress]
    });

    const vaultRedeemUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.factoryProxyAddress,
        abi: FACTORY_ABI,
        functionName: 'setModuleImplementation',
        functionArgs: [getModuleKey('ALEPH_VAULT_REDEEM'), chainConfig.vaultRedeemImplementationAddress]
    });

    const vaultSettlementUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.factoryProxyAddress,
        abi: FACTORY_ABI,
        functionName: 'setModuleImplementation',
        functionArgs: [getModuleKey('ALEPH_VAULT_SETTLEMENT'), chainConfig.vaultSettlementImplementationAddress]
    });

    const feeManagerUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.factoryProxyAddress,
        abi: FACTORY_ABI,
        functionName: 'setModuleImplementation',
        functionArgs: [getModuleKey('FEE_MANAGER'), chainConfig.feeManagerImplementationAddress]
    });

    const migrationManagerUpgradeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.factoryProxyAddress,
        abi: FACTORY_ABI,
        functionName: 'setModuleImplementation',
        functionArgs: [getModuleKey('MIGRATION_MANAGER'), chainConfig.migrationManagerImplementationAddress]
    });

    // Propose Safe transaction
    await proposeSafeTransaction(config, chainConfig.vaultBeaconOwner, [
        vaultUpgradeTransaction, 
        vaultDepositUpgradeTransaction, 
        vaultRedeemUpgradeTransaction, 
        vaultSettlementUpgradeTransaction, 
        feeManagerUpgradeTransaction, 
        migrationManagerUpgradeTransaction
    ]);
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
}); 