#!/bin/bash

# ./script/bash/deployVaultInfra.sh

# Source the utils file
source "$(dirname "$0")/utils.sh"

# Check if required files exist
check_file_exists "deploymentConfig.json"
check_file_exists "config.json"
check_file_exists "factoryConfig.json"

# Print welcome message
print_header "Aleph Vault Infrastructure Deployment"
echo -e "${YELLOW}This script will deploy the following contracts:${NC}"
echo -e "  • ${BLUE}Vault Implementation${NC}"
echo -e "  • ${BLUE}Vault Beacon${NC}"
echo -e "  • ${BLUE}Factory Implementation & Proxy${NC}\n"

# Get and validate inputs
CHAIN_ID=$(get_chain_id)
ENVIRONMENT=$(get_environment)

# Check if owner configs are already set
VAULT_BEACON_OWNER=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultBeaconOwner")
FACTORY_PROXY_OWNER=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyOwner")

# Get private key
PRIVATE_KEY=$(get_private_key)

# Export environment variables
export_common_vars "$CHAIN_ID" "$ENVIRONMENT" "$PRIVATE_KEY"

echo -e "\n${BOLD}${GREEN}🚀 Starting deployment process...${NC}\n"

# Deploy Vault Implementation
echo -e "${CYAN}╭─ Step 1: Deploying Vault Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAlephVaultImplementation" "true" "Failed to deploy implementation contract"

# Verify vault implementation address in deploymentConfig
VAULT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultImplementationAddress")
echo -e "\n${GREEN}✓${NC} Vault Implementation deployed successfully"
echo -e "  ${BLUE}Address:${NC} $VAULT_IMPL_ADDRESS\n"

# Deploy Beacon
echo -e "${CYAN}╭─ Step 2: Deploying Vault Beacon${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAlephVaultBeacon" "true" "Failed to deploy beacon contract"

# Verify vault beacon address in deploymentConfig
VAULT_BEACON_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "vaultBeaconAddress")
echo -e "\n${GREEN}✓${NC} Vault Beacon deployed successfully"
echo -e "  ${BLUE}Address:${NC} $VAULT_BEACON_ADDRESS\n"

# Deploy Fee Recipient
echo -e "${CYAN}╭─ Step 3: Deploying Fee Recipient${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployFeeRecipient" "true" "Failed to deploy fee recipient contract"

# Verify fee recipient addresses in deploymentConfig
FEE_RECIPIENT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "feeRecipientImplementationAddress")
FEE_RECIPIENT_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "feeRecipientProxyAddress")

echo -e "\n${GREEN}✓${NC} Fee Recipient contracts deployed successfully"
echo -e "  ${BLUE}Implementation:${NC} $FEE_RECIPIENT_IMPL_ADDRESS"
echo -e "  ${BLUE}Proxy:${NC} $FEE_RECIPIENT_PROXY_ADDRESS\n"

# Deploy Factory
echo -e "${CYAN}╭─ Step 4: Deploying Vault Factory${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAlephVaultFactory" "true" "Failed to deploy factory contract"

# Verify factory addresses in deploymentConfig
FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")
FACTORY_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")

echo -e "\n${GREEN}✓${NC} Factory contracts deployed successfully"
echo -e "  ${BLUE}Implementation:${NC} $FACTORY_IMPL_ADDRESS"
echo -e "  ${BLUE}Proxy:${NC} $FACTORY_PROXY_ADDRESS\n"

# Set Factory in Fee Recipient
echo -e "${CYAN}╭─ Step 5: Setting Factory in Fee Recipient${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "SetVaultFactory" "true" "Failed to set factory in fee recipient contract"

echo -e "\n${GREEN}✓${NC} Factory set in fee recipient successfully"

# Final success message
print_header "Deployment Summary"
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
echo -e "${BOLD}Fee Recipient Configs${NC}"
echo -e "  ${BLUE}ManagementFeeCut:${NC}    $(get_fee_recipient_config_value "$CHAIN_ID" "$ENVIRONMENT" "managementFeeCut")"
echo -e "  ${BLUE}PerformanceFeeCut:${NC}   $(get_fee_recipient_config_value "$CHAIN_ID" "$ENVIRONMENT" "performanceFeeCut")"
echo -e "  ${BLUE}AlephTreasury:${NC}       $(get_fee_recipient_config_value "$CHAIN_ID" "$ENVIRONMENT" "alephTreasury")\n"