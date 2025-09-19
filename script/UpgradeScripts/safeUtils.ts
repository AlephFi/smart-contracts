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

export interface DeploymentConfig {
    [chainId: string]: {
        [environment: string]: {
            vaultBeaconOwner: string;
            accountantProxyOwner: string;
            factoryProxyOwner: string;
            vaultImplementationAddress: string;
            vaultDepositImplementationAddress: string;
            vaultRedeemImplementationAddress: string;
            vaultSettlementImplementationAddress: string;
            feeManagerImplementationAddress: string;
            migrationManagerImplementationAddress: string;
            accountantImplementationAddress: string;
            factoryImplementationAddress: string;
            vaultBeaconAddress: string;
            accountantProxyAddress: string;
            factoryProxyAddress: string;
        };
    };
}

export interface SafeTransactionConfig {
    chainId: string;
    environment: string;
    rpcUrl: string;
    privateKey: string;
    safeApiKey: string;
}

export interface ContractUpgradeParams {
    targetAddress: string;
    newImplementationAddress: string;
    safeOwnerAddress: string;
    abi: string[];
    functionName: string;
    functionArgs: any[];
}

export function validateEnvironmentVariables(): SafeTransactionConfig {
    const chainId = process.env.CHAIN_ID;
    const environment = process.env.ENVIRONMENT;
    const rpcUrl = process.env.RPC_URL;
    const privateKey = process.env.PRIVATE_KEY;
    const safeApiKey = process.env.SAFE_API_KEY;

    if (!chainId || !environment || !rpcUrl || !privateKey || !safeApiKey) {
        throw new Error('CHAIN_ID, ENVIRONMENT, RPC_URL, PRIVATE_KEY, and SAFE_API_KEY must be set in environment variables');
    }

    return { chainId, environment, rpcUrl, privateKey, safeApiKey };
}

export function loadDeploymentConfig(chainId: string, environment: string): DeploymentConfig[string][string] {
    const configPath = path.join(__dirname, '../../deploymentConfig.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    const config: DeploymentConfig = JSON.parse(configData);
    const chainConfig = config[chainId][environment];

    if (!chainConfig) {
        throw new Error(`No configuration found for chain ${chainId} and environment ${environment}`);
    }

    return chainConfig;
}

export function runForgeScript(scriptName: string, verify: boolean = true): void {
    console.log(`Running forge script: ${scriptName}`);
    const verifyFlag = verify ? '--verify' : '';
    execSync(`forge script ${scriptName} --broadcast -vvvv ${verifyFlag}`, {
        env: process.env,
        stdio: 'inherit'
    });
}

export function encodeTransactionData(abi: string[], functionName: string, args: any[]): string {
    const contractInterface = new Interface(abi);
    return contractInterface.encodeFunctionData(functionName, args);
}

export async function createAndProposeSafeTransaction(
    config: SafeTransactionConfig,
    upgradeParams: ContractUpgradeParams
): Promise<string> {
    const { chainId, rpcUrl, privateKey, safeApiKey } = config;
    const { targetAddress, newImplementationAddress, safeOwnerAddress, abi, functionName, functionArgs } = upgradeParams;

    // Encode transaction data
    const txData = encodeTransactionData(abi, functionName, functionArgs);

    console.log("================================================");
    console.log("NEW IMPLEMENTATION ADDRESS");
    console.log("================================================");
    console.log(newImplementationAddress);
    console.log("================================================");

    console.log("================================================");
    console.log("TX DATA");
    console.log("================================================");
    console.log(txData);
    console.log("================================================");

    // Initialize Safe
    const safeKitOwner = await Safe.init({
        provider: rpcUrl,
        signer: privateKey,
        safeAddress: safeOwnerAddress
    });

    // Create transaction data
    const safeTransactionData: MetaTransactionData = {
        to: targetAddress,
        value: '0',
        data: txData,
        operation: OperationType.Call
    };

    // Create Safe transaction
    const safeTransaction = await safeKitOwner.createTransaction({
        transactions: [safeTransactionData]
    });

    // Sign transaction
    const safeTxHash = await safeKitOwner.getTransactionHash(safeTransaction);
    const signatureOwner = await safeKitOwner.signHash(safeTxHash);

    console.log("SAFE TX HASH");
    console.log("================================================");
    console.log(safeTxHash);
    console.log("================================================");

    // Initialize API Kit
    const apiKit = new SafeApiKit({
        chainId: BigInt(chainId),
        apiKey: safeApiKey
    });

    // Propose transaction
    await apiKit.proposeTransaction({
        safeAddress: safeOwnerAddress,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress: new Wallet(privateKey).address,
        senderSignature: signatureOwner.data
    });

    console.log("Safe transaction proposed successfully!");
    return safeTxHash;
}

// Common ABIs
export const BEACON_ABI = [
    "function upgradeTo(address newImplementation) external"
];

export const PROXY_ADMIN_ABI = [
    "function upgrade(address proxy, address implementation) external",
    "function upgradeAndCall(address proxy, address implementation, bytes memory data) external"
];
