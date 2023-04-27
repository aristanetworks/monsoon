terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    tls = {
      source = "hashicorp/tls"
    }
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.7.1"
    }
    matchbox = {
      source = "poseidon/matchbox"
      version = "0.5.1"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.11.0"
    }
  }
}

data "terraform_remote_state" "matchbox" {
  backend = "local"

  config = {
    path = "matchbox/terraform.tfstate"
  }
}

provider "docker" {
  host = var.docker_uri
}

provider "libvirt" {
  uri = var.libvirt_uri
}

provider "matchbox" {
  endpoint    = "localhost:8081"
  client_cert = data.terraform_remote_state.matchbox.outputs.client_cert.cert_pem
  client_key  = data.terraform_remote_state.matchbox.outputs.client_cert.private_key_pem
  ca          = data.terraform_remote_state.matchbox.outputs.client_cert.ca_cert_pem
}
