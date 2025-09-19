#!/bin/bash

# ./script/bash/upgradeAccountant.sh

# Source the utils file
source "$(dirname "$0")/utils.sh"

# Check if required files exist
check_file_exists "deploymentConfig.json"

# Print welcome message
print_header "Accountant Upgrade"

# Get and validate inputs
CHAIN_ID=$(get_chain_id)
ENVIRONMENT=$(get_environment)

# Verify accountant proxy address exists
ACCOUNTANT_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "accountantProxyAddress")
if [ -z "$ACCOUNTANT_PROXY_ADDRESS" ] || [[ "$ACCOUNTANT_PROXY_ADDRESS" =~ ^0x0+$ ]]; then
    error_exit "Invalid accountant proxy address: $ACCOUNTANT_PROXY_ADDRESS"
fi

# Get current implementation address for comparison later
CURRENT_ACCOUNTANT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "accountantImplementationAddress")

# Get private key
PRIVATE_KEY=$(get_private_key)

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting accountant upgrade process...${NC}\n"

# Deploy New Factory Implementation
echo -e "${CYAN}╭─ Step 1: Deploying New Accountant Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"

verify_forge_script "DeployAccountantImplementation" "false" "Failed to deploy new accountant implementation"

# Verify new accountant implementation address in deploymentConfig
NEW_ACCOUNTANT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "accountantImplementationAddress")
if [ "$NEW_ACCOUNTANT_IMPL_ADDRESS" == "$CURRENT_ACCOUNTANT_IMPL_ADDRESS" ]; then
    error_exit "New implementation address is the same as current implementation"
fi

echo -e "\n${GREEN}✓${NC} New Accountant Implementation deployed successfully"
echo -e "  ${BLUE}Address:${NC} $NEW_ACCOUNTANT_IMPL_ADDRESS\n"

# Upgrade Accountant Proxy
echo -e "${CYAN}╭─ Step 2: Upgrading Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing upgrade...\n"
verify_forge_script "UpgradeAccountant" "true" "Failed to upgrade accountant proxy"

echo -e "\n${GREEN}✓${NC} Accountant Proxy upgraded successfully"

# Final success message
print_header "Upgrade Summary"
echo -e "${GREEN}✨ Accountant upgrade completed successfully!${NC}\n"
echo -e "${BOLD}Contract Addresses${NC}"
echo -e "  ${BLUE}Accountant Proxy:${NC}           $ACCOUNTANT_PROXY_ADDRESS"
echo -e "  ${BLUE}Previous Implementation:${NC} $CURRENT_ACCOUNTANT_IMPL_ADDRESS"
echo -e "  ${BLUE}New Implementation:${NC}      $NEW_ACCOUNTANT_IMPL_ADDRESS\n"
