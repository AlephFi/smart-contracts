#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print error and exit
error_exit() {
    echo -e "\n${RED}${BOLD}ERROR${NC} ❌ $1\n" >&2
    exit 1
}

# Function to check if a file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        error_exit "File $1 not found!"
    fi
}

# Function to check if a value exists in deploymentConfig.json
check_deployment_config() {
    local chain_id="$1"
    local env="$2"
    local key="$3"
    local value=$(jq -r ".[\"$chain_id\"][\"$env\"].$key" deploymentConfig.json)
    
    if [ "$value" == "null" ] || [ -z "$value" ]; then
        error_exit "Missing $key in deploymentConfig.json for chain $chain_id and environment $env"
    fi
    echo "$value"
}

# Function to get vault config value
get_config_value() {
    local chain_id="$1"
    local env="$2"
    local key="$3"
    local value=$(jq -r ".[\"$chain_id\"][\"$env\"].$key" config.json)
    echo "$value"
}

# Function to get factory config value
get_factory_config_value() {
    local chain_id="$1"
    local env="$2"
    local key="$3"
    local value=$(jq -r ".[\"$chain_id\"][\"$env\"].$key" factoryConfig.json)
    echo "$value"
}

# Function to validate chain ID
validate_chain_id() {
    local chain_id="$1"
    if ! [[ "$chain_id" =~ ^[0-9]+$ ]]; then
        error_exit "Chain ID must be a number"
    fi
}

# Function to validate environment
validate_environment() {
    local env="$1"
    if [[ ! "$env" =~ ^(prod|staging|nightly|feature)$ ]]; then
        error_exit "Environment must be one of: prod, staging, nightly, feature"
    fi
}

# Check if required files exist
check_file_exists "deploymentConfig.json"
check_file_exists "config.json"
check_file_exists "factoryConfig.json"

# Welcome message
echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║            Aleph Vault Infrastructure Deployment           ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
echo -e "${YELLOW}This script will deploy the following contracts:${NC}"
echo -e "  • ${BLUE}Vault Implementation${NC}"
echo -e "  • ${BLUE}Vault Beacon${NC}"
echo -e "  • ${BLUE}Factory Implementation & Proxy${NC}\n"

# Prompt for chain ID
read -p "Enter the chain ID: " CHAIN_ID
validate_chain_id "$CHAIN_ID"

# Prompt for environment
read -p "Enter the environment (prod/staging/nightly/feature): " ENVIRONMENT
validate_environment "$ENVIRONMENT"

# Check if owner configs are already set
VAULT_BEACON_OWNER=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultBeaconOwner")
FACTORY_PROXY_OWNER=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyOwner")

# Prompt for private key (hidden input)
read -s -p "Enter your private key: " PRIVATE_KEY
echo # New line after hidden input
if [ -z "$PRIVATE_KEY" ]; then
    error_exit "Private key cannot be empty"
fi

# Export environment variables
export CHAIN_ID="$CHAIN_ID"
export ENVIRONMENT="$ENVIRONMENT"
export PRIVATE_KEY="$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting deployment process...${NC}\n"

# Deploy Vault Implementation
echo -e "${CYAN}╭─ Step 1: Deploying Vault Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
forge script DeployAlephVaultImplementation --sig="run()" --broadcast -vvvv --verify
if [ $? -ne 0 ]; then
    error_exit "Failed to deploy implementation contract"
fi

# Verify vault implementation address in deploymentConfig
VAULT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultImplementationAddress")
echo -e "\n${GREEN}✓${NC} Vault Implementation deployed successfully"
echo -e "  ${BLUE}Address:${NC} $VAULT_IMPL_ADDRESS\n"

# Deploy Beacon
echo -e "${CYAN}╭─ Step 2: Deploying Vault Beacon${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
forge script DeployAlephVaultBeacon --sig="run()" --broadcast -vvvv --verify
if [ $? -ne 0 ]; then
    error_exit "Failed to deploy beacon contract"
fi

# Verify vault beacon address in deploymentConfig
VAULT_BEACON_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultBeaconAddress")
echo -e "\n${GREEN}✓${NC} Vault Beacon deployed successfully"
echo -e "  ${BLUE}Address:${NC} $VAULT_BEACON_ADDRESS\n"

# Deploy Factory
echo -e "${CYAN}╭─ Step 3: Deploying Vault Factory${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
forge script DeployAlephVaultFactory --sig="run()" --broadcast -vvvv --verify
if [ $? -ne 0 ]; then
    error_exit "Failed to deploy factory contract"
fi

# Verify factory addresses in deploymentConfig
FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")
FACTORY_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")

echo -e "\n${GREEN}✓${NC} Factory contracts deployed successfully"
echo -e "  ${BLUE}Implementation:${NC} $FACTORY_IMPL_ADDRESS"
echo -e "  ${BLUE}Proxy:${NC} $FACTORY_PROXY_ADDRESS\n"

# Final success message
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                 Deployment Summary                         ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
echo -e "${GREEN}✨ All contracts deployed successfully!${NC}\n"
echo -e "${BOLD}Deployed Contracts${NC}"
echo -e "  ${BLUE}Vault Implementation:${NC}    $VAULT_IMPL_ADDRESS"
echo -e "  ${BLUE}Vault Beacon:${NC}            $VAULT_BEACON_ADDRESS"
echo -e "  ${BLUE}Factory Implementation:${NC}  $FACTORY_IMPL_ADDRESS"
echo -e "  ${BLUE}Factory Proxy:${NC}           $FACTORY_PROXY_ADDRESS\n"
echo -e "${BOLD}Vault Configs${NC}"
echo -e "  ${BLUE}MinDepositAmountTimelock:${NC}  $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "minDepositAmountTimelock")"
echo -e "  ${BLUE}MaxDepositCapTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "maxDepositCapTimelock")"
echo -e "  ${BLUE}ManagementFeeTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "managementFeeTimelock")"
echo -e "  ${BLUE}PerformanceFeeTimelock:${NC}    $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "performanceFeeTimelock")"
echo -e "  ${BLUE}FeeRecipientTimelock:${NC}      $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "feeRecipientTimelock")"
echo -e "  ${BLUE}BatchDuration:${NC}             $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "batchDuration")\n"
echo -e "${BOLD}Factory Configs${NC}"
echo -e "  ${BLUE}OperationsMultisig:${NC}  $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "operationsMultisig")"
echo -e "  ${BLUE}Oracle:${NC}              $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "oracle")"
echo -e "  ${BLUE}Guardian:${NC}            $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "guardian")"
echo -e "  ${BLUE}FeeRecipient:${NC}        $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "feeRecipient")"
echo -e "  ${BLUE}ManagementFee:${NC}       $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "managementFee")"
echo -e "  ${BLUE}PerformanceFee:${NC}      $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "performanceFee")\n"