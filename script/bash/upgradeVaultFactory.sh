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

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Welcome message
echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║               Aleph Vault Factory Upgrade                  ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Prompt for chain ID
read -p "Enter the chain ID: " CHAIN_ID
validate_chain_id "$CHAIN_ID"

# Prompt for environment
read -p "Enter the environment (prod/staging/nightly/feature): " ENVIRONMENT
validate_environment "$ENVIRONMENT"

# Verify factory proxy address exists
FACTORY_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")
if [ -z "$FACTORY_PROXY_ADDRESS" ] || [[ "$FACTORY_PROXY_ADDRESS" =~ ^0x0+$ ]]; then
    error_exit "Invalid factory proxy address: $FACTORY_PROXY_ADDRESS"
fi

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

echo -e "\n${BOLD}${GREEN}🚀 Starting factory upgrade process...${NC}\n"

# Upgrade Factory Implementation
echo -e "${CYAN}╭─ Step 1: Upgrading Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"

forge script UpgradeAlephVaultFactory --sig="run()" --broadcast -vvvv --verify
if [ $? -ne 0 ]; then
    error_exit "Failed to upgrade factory implementation"
fi

# Verify new factory implementation address in deploymentConfig
NEW_FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")

# Final success message
echo -e "\n${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                   Upgrade Summary                          ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
echo -e "${GREEN}✨ Factory upgrade completed successfully!${NC}\n"
echo -e "${BOLD}Contract Addresses${NC}"
echo -e "  ${BLUE}Factory Proxy:${NC}           $FACTORY_PROXY_ADDRESS"
echo -e "  ${BLUE}New Implementation:${NC}      $NEW_FACTORY_IMPL_ADDRESS\n"
