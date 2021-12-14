terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.20.0"
    }
  }
  backend "consul" {
    address = "34.130.88.21:8500"
    scheme  = "http"
    path    = "tf/terraform.tfstate"
    lock    = true
    gzip    = false
  }
}

provider "google" {
  credentials = file("latera-test-f6e57050dab1.json")
  project     = "latera-test"
  region      = "us-central1"
  zone        = "us-central1-c"
}

provider "consul" {
  address = "34.130.88.21:8500"
}

data "consul_keys" "app" {
  key {
    name    = "localizations"
    path    = "service/app/localizations"
    default = "en"
  }
  key {
    name    = "vip"
    path    = "service/app/vip"
    default = "dfl"
  }
}

resource "google_compute_network" "local_network" {
  name                    = "local"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "fw_rule1" {
  name     = "all-allow-ssh-icmp"
  network  = google_compute_network.local_network.name
  priority = 1000
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "fw_rule2" {
  name          = "pres-allow-web"
  network       = google_compute_network.local_network.name
  target_tags   = ["pres"]
  source_ranges = ["95.154.65.84/32"]
  priority      = 980
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
}

resource "google_compute_firewall" "fw_rule3" {
  name        = "no-pres-allow-web"
  network     = google_compute_network.local_network.name
  target_tags = ["pub", "vip"]
  priority    = 990
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
}

resource "google_compute_instance_template" "tmpl" {
  name           = "template"
  machine_type   = "f1-micro"
  can_ip_forward = false
  disk {
    source_image = "image-ru"
    auto_delete  = false
    boot         = true
  }
  network_interface {
    network = google_compute_network.local_network.name
    access_config {
    }
  }
}

resource "google_dns_managed_zone" "w5277c" {
  name     = "w5277c"
  dns_name = "w5277c.pp.ru."
}

resource "google_dns_record_set" "pres-dns-a" {
  count        = length(jsondecode(data.consul_keys.app.var.localizations))
  name         = "pres-${jsondecode(data.consul_keys.app.var.localizations)[count.index]}.${google_dns_managed_zone.w5277c.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.w5277c.name
  rrdatas      = [google_compute_instance_from_template.pres["${count.index}"].network_interface[0].access_config[0].nat_ip]
}
resource "google_dns_record_set" "pub-dns-a" {
  count        = length(jsondecode(data.consul_keys.app.var.localizations))
  name         = "pub-${jsondecode(data.consul_keys.app.var.localizations)[count.index]}.${google_dns_managed_zone.w5277c.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.w5277c.name
  rrdatas      = [google_compute_instance_from_template.pub["${count.index}"].network_interface[0].access_config[0].nat_ip]
}
resource "google_dns_record_set" "vip1-dns-a" {
  count        = length(jsondecode(data.consul_keys.app.var.vip))
  name         = "vip-${jsondecode(data.consul_keys.app.var.vip)[count.index]}.${google_dns_managed_zone.w5277c.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.w5277c.name
  rrdatas      = [google_compute_instance_from_template.vip["${count.index}"].network_interface[0].access_config[0].nat_ip]
}

resource "google_compute_instance_from_template" "pub" {
  count                    = length(jsondecode(data.consul_keys.app.var.localizations))
  name                     = "pub-${jsondecode(data.consul_keys.app.var.localizations)[count.index]}"
  source_instance_template = google_compute_instance_template.tmpl.name
  can_ip_forward           = false
  tags                     = ["pub"]
}
resource "google_compute_instance_from_template" "pres" {
  count                    = length(jsondecode(data.consul_keys.app.var.localizations))
  name                     = "pres-${jsondecode(data.consul_keys.app.var.localizations)[count.index]}"
  source_instance_template = google_compute_instance_template.tmpl.name
  can_ip_forward           = false
  tags                     = ["pres"]
}
resource "google_compute_instance_from_template" "vip" {
  count                    = length(jsondecode(data.consul_keys.app.var.vip))
  name                     = "vip-${jsondecode(data.consul_keys.app.var.vip)[count.index]}"
  source_instance_template = google_compute_instance_template.tmpl.name
  can_ip_forward           = false
  tags                     = ["vip"]
}
