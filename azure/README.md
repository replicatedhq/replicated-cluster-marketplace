# Azure Managed Application - Replicated Cluster

This repository contains the Bicep templates and UI definition for deploying a Replicated Embedded Cluster as an Azure Managed Application.

## Overview

The managed application deploys:

- Control plane VMs (default: 3 nodes)
- Worker node pools (configurable)
- Virtual network and subnet (or use existing)
- Network security groups
- Load balancer
- Key vault for secrets

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- `jq` command-line JSON processor
- `make` utility
- Bicep CLI (installed via Azure CLI)
- Appropriate Azure permissions to:
  - Create resource groups
  - Create storage accounts
  - Create managed application definitions
  - Assign service principal permissions

## Required Information

Before starting, gather the following:

- **APPLICATION**: Name of your application (e.g., `myapp`)
- **CHANNEL**: Release channel (e.g., `stable`, `beta`, `unstable`)
- **IMAGE_ID**: Full Azure VM image resource ID for the cluster nodes

## Step 1: Create Azure Resources for Publishing

### 1.1 Set Variables

```bash
# Publisher/Organization details
PUBLISHER_RG="rg-managedapp-publisher"
LOCATION="eastus"
STORAGE_ACCOUNT="stamanagedapps$(date +%s)"  # Must be globally unique
CONTAINER_NAME="managedapps"

# Application details
APPLICATION="myapp"
CHANNEL="stable"
IMAGE_ID="/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.Compute/galleries/YOUR_GALLERY/images/YOUR_IMAGE/versions/YOUR_VERSION"
```

### 1.2 Create Publisher Resource Group

```bash
az group create \
  --name $PUBLISHER_RG \
  --location $LOCATION
```

### 1.3 Create Storage Account

```bash
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $PUBLISHER_RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot
```

### 1.4 Create Storage Container

```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group $PUBLISHER_RG \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' \
  --output tsv)

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --public-access blob
```

## Step 2: Build and Package the Managed Application

### 2.1 Build the Application Package

```bash
make package \
  APPLICATION=$APPLICATION \
  CHANNEL=$CHANNEL \
  IMAGE_ID=$IMAGE_ID
```

This will:

1. Convert the Bicep template to ARM JSON (`mainTemplate.json`)
2. Inject default values for application, channel, and image ID
3. Copy `createUiDefinition.json`
4. Create a zip file: `dist/{APPLICATION}-{CHANNEL}.zip`

### 2.2 Verify the Package

```bash
# Check the package contents
unzip -l dist/${APPLICATION}-${CHANNEL}.zip

# Should contain:
# - mainTemplate.json
# - createUiDefinition.json
```

## Step 3: Upload to Azure Storage

### 3.1 Upload the Package

```bash
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --container-name $CONTAINER_NAME \
  --name "${APPLICATION}-${CHANNEL}.zip" \
  --file "dist/${APPLICATION}-${CHANNEL}.zip"
```

### 3.2 Get the Package URI

```bash
PACKAGE_URI=$(az storage blob url \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --name "${APPLICATION}-${CHANNEL}.zip" \
  --output tsv)

echo "Package URI: $PACKAGE_URI"
```

## Step 4: Create AD Group for Managed Application Administrators

Members of this group will have privileges to manage deployments of the managed application.

### 4.1 Create AD Group

```bash
AD_GROUP_OUTPUT=$(az ad group create --display-name ${APPLICATION}-owners --mail-nickname ${APPLICATION}-owners)
AD_GROUP_ID=$(echo $AD_GROUP_OUTPUT | jq -r '.id')

echo "AD Group ID: $AD_GROUP_ID"
```

### 4.2 Get Role Definition ID

```bash
# Owner role (or use Contributor if preferred)
ROLE_ID=$(az role definition list \
  --name "Owner" \
  --query '[0].name' \
  --output tsv)

echo "Role Definition ID: $ROLE_ID"
```

## Step 5: Create Managed Application Definition

### 5.1 Set Definition Variables

```bash
# Managed application details
APP_DEFINITION_NAME="${APPLICATION}-${CHANNEL}"
APP_DEFINITION_DISPLAY_NAME="Replicated Cluster - ${APPLICATION} (${CHANNEL})"
APP_DEFINITION_DESCRIPTION="Deploys a Replicated cluster for ${APPLICATION} on the ${CHANNEL} channel"
LOCK_LEVEL="ReadOnly"  # Options: None, CanNotDelete, ReadOnly
```

### 5.2 Create the Managed Application Definition

