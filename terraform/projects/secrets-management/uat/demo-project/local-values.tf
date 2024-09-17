locals {
  secrets_map_services = {
    integration_kafka = toset([
      "service-a"
    ])

    integrate_redis = toset([
      "service-a"
    ])

    project_dbservice  = toset(["service-a"])
  }

  services = {
    # Namespace
    "project-demo" = [
      "service-a"
    ]
  }
}
