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

# Deploy Accountant Implementation
echo -e "${CYAN}╭─ Step 3: Deploying Accountant Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAccountantImplementation" "false" "Failed to deploy accountant implementation contract"

# Verify accountant implementation address in deploymentConfig
ACCOUNTANT_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "accountantImplementationAddress")

echo -e "\n${GREEN}✓${NC} Accountant implementation deployed successfully"
echo -e "  ${BLUE}Implementation:${NC} $ACCOUNTANT_IMPL_ADDRESS"

# Deploy Accountant Proxy
echo -e "${CYAN}╭─ Step 4: Deploying Accountant Proxy${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAccountantProxy" "false" "Failed to deploy accountant proxy contract"

# Verify accountant proxy address in deploymentConfig
ACCOUNTANT_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "accountantProxyAddress")

echo -e "\n${GREEN}✓${NC} Accountant proxy deployed successfully"
echo -e "  ${BLUE}Proxy:${NC} $ACCOUNTANT_PROXY_ADDRESS"

# Deploy Factory Implementation
echo -e "${CYAN}╭─ Step 5: Deploying Vault Factory Implementation${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAlephVaultFactoryImplementation" "true" "Failed to deploy factory implementation contract"

# Verify factory implementation address in deploymentConfig
FACTORY_IMPL_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryImplementationAddress")

echo -e "\n${GREEN}✓${NC} Factory implementation deployed successfully"
echo -e "  ${BLUE}Implementation:${NC} $FACTORY_IMPL_ADDRESS"

# Deploy Factory Proxy
echo -e "${CYAN}╭─ Step 6: Deploying Vault Factory Proxy${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "DeployAlephVaultFactoryProxy" "true" "Failed to deploy factory proxy contract"

# Verify factory proxy address in deploymentConfig
FACTORY_PROXY_ADDRESS=$(check_deployment_config "$CHAIN_ID" "$ENVIRONMENT" "factoryProxyAddress")

echo -e "\n${GREEN}✓${NC} Factory proxy deployed successfully"
echo -e "  ${BLUE}Proxy:${NC} $FACTORY_PROXY_ADDRESS"

# Set Factory in Accountant
echo -e "${CYAN}╭─ Step 7: Setting Factory in Accountant${NC}"
echo -e "${CYAN}╰─>${NC} Initializing deployment...\n"
verify_forge_script "SetVaultFactory" "false" "Failed to set factory in accountant contract"

echo -e "\n${GREEN}✓${NC} Factory set in accountant successfully"

# Final success message
print_header "Deployment Summary"
echo -e "${GREEN}✨ All contracts deployed successfully!${NC}\n"
echo -e "${BOLD}Deployed Contracts${NC}"
echo -e "  ${BLUE}Vault Implementation:${NC}    $VAULT_IMPL_ADDRESS"
echo -e "  ${BLUE}Vault Beacon:${NC}            $VAULT_BEACON_ADDRESS"
echo -e "  ${BLUE}Accountant Implementation:${NC} $ACCOUNTANT_IMPL_ADDRESS"
echo -e "  ${BLUE}Accountant Proxy:${NC}         $ACCOUNTANT_PROXY_ADDRESS"
echo -e "  ${BLUE}Factory Implementation:${NC}  $FACTORY_IMPL_ADDRESS"
echo -e "  ${BLUE}Factory Proxy:${NC}           $FACTORY_PROXY_ADDRESS\n"
echo -e "${BOLD}Vault Configs${NC}"
echo -e "  ${BLUE}MinDepositAmountTimelock:${NC}  $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "minDepositAmountTimelock")"
echo -e "  ${BLUE}MinUserBalanceTimelock:${NC}  $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "minUserBalanceTimelock")"
echo -e "  ${BLUE}MaxDepositCapTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "maxDepositCapTimelock")"
echo -e "  ${BLUE}NoticePeriodTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "noticePeriodTimelock")"
echo -e "  ${BLUE}LockInPeriodTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "lockInPeriodTimelock")"
echo -e "  ${BLUE}MinRedeemAmountTimelock:${NC}  $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "minRedeemAmountTimelock")"
echo -e "  ${BLUE}ManagementFeeTimelock:${NC}     $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "managementFeeTimelock")"
echo -e "  ${BLUE}PerformanceFeeTimelock:${NC}    $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "performanceFeeTimelock")"
echo -e "  ${BLUE}BatchDuration:${NC}             $(get_config_value "$CHAIN_ID" "$ENVIRONMENT" "batchDuration")\n"
echo -e "${BOLD}Factory Configs${NC}"
echo -e "  ${BLUE}OperationsMultisig:${NC}  $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "operationsMultisig")"
echo -e "  ${BLUE}Oracle:${NC}              $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "oracle")"
echo -e "  ${BLUE}Guardian:${NC}            $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "guardian")"
echo -e "  ${BLUE}AuthSigner:${NC}          $(get_factory_config_value "$CHAIN_ID" "$ENVIRONMENT" "authSigner")\n"
echo -e "${BOLD}Accountant Configs${NC}"
echo -e "  ${BLUE}AlephTreasury:${NC}       $(get_accountant_config_value "$CHAIN_ID" "$ENVIRONMENT" "alephTreasury")\n"