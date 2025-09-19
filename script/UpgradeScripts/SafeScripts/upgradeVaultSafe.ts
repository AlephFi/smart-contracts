import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    runForgeScript,
    createAndProposeSafeTransaction,
    BEACON_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Run forge script to deploy new implementation
    runForgeScript('DeployAlephVaultImplementation');

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Create and propose Safe transaction
    await createAndProposeSafeTransaction(config, {
        targetAddress: chainConfig.vaultBeaconAddress,
        newImplementationAddress: chainConfig.vaultImplementationAddress,
        safeOwnerAddress: chainConfig.vaultBeaconOwner,
        abi: BEACON_ABI,
        functionName: 'upgradeTo',
        functionArgs: [chainConfig.vaultImplementationAddress]
    });
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
}); 