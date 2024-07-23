terraform {
  cloud {
    organization = "roknsound"

    workspaces {
      name = "terraform-tfc-pipeline"
    }
  }
}
