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

# Function to get fee recipient config value
get_fee_recipient_config_value() {
    local chain_id="$1"
    local env="$2"
    local key="$3"
    local value=$(jq -r ".[\"$chain_id\"][\"$env\"].$key" feeRecipientConfig.json)
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

# Function to validate Ethereum address
validate_address() {
    local address="$1"
    local field="$2"
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        error_exit "$field must be a valid Ethereum address"
    fi
}

# Function to print a header box
print_header() {
    local title="$1"
    # Exactly 56 '═' characters
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}${CYAN}║%*s%s%*s║${NC}\n" $(((62-${#title})/2)) "" "$title" $(((62-${#title}+1)/2)) ""
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

# Function to get private key securely
get_private_key() {
    local private_key
    IFS= read -rs -p "Enter your private key: " private_key
    echo # New line after hidden input
    if [ -z "$private_key" ]; then
        error_exit "Private key cannot be empty"
    fi
    # Remove any whitespace and newlines and ensure it's a single line
    echo -n "$private_key" | tr -d '[:space:]'
}

# Function to get and validate chain ID
get_chain_id() {
    read -p "Enter the chain ID: " CHAIN_ID
    validate_chain_id "$CHAIN_ID"
    echo "$CHAIN_ID"
}

# Function to get and validate environment
get_environment() {
    read -p "Enter the environment (prod/staging/nightly/feature): " ENVIRONMENT
    validate_environment "$ENVIRONMENT"
    echo "$ENVIRONMENT"
}

# Function to export common environment variables
export_common_vars() {
    local chain_id="$1"
    local environment="$2"
    local private_key="$3"
    
    export CHAIN_ID="$chain_id"
    export ENVIRONMENT="$environment"
    # Ensure private key is clean of any whitespace or newlines
    export PRIVATE_KEY=$(echo "$private_key" | tr -d '[:space:]')
}

# Function to verify forge script execution
verify_forge_script() {
    local script_name="$1"
    local verify="$2"
    local error_message="$3"
    
    if [ "$verify" == "true" ]; then
        forge script "$script_name" --sig="run()" --broadcast -vvvv --verify
    else
        forge script "$script_name" --sig="run()" --broadcast -vvvv
    fi
    if [ $? -ne 0 ]; then
        error_exit "$error_message"
    fi
}