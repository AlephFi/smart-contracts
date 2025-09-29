import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    loadFactoryConfig,
    createAndProposeSafeTransaction,
    ACCOUNTANT_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);
    const factoryConfig = loadFactoryConfig(config.chainId, config.environment);

    // Create and propose Safe transaction
    await createAndProposeSafeTransaction(config, {
        targetAddress: chainConfig.accountantProxyAddress,
        safeOwnerAddress: factoryConfig.operationsMultisig,
        abi: ACCOUNTANT_ABI,
        functionName: 'setVaultFactory',
        functionArgs: [chainConfig.factoryProxyAddress]
    });
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
