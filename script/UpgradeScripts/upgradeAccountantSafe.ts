import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    runForgeScript,
    createAndProposeSafeTransaction,
    PROXY_ADMIN_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Run forge script to deploy new implementation
    runForgeScript('UpgradeAccountant', false);

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Create and propose Safe transaction
    await createAndProposeSafeTransaction(config, {
        targetAddress: chainConfig.accountantProxyAddress,
        newImplementationAddress: chainConfig.accountantImplementationAddress,
        safeOwnerAddress: chainConfig.accountantProxyOwner,
        abi: PROXY_ADMIN_ABI,
        functionName: 'upgradeAndCall',
        functionArgs: [chainConfig.accountantProxyAddress, chainConfig.accountantImplementationAddress, '0x']
    });
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
