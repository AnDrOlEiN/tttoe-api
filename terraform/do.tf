variable "do_token" {}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = "${var.do_token}"
}


# Create a web server
resource "digitalocean_droplet" "web" {
  name = "tttoe-api"
  image  = "ubuntu-18-04-x64"
  region = "fra1"
  size = "s-1vcpu-1gb"
}

resource "digitalocean_project" "tttoe-project" {
  name        = "tttoe-wps"
  description = "Project for the tttoe"
  purpose     = "Class project / Educational purposes"
  environment = "Staging"
  resources   = ["${digitalocean_droplet.web.urn}"]
}