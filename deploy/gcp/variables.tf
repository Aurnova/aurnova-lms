variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Compute Engine machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 100
}

variable "instance_name" {
  description = "Instance name"
  type        = string
  default     = "aurnova-lms"
}

variable "allow_source_ranges" {
  description = "CIDR ranges allowed to access HTTP/HTTPS/8080"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_user" {
  description = "Username to SSH with (for docs only)"
  type        = string
  default     = "ubuntu"
}
