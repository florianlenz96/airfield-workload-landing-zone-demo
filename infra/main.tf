# What the Meter Readings team needs, inside its landing zone.
# The network, the identity this runs as and the guardrails come from the platform.

data "azurerm_client_config" "current" {} # the deploy identity the platform created

locals {
  lz         = var.landing_zone
  env        = local.lz.tags["env"]
  suffix     = substr(sha1(local.lz.subscription_id), 0, 6) # globally unique names
  short_name = replace(var.app_name, "-", "")
  # Set on every resource. Otherwise the platform's inherit-tag policy adds them and
  # every run would plan to remove them again.
  tags = merge(local.lz.tags, { app = var.app_name })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.app_name}-${local.env}"
  location = local.lz.location
  tags     = local.tags # without owner, cost-center and env the platform's policy says no
}

# The identity the API runs as. No connection strings, no keys.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.app_name}-app"
  location            = local.lz.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Data: private only
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "readings" {
  name                            = "st${substr(local.short_name, 0, 12)}${local.suffix}"
  location                        = local.lz.location
  resource_group_name             = azurerm_resource_group.this.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  tags                            = local.tags
}

resource "azurerm_storage_container" "readings" {
  name               = "readings"
  storage_account_id = azurerm_storage_account.readings.id
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.readings.name}-blob"
  location            = local.lz.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = local.lz.subnet_ids["private-endpoints"] # from the platform
  tags                = local.tags

  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.readings.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # The zone lives in the hub; the landing zone allows us to add our record.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.lz.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
  }
}

# ---------------------------------------------------------------------------
# Container registry: the pipeline pushes, the app pulls with its identity
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "this" {
  name                = "acr${local.short_name}${local.suffix}"
  location            = local.lz.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# The API: App Service, wired into the landing zone's apps subnet
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "this" {
  name                = "asp-${var.app_name}-${local.env}"
  location            = local.lz.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

resource "azurerm_linux_web_app" "api" {
  name                      = "app-${var.app_name}-${local.suffix}"
  location                  = local.lz.location
  resource_group_name       = azurerm_resource_group.this.name
  service_plan_id           = azurerm_service_plan.this.id
  https_only                = true
  virtual_network_subnet_id = local.lz.subnet_ids["apps"] # from the platform
  tags                      = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {
    vnet_route_all_enabled                        = true # outbound follows the landing zone's routes and NSGs
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id
    health_check_path                             = "/health"
    health_check_eviction_time_in_min             = 2
    ftps_state                                    = "Disabled"

    application_stack {
      # The registry is ours from the start, so the managed identity pulls from it.
      # The image doesn't exist until the first pipeline run deploys it.
      docker_image_name   = "${var.app_name}-api:placeholder"
      docker_registry_url = "https://${azurerm_container_registry.this.login_server}"
    }
  }

  app_settings = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.app.client_id
    Storage__BlobEndpoint = azurerm_storage_account.readings.primary_blob_endpoint
    WEBSITES_PORT         = "8080"
  }

  lifecycle {
    ignore_changes = [site_config[0].application_stack] # the pipeline owns the image
  }
}

# ---------------------------------------------------------------------------
# Role assignments. The landing zone allows exactly these kinds of roles.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "app_readings" {
  scope                = azurerm_storage_account.readings.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "app_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "pipeline_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "ServicePrincipal"
}
