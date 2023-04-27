# Generate matchbox CA and client certificates.

resource "tls_private_key" "matchbox_ca" {
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "matchbox_ca" {
  private_key_pem   = tls_private_key.matchbox_ca.private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "test-matchbox-ca"
    organization = "ACME, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

resource "tls_private_key" "matchbox_client" {
  algorithm = "ED25519"
}

resource "tls_cert_request" "matchbox_client" {
  private_key_pem = tls_private_key.matchbox_client.private_key_pem

  subject {
    common_name  = "test-matchbox-client"
    organization = "ACME, Inc"
  }
}

resource "tls_locally_signed_cert" "matchbox_client" {
  cert_request_pem   = tls_cert_request.matchbox_client.cert_request_pem
  ca_private_key_pem = tls_private_key.matchbox_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox_ca.cert_pem

  validity_period_hours = 12

  allowed_uses = [
    "client_auth",
    "content_commitment",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "tls_private_key" "matchbox_server" {
  algorithm = "ED25519"
}

resource "tls_cert_request" "matchbox_server" {
  private_key_pem = tls_private_key.matchbox_server.private_key_pem

  dns_names = [
    "localhost",
    "localhost:8080",
    "localhost:8081",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]

  subject {
    common_name  = "test-matchbox-server"
    organization = "ACME, Inc"
  }
}

resource "tls_locally_signed_cert" "matchbox_server" {
  cert_request_pem   = tls_cert_request.matchbox_server.cert_request_pem
  ca_private_key_pem = tls_private_key.matchbox_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox_ca.cert_pem

  validity_period_hours = 12

  allowed_uses = [
    "content_commitment",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]
}

# Build ipxe

resource "docker_image" "ipxe" {
  name = "ipxe-build"
  build {
    context = "ipxe"
  }
  triggers = {
    sha1 = sha1(join("", [for f in fileset(path.module, "ipxe/*") : filesha1(f)]))
  }
  keep_locally = false
}

resource "docker_volume" "matchbox_assets" {}

resource "docker_container" "copy_ipxe" {
  image    = docker_image.ipxe.image_id
  name     = "copy_ipxe"
  start    = true
  attach   = true
  must_run = false

  command = [
    "sh", "-c", <<EOS
    mkdir -p /mnt/ipxe/x86_64 /mnt/ipxe/aarch64
    cp -f /ipxe/src/bin-x86_64-efi/*.efi     /mnt/ipxe/x86_64/
    cp -f /ipxe/src/bin-x86_64-pcbios/*.kpxe /mnt/ipxe/x86_64/
    cp -f /ipxe/src/bin-arm64-efi/*.efi      /mnt/ipxe/aarch64/
    chmod 644 /mnt/ipxe/x86_64/* /mnt/ipxe/aarch64/*
    EOS
  ]

  volumes {
    container_path = "/mnt"
    volume_name    = docker_volume.matchbox_assets.name
  }
}

# Start matchbox container locally

resource "docker_container" "matchbox" {
  image = "quay.io/poseidon/matchbox:v0.10.0"
  name  = "matchbox"

  network_mode = "host"

  command = [
    "-address=0.0.0.0:8080",
    "-rpc-address=0.0.0.0:8081",
    "-log-level=debug",
  ]

  volumes {
    container_path = "/var/lib/matchbox/assets"
    volume_name    = docker_volume.matchbox_assets.name
  }

  upload {
    file    = "/etc/matchbox/ca.crt"
    content = tls_self_signed_cert.matchbox_ca.cert_pem
  }

  upload {
    file    = "/etc/matchbox/server.crt"
    content = tls_locally_signed_cert.matchbox_server.cert_pem
  }

  upload {
    file    = "/etc/matchbox/server.key"
    content = tls_private_key.matchbox_server.private_key_pem
  }
}

output "client_cert" {
    description = "client certificate and private key, used to connect to matchbox gRPC API"

    value = {
        ca_cert_pem     = tls_self_signed_cert.matchbox_ca.cert_pem
        cert_pem        = tls_locally_signed_cert.matchbox_client.cert_pem
        private_key_pem = tls_private_key.matchbox_client.private_key_pem
    }
    sensitive = true
}
