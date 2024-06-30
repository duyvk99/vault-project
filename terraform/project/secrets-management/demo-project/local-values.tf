locals {
  secrets_map_services = {
    integration_kafka = toset([
      "demo-project-user-profile" "demo-project-notification", "demo-project-otp"
    ])

    integrate_redis = toset([
      "demo-project-user-profile", "demo-project-notification", "demo-project-otp"
    ])

    project_dbservice          = toset(["demo-project-databaseservice"])
    project_dbservice_replicas = toset(["demo-project-databaseservice-replicas"])
  }

  services = {
    # Namespace
    "project-demo" = [
      "demo-project-user-profile", "demo-project-databaseservice", "demo-project-notification", "demo-project-otp"
    ]
  }
}
