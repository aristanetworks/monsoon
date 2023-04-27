variable "docker_uri" {
  type    = string
  default = "unix:///var/run/docker.sock"
}

variable "libvirt_uri" {
  default = "qemu:///system"
}
