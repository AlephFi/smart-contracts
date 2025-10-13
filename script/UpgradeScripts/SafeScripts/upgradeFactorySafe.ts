import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    createSafeTransaction,
    proposeSafeTransaction,
    getProxyAdminAddress,
    PROXY_ADMIN_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Get the proxy admin address from the factory proxy
    const proxyAdminAddress = await getProxyAdminAddress(chainConfig.factoryProxyAddress, config.rpcUrl);
    console.log(`Factory Proxy: ${chainConfig.factoryProxyAddress}`);
    console.log(`Proxy Admin: ${proxyAdminAddress}`);

    // Create Safe transaction
    const safeTransaction = await createSafeTransaction({
        targetAddress: proxyAdminAddress,
        abi: PROXY_ADMIN_ABI,
        functionName: 'upgradeAndCall',
        functionArgs: [chainConfig.factoryProxyAddress, chainConfig.factoryImplementationAddress, '0x']
    });

    // Propose Safe transaction
    await proposeSafeTransaction(config, chainConfig.factoryProxyOwner, [safeTransaction]);
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