```bash
az managedapp definition create \
  --name $APP_DEFINITION_NAME \
  --resource-group $PUBLISHER_RG \
  --location $LOCATION \
  --display-name "$APP_DEFINITION_DISPLAY_NAME" \
  --description "$APP_DEFINITION_DESCRIPTION" \
  --lock-level $LOCK_LEVEL \
  --authorizations "${AD_GROUP_ID}:${ROLE_ID}" \
  --package-file-uri $PACKAGE_URI
```

### 5.3 Verify Creation

```bash
az managedapp definition show \
  --name $APP_DEFINITION_NAME \
  --resource-group $PUBLISHER_RG \
  --output table
```

## Step 6: Deploy the Managed Application (Customer)

Once the managed application definition is created, customers can deploy it.

### 6.1 Customer Deployment via Portal

1. Navigate to the Azure Portal
2. Search for "Managed Applications"
3. Click "Add" or "Create"
4. Select your managed application definition
5. Fill in the required parameters:
   - Name Prefix
   - Admin Console Password
   - License file (YAML)
   - Admin Username
   - SSH Public Key
   - Control plane and worker node configurations
6. Review and create

### 6.2 Customer Deployment via CLI

```bash
# Customer's variables
CUSTOMER_RG="rg-replicated-cluster"
CUSTOMER_LOCATION="eastus"
MANAGED_APP_NAME="replicated-cluster-instance"

# Create resource group for the managed application
az group create \
  --name $CUSTOMER_RG \
  --location $CUSTOMER_LOCATION

# Deploy the managed application
az managedapp create \
  --name $MANAGED_APP_NAME \
  --resource-group $CUSTOMER_RG \
  --kind "ServiceCatalog" \
  --managed-rg-id "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/mrg-${MANAGED_APP_NAME}" \
  --managedapp-definition-id "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/${PUBLISHER_RG}/providers/Microsoft.Solutions/applicationDefinitions/${APP_DEFINITION_NAME}" \
  --parameters @parameters.json
```

## Step 7: Update an Existing Managed Application Definition

To update the managed application definition with a new package:

```bash
# Build new package
make package \
  APPLICATION=$APPLICATION \
  CHANNEL=$CHANNEL \
  IMAGE_ID=$NEW_IMAGE_ID

# Upload new version
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --container-name $CONTAINER_NAME \
  --name "${APPLICATION}-${CHANNEL}.zip" \
  --file "dist/${APPLICATION}-${CHANNEL}.zip" \
  --overwrite

az managedapp definition update \
  --name $APP_DEFINITION_NAME \
  --resource-group $PUBLISHER_RG \
  --location $LOCATION \
  --display-name "$APP_DEFINITION_DISPLAY_NAME" \
  --description "$APP_DEFINITION_DESCRIPTION" \
  --lock-level $LOCK_LEVEL \
  --authorizations "${AD_GROUP_ID}:${ROLE_ID}" \
  --package-file-uri $PACKAGE_URI
```

## Troubleshooting

### View Deployment Logs

```bash
# Get the managed resource group name
MANAGED_RG=$(az managedapp show \
  --name $MANAGED_APP_NAME \
  --resource-group $CUSTOMER_RG \
  --query managedResourceGroupId \
  --output tsv | cut -d'/' -f5)

# View deployments in managed resource group
az deployment group list \
  --resource-group $MANAGED_RG \
  --output table

# View specific deployment
az deployment group show \
  --name DEPLOYMENT_NAME \
  --resource-group $MANAGED_RG
```

### Test UI Definition Locally

```bash
# Use the Azure Portal's sandbox
# Navigate to: https://portal.azure.com/?feature.customPortal=false#create/Microsoft.Template

# Upload createUiDefinition.json and mainTemplate.json for testing
```

### Validate Templates

```bash
# Validate Bicep syntax
az bicep build --file modules/cluster.bicep

# Validate ARM template
az deployment group validate \
  --resource-group TEST_RG \
  --template-file dist/mainTemplate.json \
  --parameters @test-parameters.json
```

## Clean Up

### Delete Managed Application Instance

```bash
az managedapp delete \
  --name $MANAGED_APP_NAME \
  --resource-group $CUSTOMER_RG
```

### Delete Managed Application Definition

```bash
az managedapp definition delete \
  --name $APP_DEFINITION_NAME \
  --resource-group $PUBLISHER_RG
```

### Delete Publisher Resources

```bash
# Delete storage container
az storage container delete \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT

# Delete storage account
az storage account delete \
  --name $STORAGE_ACCOUNT \
  --resource-group $PUBLISHER_RG

# Delete resource group
az group delete \
  --name $PUBLISHER_RG \
  --yes --no-wait
```
