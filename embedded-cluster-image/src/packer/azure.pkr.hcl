source "azure-arm" "embedded-cluster" {
  # Azure authentication
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  # Build VM configuration
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"

  location = var.build_region
  vm_size  = var.instance_type

  # Storage
  os_disk_size_gb              = var.volume_size
  disk_additional_size         = []
  managed_image_storage_account_type = "Premium_LRS"

  # Shared Image Gallery distribution (Azure equivalent of AMI regions)
  shared_image_gallery_destination {
    subscription         = var.azure_subscription_id
    resource_group       = var.azure_sig_resource_group
    gallery_name         = var.azure_shared_image_gallery
    image_name           = "${var.application}-${var.channel}"
    image_version        = formatdate("YYYY.MMDD.hhmm", timestamp())
    replication_regions  = var.azure_replication_regions
    storage_account_type = "Premium_LRS"
  }

  # Azure Marketplace specific settings (uncomment when ready for marketplace)
  # plan_info {
  #   plan_name      = ""
  #   plan_product   = "${var.application}"
  #   plan_publisher = ""
  # }

  # SSH configuration
  ssh_username = "ubuntu"

  # User data for initial configuration
  user_data = base64encode(local.user-data)

  # Azure-specific build settings
  azure_tags = {
    Application = var.application
    Channel     = var.channel
    BuildDate   = formatdate("YYYY-MM-DD", timestamp())
    ManagedBy   = "Packer"
  }
}

build {
  sources = [
    "source.azure-arm.embedded-cluster",
  ]

  # Wait for cloud-init to complete
  provisioner "shell" {
    pause_before = "20s"
    inline = [
      "sudo cloud-init status --wait",
    ]
  }

  # Clean cloud-init state
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo cloud-init clean -l",
    ]
  }

  # Configure default user for Azure
  provisioner "shell" {
    inline = [
      <<SCRIPT
sudo bash -c 'cat <<DEFAULT_USER > /etc/cloud/cloud.cfg.d/99_default_user.cfg
#cloud-config
system_info:
  default_user:
    name: ${var.application}
    uid: 1118
    groups:
    - users
    - sudo
    - adm
    sudo:
    - ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
DEFAULT_USER
chown root:root /etc/cloud/cloud.cfg.d/99_default_user.cfg
chmod 0644 /etc/cloud/cloud.cfg.d/99_default_user.cfg
'
SCRIPT
    ]
  }

  # Remove default ubuntu user's home directory
  provisioner "shell" {
    inline = [
      "export GLOBIGNORE=\".:..\"",
      "sudo rm -rf /home/ubuntu/.ssh",
      "sudo rm -rf /home/ubuntu/*",
      "sudo chsh -s /usr/sbin/nologin ubuntu"
    ]
  }

  # Azure-specific: Deprovision VM using waagent
  # This is REQUIRED for Azure marketplace images
  provisioner "shell" {
    inline = [
      "sudo waagent -force -deprovision+user",
      "export HISTSIZE=0",
      "sync"
    ]
  }
}
