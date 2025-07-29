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

# Function to validate address
validate_address() {
    local address="$1"
    local field="$2"
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        error_exit "$field must be a valid Ethereum address"
    fi
}

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Welcome message
echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                   Aleph Vault Deployment                   ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Prompt for chain ID
read -p "Enter the chain ID: " CHAIN_ID
validate_chain_id "$CHAIN_ID"

# Prompt for environment
read -p "Enter the environment (prod/staging/nightly/feature): " ENVIRONMENT
validate_environment "$ENVIRONMENT"

# Get factory address from deployment config
FACTORY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")
echo -e "\n${BLUE}Using Factory Address:${NC} $FACTORY_ADDRESS"

# Prompt for private key (hidden input)
read -s -p "Enter your private key: " PRIVATE_KEY
echo # New line after hidden input
if [ -z "$PRIVATE_KEY" ]; then
    error_exit "Private key cannot be empty"
fi

# Get vault initialization parameters
echo -e "\n${YELLOW}Enter vault initialization parameters:${NC}"

# Vault name
read -p "Enter vault name: " VAULT_NAME
if [ -z "$VAULT_NAME" ]; then
    error_exit "Vault name cannot be empty"
fi

# Vault config ID
read -p "Enter vault config ID: " VAULT_CONFIG_ID

# Underlying token address
read -p "Enter underlying token address: " VAULT_UNDERLYING_TOKEN
validate_address "$VAULT_UNDERLYING_TOKEN" "Underlying token address"

# Vault manager address
read -p "Enter vault manager address: " VAULT_MANAGER
validate_address "$VAULT_MANAGER" "Vault manager address"

# Vault custodian address
read -p "Enter vault custodian address: " VAULT_CUSTODIAN
validate_address "$VAULT_CUSTODIAN" "Vault custodian address"

# Export environment variables
export PRIVATE_KEY="$PRIVATE_KEY"
export CHAIN_ID="$CHAIN_ID"
export ENVIRONMENT="$ENVIRONMENT"

# Export vault initialization parameters
export VAULT_NAME="$VAULT_NAME"
export VAULT_CONFIG_ID="$VAULT_CONFIG_ID"
export VAULT_UNDERLYING_TOKEN="$VAULT_UNDERLYING_TOKEN"
export VAULT_MANAGER="$VAULT_MANAGER"
export VAULT_CUSTODIAN="$VAULT_CUSTODIAN"

echo -e "\n${BOLD}${GREEN}🚀 Starting vault deployment...${NC}\n"

# Deploy vault
echo -e "${CYAN}╭─ Deploying Vault${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"

forge script DeployAlephVault --sig="run()" --broadcast -vvvv
if [ $? -ne 0 ]; then
    error_exit "Failed to deploy vault"
fi

# Final success message
echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                 Deployment Summary                         ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
echo -e "${GREEN}✨ Vault deployed successfully!${NC}\n"
echo -e "${BOLD}Deployment Details${NC}"
echo -e "  ${BLUE}Vault Name:${NC}              $VAULT_NAME"
echo -e "  ${BLUE}Config ID:${NC}               $VAULT_CONFIG_ID"
echo -e "  ${BLUE}Underlying Token:${NC}        $VAULT_UNDERLYING_TOKEN"
echo -e "  ${BLUE}Manager:${NC}                 $VAULT_MANAGER"
echo -e "  ${BLUE}Custodian:${NC}               $VAULT_CUSTODIAN\n"
