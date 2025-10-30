resource "google_compute_address" "public_ip" {
  name = "${var.instance_name}-ip"
}

resource "google_compute_firewall" "allow_web" {
  name    = "${var.instance_name}-allow-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = var.allow_source_ranges
  target_tags   = [var.instance_name]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.instance_name}-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allow_source_ranges
  target_tags   = [var.instance_name]
}

resource "google_compute_instance" "vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.instance_name]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.public_ip.address
    }
  }

  metadata_startup_script = file("${path.module}/startup.sh")
}
