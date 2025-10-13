import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    createSafeTransaction,
    proposeSafeTransaction,
    ACCOUNTANT_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Create Safe transaction
   const safeTransaction = await createSafeTransaction({
        targetAddress: chainConfig.accountantProxyAddress,
        abi: ACCOUNTANT_ABI,
        functionName: 'setVaultFactory',
        functionArgs: [chainConfig.factoryProxyAddress]
    });

    // Propose Safe transaction
    await proposeSafeTransaction(config, chainConfig.operationsMultisig, [safeTransaction]);
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
