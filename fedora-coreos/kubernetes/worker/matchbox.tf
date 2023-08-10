locals {
  remote_kernel = "https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/${var.cpu_architecture}/fedora-coreos-${var.os_version}-live-kernel-${var.cpu_architecture}"
  remote_initrd = [
    "--name main https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/${var.cpu_architecture}/fedora-coreos-${var.os_version}-live-initramfs.${var.cpu_architecture}.img",
  ]

  remote_args = [
    "initrd=main",
    "coreos.live.rootfs_url=https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/${var.cpu_architecture}/fedora-coreos-${var.os_version}-live-rootfs.${var.cpu_architecture}.img",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
  ]

  cached_kernel = "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-kernel-${var.cpu_architecture}"
  cached_initrd = [
    "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-initramfs.${var.cpu_architecture}.img",
  ]

  cached_args = [
    "initrd=main",
    "coreos.live.rootfs_url=${var.matchbox_http_endpoint}/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-rootfs.${var.cpu_architecture}.img",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
  ]

  kernel = var.cached_install ? local.cached_kernel : local.remote_kernel
  initrd = var.cached_install ? local.cached_initrd : local.remote_initrd
  args   = var.cached_install ? local.cached_args : local.remote_args
}

// Match a worker to a profile by MAC
resource "matchbox_group" "worker" {
  name    = format("%s-%s", var.cluster_name, var.name)
  profile = matchbox_profile.worker.name
  selector = {
    mac = var.mac
  }
}

// Fedora CoreOS worker profile
resource "matchbox_profile" "worker" {
  name   = format("%s-worker-%s", var.cluster_name, var.name)
  kernel = local.kernel
  initrd = local.initrd
  args   = concat(local.args, var.kernel_args)

  raw_ignition = data.ct_config.worker.rendered
}

# Fedora CoreOS workers
data "ct_config" "worker" {
  content = templatefile("${path.module}/butane/worker.yaml", {
    domain_name            = var.domain
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    node_labels            = join(",", var.node_labels)
    node_taints            = join(",", var.node_taints)
  })
  strict   = true
  snippets = var.snippets
}

