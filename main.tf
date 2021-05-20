terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.47.0"
      skip_credentials_validation = false
      #Warning: "skip_credentials_validation": [DEPRECATED] This field is deprecated and will be removed in version 3.0 of the Azure Provider
    }
    databricks = {
      source  = "databrickslabs/databricks"
      version = "0.3.2"
    }
  }
}


# VARIABLES
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}


# Configure the Microsoft Azure Provider
provider "azurerm" {

  features {}
  client_id         = var.client_id
  client_secret     = var.client_secret
  tenant_id         = var.tenant_id
  subscription_id   = var.subscription_id
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-terraform-dbx"
  location = "West Europe"

  tags = {
        environment = "dev"
        project = "dbx deployment"
    }
}

resource "azurerm_databricks_workspace" "dbxws" {
  location                      = "West Europe"
  name                          = "my-dbx-ws"
  resource_group_name           = azurerm_resource_group.rg.name
  sku                           = "standard"
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.dbxws.id
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
  azure_tenant_id             = var.tenant_id
}

resource "databricks_user" "myself" {
  user_name = "paul.peton@live.fr"
}

output "databricks_host" {
  value = "https://${azurerm_databricks_workspace.dbxws.workspace_url}/"
}

#Note: You didn't specify an "-out" parameter to save this plan, so Terraform
#can't guarantee that exactly these actions will be performed if
#"terraform apply" is subsequently run.

data "databricks_node_type" "smallest" {
  local_disk = true
    }

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
    }

resource "databricks_instance_pool" "dbxpool" {
  instance_pool_name = "poolcluster"
  min_idle_instances = 0
  max_capacity       = 3
  node_type_id       = data.databricks_node_type.smallest.id
  azure_attributes {
  }
  idle_instance_autotermination_minutes = 30
  disk_spec {
    disk_type {
      azure_disk_volume_type  = "STANDARD_LRS"
    }
    disk_size = 40
    disk_count = 1
  }
}

resource "databricks_cluster" "dbxcluster" {
    cluster_name            = "my-interactive-cluster"
    spark_version           = data.databricks_spark_version.latest_lts.id
    instance_pool_id        = databricks_instance_pool.dbxpool.id
    #node_type_id            = data.databricks_node_type.smallest.id #optional if instance_pool_id
    autoscale {
            min_workers = 1
            max_workers = 3
                }
    autotermination_minutes = 60
    library {
      pypi {
        package = "mlflow"
      }
    }
}

# Associate Key Vault

# Mount Datalake
