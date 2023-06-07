locals {
  remote_kernel = "https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/$${cpu_architecture}/fedora-coreos-${var.os_version}-live-kernel-$${cpu_architecture}"
  remote_initrd = "--name main https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/$${cpu_architecture}/fedora-coreos-${var.os_version}-live-initramfs.$${cpu_architecture}.img"

  remote_args = [
    "initrd=main",
    "coreos.live.rootfs_url=https://builds.coreos.fedoraproject.org/prod/streams/${var.os_stream}/builds/${var.os_version}/$${cpu_architecture}/fedora-coreos-${var.os_version}-live-rootfs.$${cpu_architecture}.img",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
  ]

  cached_kernel = "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-kernel-$${cpu_architecture}"
  cached_initrd = "/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-initramfs.$${cpu_architecture}.img"


  cached_args = [
    "initrd=main",
    "coreos.live.rootfs_url=${var.matchbox_http_endpoint}/assets/fedora-coreos/fedora-coreos-${var.os_version}-live-rootfs.$${cpu_architecture}.img",
    "coreos.inst.install_dev=${var.install_disk}",
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?uuid=$${uuid}&mac=$${mac:hexhyp}",
  ]

  kernel = var.cached_install ? local.cached_kernel : local.remote_kernel
  initrd = var.cached_install ? local.cached_initrd : local.remote_initrd
  args   = var.cached_install ? local.cached_args : local.remote_args

}

# Match a controller to a profile by MAC
resource "matchbox_group" "controller" {
  count   = length(var.controllers)
  name    = format("%s-%s", var.cluster_name, var.controllers.*.name[count.index])
  profile = matchbox_profile.controllers.*.name[count.index]

  selector = {
    mac = var.controllers.*.mac[count.index]
  }
}

// Fedora CoreOS controller profile
resource "matchbox_profile" "controllers" {
  count            = length(var.controllers)
  name             = format("%s-controller-%s", var.cluster_name, var.controllers.*.name[count.index])
  cpu_architecture = var.controllers[count.index].cpu_architecture
  kernel           = replace(local.kernel, "$${cpu_architecture}", var.controllers[count.index].cpu_architecture)
  initrd           = [replace(local.initrd, "$${cpu_architecture}", var.controllers[count.index].cpu_architecture)]
  args             = concat([for item in local.args : replace(item, "$${cpu_architecture}", var.controllers[count.index].cpu_architecture)], var.kernel_args)

  raw_ignition = data.ct_config.controllers.*.rendered[count.index]
}

# Fedora CoreOS controllers
data "ct_config" "controllers" {
  count = length(var.controllers)
  content = templatefile("${path.module}/butane/controller.yaml", {
    domain_name            = var.controllers.*.domain[count.index]
    etcd_name              = var.controllers.*.name[count.index]
    etcd_initial_cluster   = join(",", formatlist("%s=https://%s:2380", var.controllers.*.name, var.controllers.*.domain))
    cluster_dns_service_ip = module.bootstrap.cluster_dns_service_ip
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
  })
  strict   = true
  snippets = lookup(var.snippets, var.controllers.*.name[count.index], [])
}
