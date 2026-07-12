locals {
  common_tags = merge(
    var.tags,
    {
      environment = var.environment
      project     = var.project_name
    }
  )
}
