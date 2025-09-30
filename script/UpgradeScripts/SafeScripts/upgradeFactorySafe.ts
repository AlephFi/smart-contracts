import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    runForgeScript,
    createAndProposeSafeTransaction,
    getProxyAdminAddress,
    PROXY_ADMIN_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Run forge script to deploy new implementation
    runForgeScript('DeployAlephVaultFactoryImplementation');

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Get the proxy admin address from the factory proxy
    const proxyAdminAddress = await getProxyAdminAddress(chainConfig.factoryProxyAddress, config.rpcUrl);
    console.log(`Factory Proxy: ${chainConfig.factoryProxyAddress}`);
    console.log(`Proxy Admin: ${proxyAdminAddress}`);

    // Create and propose Safe transaction
    await createAndProposeSafeTransaction(config, {
        targetAddress: proxyAdminAddress,
        safeOwnerAddress: chainConfig.factoryProxyOwner,
        abi: PROXY_ADMIN_ABI,
        functionName: 'upgradeAndCall',
        functionArgs: [chainConfig.factoryProxyAddress, chainConfig.factoryImplementationAddress, '0x']
    });
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
