terraform {
  backend "gcs" {
    # Bucket name will be set by setup script
    # prefix = "terraform/state"
  }
}