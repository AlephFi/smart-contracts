import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import {
    MetaTransactionData
} from '@safe-global/types-kit'
import { execSync } from 'child_process'
import { Interface, Wallet, JsonRpcProvider, keccak256, toUtf8Bytes } from 'ethers'
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'

dotenv.config();

export interface DeploymentConfig {
    [chainId: string]: {
        [environment: string]: {
            operationsMultisig: string;
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

export interface FactoryConfig {
    [chainId: string]: {
        [environment: string]: {
            oracle: string;
            guardian: string;
            authSigner: string;
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
    const configPath = path.join(__dirname, '../../../deploymentConfig.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    const config: DeploymentConfig = JSON.parse(configData);
    const chainConfig = config[chainId][environment];

    if (!chainConfig) {
        throw new Error(`No configuration found for chain ${chainId} and environment ${environment}`);
    }

    return chainConfig;
}

export function loadFactoryConfig(chainId: string, environment: string): FactoryConfig[string][string] {
    const configPath = path.join(__dirname, '../../../factoryConfig.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    const config: FactoryConfig = JSON.parse(configData);
    const chainConfig = config[chainId][environment];

    if (!chainConfig) {
        throw new Error(`No configuration found for chain ${chainId} and environment ${environment}`);
    }

    return chainConfig;
}

export async function getProxyAdminAddress(proxyAddress: string, rpcUrl: string): Promise<string> {
    const ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';

    const provider = new JsonRpcProvider(rpcUrl);
    const adminSlotValue = await provider.getStorage(proxyAddress, ADMIN_SLOT);

    // Convert the storage value to an address (remove leading zeros and add 0x prefix)
    const proxyAdminAddress = '0x' + adminSlotValue.slice(-40);

    return proxyAdminAddress;
}


export function runForgeScript(scriptName: string, verify: boolean = true): void {
    console.log(`Running forge script: ${scriptName}`);
    const verifyFlag = verify ? '--verify' : '';
    execSync(`forge script ${scriptName} --broadcast -vvvv ${verifyFlag}`, {
        env: process.env,
        stdio: 'inherit'
    });
}

export function getModuleKey(module: string): string {
    const hash = keccak256(toUtf8Bytes(module));
    return hash.slice(0, 10);
}

export function encodeTransactionData(abi: string[], functionName: string, args: any[]): string {
    const contractInterface = new Interface(abi);
    return contractInterface.encodeFunctionData(functionName, args);
}

export async function createSafeTransaction(
    upgradeParams: ContractUpgradeParams
): Promise<MetaTransactionData> {
    const { targetAddress, abi, functionName, functionArgs } = upgradeParams;

    // Encode transaction data
    const txData = encodeTransactionData(abi, functionName, functionArgs);

    // Create transaction data
    const safeTransactionData: MetaTransactionData = {
        to: targetAddress,
        value: '0',
        data: txData
    };

    console.log("SAFE TX DATA");
    console.log("================================================");
    console.log(txData);
    console.log("================================================");

    return safeTransactionData;
}

export async function proposeSafeTransaction(
    config: SafeTransactionConfig,
    safeOwnerAddress: string,
    transactions: MetaTransactionData[]
): Promise<string> {
    const { chainId, rpcUrl, privateKey, safeApiKey } = config;

    // Initialize Safe
    const safeKitOwner = await Safe.init({
        provider: rpcUrl,
        signer: privateKey,
        safeAddress: safeOwnerAddress
    });

    // Create Safe transaction
    const safeTransaction = await safeKitOwner.createTransaction({ transactions });

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

export const ACCOUNTANT_ABI = [
    "function setVaultFactory(address newVaultFactory) external"
];

export const FACTORY_ABI = [
    "function setModuleImplementation(bytes4 _module, address _implementation) external"
];