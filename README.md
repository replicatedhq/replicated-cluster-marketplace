# replicated-cluster-marketplace

This repository contains tools and examples for deploying Replicated Embedded Cluster through cloud marketplace offerings.

## Directory Structure

### [embedded-cluster-image/](./embedded-cluster-image/)
Packer configuration to create AMI for AWS and images for GCP. This directory contains the base image building process for marketplace deployments.

### [aws/](./aws/)
CloudFormation example for AWS Marketplace offering. Contains templates and resources for deploying through AWS Marketplace.

### [gcp/](./gcp/)
Terraform example for GCP Marketplace offering. Contains Terraform configurations for deploying through Google Cloud Marketplace.
