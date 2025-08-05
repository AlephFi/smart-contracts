import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import {
    MetaTransactionData,
    OperationType
} from '@safe-global/types-kit'
import { execSync } from 'child_process'
import { Interface, Wallet } from 'ethers'
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'

dotenv.config();

interface DeploymentConfig {
    [chainId: string]: {
        [environment: string]: {
            vaultBeaconOwner: string;
            factoryProxyOwner: string;
            vaultImplementationAddress: string;
            factoryImplementationAddress: string;
            vaultBeaconAddress: string;
            factoryProxyAddress: string;
        };
    };
}

const BEACON_ABI = [
    "function upgradeTo(address newImplementation) external"
]

async function main() {
    const chainId = process.env.CHAIN_ID;
    const environment = process.env.ENVIRONMENT;
    const rpcUrl = process.env.RPC_URL;
    const privateKey = process.env.PRIVATE_KEY;
    const safeApiKey = process.env.SAFE_API_KEY;

    if (!chainId || !environment || !rpcUrl || !privateKey || !safeApiKey) {
        throw new Error('CHAIN_ID, ENVIRONMENT, RPC_URL, and PRIVATE_KEY must be set in environment variables');
    }

    execSync(`forge script DeployAlephVaultImplementation --broadcast -vvvv --verify`, {
        env: process.env,
        stdio: 'inherit'
    })

    const configPath = path.join(__dirname, '../../deploymentConfig.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    const config: DeploymentConfig = JSON.parse(configData);
    const chainConfig = config[chainId][environment];
    if (!chainConfig) {
        throw new Error(`No configuration found for chain ${chainId} and environment ${environment}`);
    }

    const beaconInterface = new Interface(BEACON_ABI);
    const txData = beaconInterface.encodeFunctionData('upgradeTo', [chainConfig.vaultImplementationAddress]);

    const safeKitOwner = await Safe.init({
        provider: rpcUrl,
        signer: privateKey,
        safeAddress: chainConfig.vaultBeaconOwner
    })

    const safeTransactionData: MetaTransactionData = {
        to: chainConfig.vaultBeaconAddress,
        value: '0',
        data: txData,
        operation: OperationType.Call
    }

    const safeTransaction = await safeKitOwner.createTransaction({
        transactions: [safeTransactionData]
    })

    const safeTxHash = await safeKitOwner.getTransactionHash(safeTransaction)
    const signatureOwner = await safeKitOwner.signHash(safeTxHash)

    const apiKit = new SafeApiKit({
        chainId: BigInt(chainId),
        apiKey: safeApiKey
    })

    await apiKit.proposeTransaction({
        safeAddress: chainConfig.vaultBeaconOwner,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress: new Wallet(privateKey).address,
        senderSignature: signatureOwner.data
    })
}

// Run the main function
main().catch((error) => {
    console.error(error);
    process.exit(1);
}); 