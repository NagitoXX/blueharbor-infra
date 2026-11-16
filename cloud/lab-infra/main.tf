terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

variable "env" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env must be dev, test or prod."
  }
}

variable "web_count" {
  type    = number
  default = 2
}

variable "owner" {
  type = string
}

resource "docker_network" "bh" {
  name = "bh-${var.env}-net"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  count = var.web_count
  name  = "bh-web-${var.env}-${count.index + 1}"
  image = docker_image.nginx.image_id
  networks_advanced {
    name = docker_network.bh.name
  }
  ports {
    internal = 80
    external = 8080 + count.index
  }
  labels {
    label = "owner"
    value = var.owner
  }
}

output "urls" {
  value = [for c in docker_container.web : "http://localhost:${c.ports[0].external}"]
}
