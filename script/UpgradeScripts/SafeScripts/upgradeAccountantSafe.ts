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
    runForgeScript('DeployAccountantImplementation', false);

    // Load deployment configuration
    const chainConfig = loadDeploymentConfig(config.chainId, config.environment);

    // Get the proxy admin address from the factory proxy
    const proxyAdminAddress = await getProxyAdminAddress(chainConfig.factoryProxyAddress, config.rpcUrl);
    console.log(`Accountant Proxy: ${chainConfig.accountantProxyAddress}`);
    console.log(`Proxy Admin: ${proxyAdminAddress}`);

    // Create and propose Safe transaction
    await createAndProposeSafeTransaction(config, {
        targetAddress: proxyAdminAddress,
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
