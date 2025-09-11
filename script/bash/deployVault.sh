#!/bin/bash

# ./script/bash/deployVault.sh

# Source the utils file
source "$(dirname "$0")/utils.sh"

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Print welcome message
print_header "Aleph Vault Deployment"

# Get and validate inputs
CHAIN_ID=$(get_chain_id)
ENVIRONMENT=$(get_environment)

# Get factory address from deployment config
FACTORY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")
echo -e "\n${BLUE}Using Factory Address:${NC} $FACTORY_ADDRESS"

# Get private key
PRIVATE_KEY=$(get_private_key)

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

# Vault treasury address
read -p "Enter vault treasury address: " VAULT_TREASURY
validate_address "$VAULT_TREASURY" "Vault treasury address"

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

# Export vault initialization parameters
export VAULT_NAME="$VAULT_NAME"
export VAULT_CONFIG_ID="$VAULT_CONFIG_ID"
export VAULT_UNDERLYING_TOKEN="$VAULT_UNDERLYING_TOKEN"
export VAULT_MANAGER="$VAULT_MANAGER"
export VAULT_CUSTODIAN="$VAULT_CUSTODIAN"
export VAULT_TREASURY="$VAULT_TREASURY"

echo -e "\n${BOLD}${GREEN}🚀 Starting vault deployment...${NC}\n"

# Deploy vault
echo -e "${CYAN}╭─ Deploying Vault${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"

verify_forge_script "DeployAlephVault" "false" "Failed to deploy vault"

# Final success message
print_header "Deployment Summary"
echo -e "${GREEN}✨ Vault deployed successfully!${NC}\n"
echo -e "${BOLD}Deployment Details${NC}"
echo -e "  ${BLUE}Vault Name:${NC}              $VAULT_NAME"
echo -e "  ${BLUE}Config ID:${NC}               $VAULT_CONFIG_ID"
echo -e "  ${BLUE}Underlying Token:${NC}        $VAULT_UNDERLYING_TOKEN"
echo -e "  ${BLUE}Manager:${NC}                 $VAULT_MANAGER"
echo -e "  ${BLUE}Custodian:${NC}               $VAULT_CUSTODIAN"
echo -e "  ${BLUE}Treasury:${NC}                $VAULT_TREASURY\n"

