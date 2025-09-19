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

# Get current implementation address for comparison later
CURRENT_FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")

# Get private key
PRIVATE_KEY=$(get_private_key)

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting factory upgrade process...${NC}\n"

# Deploy New Factory Implementation
echo -e "${CYAN}╭─ Step 1: Deploying New Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"

verify_forge_script "DeployAlephVaultFactoryImplementation" "true" "Failed to deploy new factory implementation"

# Verify new factory implementation address in deploymentConfig
NEW_FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")
if [ "$NEW_FACTORY_IMPL_ADDRESS" == "$CURRENT_FACTORY_IMPL_ADDRESS" ]; then
    error_exit "New implementation address is the same as current implementation"
fi

echo -e "\n${GREEN}✓${NC} New Factory Implementation deployed successfully"
echo -e "  ${BLUE}Address:${NC} $NEW_FACTORY_IMPL_ADDRESS\n"

# Upgrade Factory Proxy
echo -e "${CYAN}╭─ Step 2: Upgrading Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"
verify_forge_script "UpgradeAlephVaultFactory" "true" "Failed to upgrade factory proxy"

echo -e "\n${GREEN}✓${NC} Factory Proxy upgraded successfully"

# Final success message
print_header "Upgrade Summary"
echo -e "${GREEN}✨ Factory upgrade completed successfully!${NC}\n"
echo -e "${BOLD}Contract Addresses${NC}"
echo -e "  ${BLUE}Factory Proxy:${NC}           $FACTORY_PROXY_ADDRESS"
echo -e "  ${BLUE}Previous Implementation:${NC} $CURRENT_FACTORY_IMPL_ADDRESS"
echo -e "  ${BLUE}New Implementation:${NC}      $NEW_FACTORY_IMPL_ADDRESS\n"
