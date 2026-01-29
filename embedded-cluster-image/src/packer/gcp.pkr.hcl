source "googlecompute" "embedded-cluster" {
  project_id   = var.gcp_project_id
  source_image = var.gcp_source_image
  zone         = var.gcp_zone

  image_name        = "${var.application}-${var.channel}-ubuntu-24-04-lts"
  image_family      = "${var.application}-${var.channel}"
  image_description = "Replicated Embedded Cluster: ${var.application} (${var.channel}) on Ubuntu 24.04 LTS"

  ssh_username = "ubuntu"

  credentials_file = var.gcp_credentials_file
  disk_size        = var.volume_size
  machine_type     = var.gcp_machine_type

  metadata = {
    user-data = local.user-data
  }
}

build {
  sources = [
    "source.googlecompute.embedded-cluster",
  ]

  provisioner "shell" {
    pause_before = "20s"
    inline = [
      "sudo cloud-init status --wait",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo cloud-init clean -l",
    ]
  }

  provisioner "shell" {
    inline = [
      <<SCRIPT
sudo bash -c 'cat <<DEFAULT_USER > /etc/cloud/cloud.cfg.d/99_default_user.cfg
#cloud-config
system_info:
  default_user:
    name: ${var.application}
    uid: 1118
    no_create_home: true
    homedir: "/var/lib/${var.application}"
    groups:
    - users
    - sudo
    - adm
    - ssher
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

  provisioner "shell" {
    inline = [
      "export GLOBIGNORE=\".:..\"",
      "sudo rm -rf /home/ubuntu/.ssh",
      "sudo rm -rf /home/ubuntu/*",
      "sudo chsh -s /usr/sbin/nologin ubuntu"
    ]
  }
}
