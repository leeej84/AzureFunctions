# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.76"
    }
  }
}

#Provider and subscription
provider "azurerm" {
  alias           = "defaultsub"
  subscription_id = var.subscription_id
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

#Resource group for all resource
resource "azurerm_resource_group" "rg_cugc" {
  provider = azurerm.defaultsub
  name     = var.rg
  location = var.default_location
}

resource "azurerm_network_security_group" "nsg_cugc" {
  name                = var.nsg_cugc
  provider            = azurerm.defaultsub
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
}

resource "azurerm_virtual_network" "vnet_cugc" {
  name                = var.vnet_cugc
  provider            = azurerm.defaultsub
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["8.8.8.8", "8.8.4.4"]
}

resource "azurerm_subnet" "subnet1" {
  provider             = azurerm.defaultsub
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg_cugc.name
  virtual_network_name = azurerm_virtual_network.vnet_cugc.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  provider             = azurerm.defaultsub
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg_cugc.name
  virtual_network_name = azurerm_virtual_network.vnet_cugc.name
  address_prefixes     = ["10.0.2.0/26"]
}

##Common components
resource "azurerm_storage_account" "st_cugc_storage" {
  provider                 = azurerm.defaultsub
  name                     = var.st_automation_storage
  resource_group_name      = azurerm_resource_group.rg_cugc.name
  location                 = var.default_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#Function App service plan
resource "azurerm_app_service_plan" "svcplan_cugc" {
  provider            = azurerm.defaultsub
  name                = var.asp_cugc
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

#Function App itself
resource "azurerm_function_app" "funtionapp_automation" {
  provider                   = azurerm.defaultsub
  name                       = var.functionapp_cugc
  location                   = var.default_location
  resource_group_name        = azurerm_resource_group.rg_cugc.name
  app_service_plan_id        = azurerm_app_service_plan.svcplan_cugc.id
  storage_account_name       = azurerm_storage_account.st_cugc_storage.name
  storage_account_access_key = azurerm_storage_account.st_cugc_storage.primary_access_key

  site_config {
    ftps_state = "AllAllowed"
  }
  identity {
    type = "SystemAssigned"
  }
  https_only = true
  version    = "~4"

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION    = "~4"
    FUNCTIONS_WORKER_RUNTIME       = "powershell"
    WEBSITE_RUN_FROM_PACKAGE       = "0"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.la_in_cugc.instrumentation_key
  }
}

##Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "la_cugc" {
  provider            = azurerm.defaultsub
  name                = var.la_cugc
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
}

#Log Analytics Insights for Function App
resource "azurerm_application_insights" "la_in_cugc" {
  provider            = azurerm.defaultsub
  name                = var.la_in_cugc
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
  application_type    = "web"
}

#NOT RECOMMENDED - Make system identity of Function App a global admin - NOT RECOMMENDED
resource "azurerm_role_assignment" "permissions_assignment" {
  provider             = azurerm.defaultsub
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azurerm_function_app.funtionapp_automation.identity.0.principal_id
}

#Deploy bastion so you can connect to the VMs
resource "azurerm_public_ip" "vnet_cugc_ip" {
  provider            = azurerm.defaultsub
  name                = var.bastion_ip
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion_cugc" {
  provider            = azurerm.defaultsub
  name                = var.bastion_cugc
  location            = var.default_location
  resource_group_name = azurerm_resource_group.rg_cugc.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.vnet_cugc_ip.id
  }
}
