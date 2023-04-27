terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "docker" {
  host = var.docker_uri
}
