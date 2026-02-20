# Replicated Cluster Marketplace

* Reference implementations for deploying [Replicated Embedded Cluster](https://docs.replicated.com/vendor/embedded-overview) applications through AWS, GCP, and Azure cloud marketplaces.
* Reference implementation for deploying Helm Charts through an AWS Marketplace offering.


## Repository Structure

### [embedded-cluster-image/](./embedded-cluster-image/)

Packer automation to create cloud images (AMIs for AWS, Compute Images for GCP, OVAs for vSphere, Shared Compute Gallery image for Azure) with your Replicated application pre-installed for air-gapped marketplace deployments.

### [aws/](./aws/)

CloudFormation + Lambda example for AWS Marketplace with automated customer licensing. Based on production SlackerNews deployment. Single-node architecture.

### [gcp/](./gcp/)

Terraform module with GCP Marketplace metadata for Blueprint submission. Supports single-node and multi-node HA deployments with Secret Manager integration.

### [azure/](./azure/)

Bicep templates with Azure Portal UI definition for Azure Marketplace Application offers. Multi-node support with load balancer and Key Vault integration.

### [aws helm](./aws-helm/)

Instruction on how to use Replicated licensing and Enterprise portal in combination with an AWS Helm Chart Marketplace offering.

## Getting Started Embedded Cluster

### Prerequisites

1. **Replicated Account** at [vendor.replicated.com](https://vendor.replicated.com)
2. **Cloud Provider Access** (AWS, GCP, or Azure credentials)
3. **Tools**: Packer, Terraform/Azure CLI, make, jq, yq

### Basic Workflow

```bash
# 1. Build your cloud image
cd embedded-cluster-image
# Follow instructions in embedded-cluster-image/README.md
make ami:your-app/stable    # or gcp:your-app/stable

# 2. Deploy marketplace infrastructure
cd ../aws  # or gcp, azure
# Follow platform-specific README instructions
```

## Platform Comparison

| Feature                | AWS                         | GCP                               | Azure                     |
| ---------------------- | --------------------------- | --------------------------------- | ------------------------- |
| **Sample App**         | SlackerNews (production)    | marketplace-example (placeholder) | APPLICATION (placeholder) |
| **IaC Tool**           | CloudFormation + Terraform  | Terraform                         | Bicep                     |
| **Licensing**          | ✅ Automated (Lambda + SNS) | Manual                            | Manual                    |
| **Multi-node**         | ❌ Single-node only         | ✅ HA + Workers                   | ✅ HA + Workers           |
| **Image Builder**      | ✅ Packer                   | ✅ Packer                         | ✅ Packer                 |
| **Marketplace Status** | Production reference        | Blueprint-ready                   | UI definition ready       |

## Marketplace Submission

- **AWS**: AMI + CloudFormation + Product Load Form → [aws/README.md](./aws/)
- **GCP**: Image + Terraform + metadata.yaml → [gcp/README.md](./gcp/)
- **Azure**: Image + Bicep + UI definition → [azure/README.md](./azure/)
