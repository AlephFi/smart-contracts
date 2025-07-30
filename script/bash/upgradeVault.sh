#!/bin/bash

# ./script/bash/upgradeVault.sh

# Source the utils file
source "$(dirname "$0")/utils.sh"

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Print welcome message
print_header "Aleph Vault Implementation Upgrade"

# Get and validate inputs
CHAIN_ID=$(get_chain_id)
ENVIRONMENT=$(get_environment)

# Verify beacon address exists
VAULT_BEACON_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultBeaconAddress")
if [ -z "$VAULT_BEACON_ADDRESS" ] || [[ "$VAULT_BEACON_ADDRESS" =~ ^0x0+$ ]]; then
    error_exit "Invalid vault beacon address: $VAULT_BEACON_ADDRESS"
fi

# Get current implementation address for comparison later
CURRENT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultImplementationAddress")

# Get private key
PRIVATE_KEY=$(get_private_key)

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting vault upgrade process...${NC}\n"

# Deploy New Vault Implementation
echo -e "${CYAN}╭─ Step 1: Deploying New Vault Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"

verify_forge_script "DeployAlephVaultImplementation" "true" "Failed to deploy new vault implementation"

# Verify new vault implementation address in deploymentConfig
NEW_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultImplementationAddress")
if [ "$NEW_IMPL_ADDRESS" == "$CURRENT_IMPL_ADDRESS" ]; then
    error_exit "New implementation address is the same as current implementation"
fi

echo -e "\n${GREEN}✓${NC} New Vault Implementation deployed successfully"
echo -e "  ${BLUE}Address:${NC} $NEW_IMPL_ADDRESS\n"

# Upgrade Beacon
echo -e "${CYAN}╭─ Step 2: Upgrading Vault Beacon${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"

verify_forge_script "UpgradeAlephVault" "true" "Failed to upgrade vault beacon"

# Final success message
print_header "Upgrade Summary"
echo -e "${GREEN}✨ Vault upgrade completed successfully!${NC}\n"
echo -e "${BOLD}Contract Addresses${NC}"
echo -e "  ${BLUE}Vault Beacon:${NC}            $VAULT_BEACON_ADDRESS"
echo -e "  ${BLUE}Previous Implementation:${NC} $CURRENT_IMPL_ADDRESS"
echo -e "  ${BLUE}New Implementation:${NC}      $NEW_IMPL_ADDRESS\n"
