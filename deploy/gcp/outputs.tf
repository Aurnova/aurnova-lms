output "instance_ip" {
  description = "Public IP address of the VM"
  value       = google_compute_address.public_ip.address
}
