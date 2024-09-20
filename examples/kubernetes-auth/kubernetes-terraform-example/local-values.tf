locals {
  secrets_map_services = {
    secret_service_a = toset([
      "service-a"
    ])

    secret_service_b = toset([
      "service-b"
    ])
  }

  services = {
    # Namespace
    "project-demo" = [
      "service-a", "service-b"
    ]
  }
}
