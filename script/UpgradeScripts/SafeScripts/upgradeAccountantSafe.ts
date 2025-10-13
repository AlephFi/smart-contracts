import {
    validateEnvironmentVariables,
    loadDeploymentConfig,
    runForgeScript,
    createSafeTransaction,
    proposeSafeTransaction,
    getProxyAdminAddress,
    PROXY_ADMIN_ABI
} from './safeUtils';

async function main() {
    // Validate environment variables
    const config = validateEnvironmentVariables();

    // Run forge script to deploy new implementation
    runForgeScript('DeployAccountantImplementation', false);

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Get the proxy admin address from the factory proxy
    const proxyAdminAddress = await getProxyAdminAddress(chainConfig.accountantProxyAddress, config.rpcUrl);
    console.log(`Accountant Proxy: ${chainConfig.accountantProxyAddress}`);
    console.log(`Proxy Admin: ${proxyAdminAddress}`);

    // Create Safe transaction
    const safeTransaction = await createSafeTransaction({
        targetAddress: proxyAdminAddress,
        abi: PROXY_ADMIN_ABI,
        functionName: 'upgradeAndCall',
        functionArgs: [chainConfig.accountantProxyAddress, chainConfig.accountantImplementationAddress, '0x']
    });

    // Propose Safe transaction
    await proposeSafeTransaction(config, chainConfig.accountantProxyOwner, [safeTransaction]);
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
