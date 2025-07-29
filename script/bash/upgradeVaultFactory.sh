#!/bin/bash

# ./script/bash/upgradeVaultFactory.sh

# Source the utils file
source "$(dirname "$0")/utils.sh"

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Print welcome message
print_header "Aleph Vault Factory Upgrade"

# Get and validate inputs
CHAIN_ID=$(get_chain_id)
ENVIRONMENT=$(get_environment)

# Verify factory proxy address exists
FACTORY_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")
if [ -z "$FACTORY_PROXY_ADDRESS" ] || [[ "$FACTORY_PROXY_ADDRESS" =~ ^0x0+$ ]]; then
    error_exit "Invalid factory proxy address: $FACTORY_PROXY_ADDRESS"
fi

# Get private key
PRIVATE_KEY=$(get_private_key)

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting factory upgrade process...${NC}\n"

# Upgrade Factory Implementation
echo -e "${CYAN}╭─ Step 1: Upgrading Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"

verify_forge_script "UpgradeAlephVaultFactory" "true" "Failed to upgrade factory implementation"

# Verify new factory implementation address in deploymentConfig
NEW_FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")

# Final success message
print_header "Upgrade Summary"
echo -e "${GREEN}✨ Factory upgrade completed successfully!${NC}\n"
echo -e "${BOLD}Contract Addresses${NC}"
echo -e "  ${BLUE}Factory Proxy:${NC}           $FACTORY_PROXY_ADDRESS"
echo -e "  ${BLUE}New Implementation:${NC}      $NEW_FACTORY_IMPL_ADDRESS\n"
