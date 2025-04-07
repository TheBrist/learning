provider "azurerm" {
  features {}
  subscription_id = "cb6a7a77-cdd1-4d79-974a-d6917ccb4ff7"
}

locals {
  vnets = {
    "${var.vnet_vm_name}" = {
      address_space = ["10.0.0.0/16"]
    }

    "${var.vnet_func_app_name}" = {
      address_space = ["10.1.0.0/16"]
    }
  }

  subnets = {
    "${var.subnet_vm_name}" = {
      address   = "10.0.0.0/24"
      vnet_name = "${var.vnet_vm_name}"
    }
    "AzureBastionSubnet" = {
      address   = "10.0.1.0/26"
      vnet_name = "${var.vnet_vm_name}"
    }
    "${var.subnet_function_app_name}" = {
      address   = "10.1.0.0/24"
      vnet_name = "${var.vnet_func_app_name}"
    }
    "subnet-private-endpoints" = {
      address   = "10.1.1.0/24"
      vnet_name = "${var.vnet_func_app_name}"
    }
  }

  peerings = {
    "vm_to_function_app" = {
      vnet_name   = "${var.vnet_vm_name}"
      remote_name = "${var.vnet_func_app_name}"
    }
    "function_app_to_vm" = {
      vnet_name   = "${var.vnet_func_app_name}"
      remote_name = "${var.vnet_vm_name}"
    }
  }
}

resource "azurerm_subnet" "subnet" {
  for_each             = local.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = each.value.vnet_name
  address_prefixes     = [each.value.address]

  depends_on = [azurerm_virtual_network.vnets]

  dynamic "delegation" {
    for_each = each.key == var.subnet_function_app_name ? [1] : []
    content {
      name = "function_app_delegation"
      service_delegation {
        name    = "Microsoft.Web/serverFarms"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }
}

resource "azurerm_virtual_network" "vnets" {
  for_each            = local.vnets
  name                = each.key
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = each.value.address_space
}

resource "azurerm_virtual_network_peering" "peerings" {
  for_each                     = local.peerings
  name                         = each.key
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.vnets[each.value.vnet_name].name
  remote_virtual_network_id    = azurerm_virtual_network.vnets[each.value.remote_name].id
  allow_virtual_network_access = true

  depends_on = [azurerm_virtual_network.vnets]
}

resource "azurerm_network_security_group" "nsg_vm" {
  name                = "nsg-vm"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-RDP-from-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = local.subnets["AzureBastionSubnet"].address
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-FunctionApp-HTTPS"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets[var.subnet_function_app_name].address
  }

  security_rule {
    name                       = "Allow-FunctionApp-PE-HTTPS"
    priority                   = 102
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets["subnet-private-endpoints"].address
  }
  security_rule {
    name                       = "Allow-FunctionApp-HTTP"
    priority                   = 103
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets[var.subnet_function_app_name].address
  }

  security_rule {
    name                       = "Allow-FunctionApp-PE-HTTP"
    priority                   = 104
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets["subnet-private-endpoints"].address
  }
  security_rule {
    name                       = "Allow-FA-PE"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets["subnet-private-endpoints"].address
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Deny-All-Outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_function_app" {
  name                = "nsg-function-app"
  location            = var.location
  resource_group_name = var.resource_group_name
  security_rule {
    name                       = "Allow-VM"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = local.subnets[var.subnet_vm_name].address
    destination_address_prefix = local.subnets[var.subnet_function_app_name].address
    destination_port_range     = "80"
  }
  security_rule {
    name                       = "Deny-All"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    private_ip_address_allocation = "Dynamic"
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[var.subnet_vm_name].id
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_vm" {
  subnet_id                 = azurerm_subnet.subnet[var.subnet_vm_name].id
  network_security_group_id = azurerm_network_security_group.nsg_vm.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_function_app" {
  subnet_id                 = azurerm_subnet.subnet[var.subnet_function_app_name].id
  network_security_group_id = azurerm_network_security_group.nsg_function_app.id
}

resource "azurerm_role_assignment" "vm_rdp_access" {
  principal_id         = var.user_principal_id
  role_definition_name = "Virtual Machine Administrator Login"
  scope                = azurerm_virtual_machine.vm.id
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "vm-windows"
  resource_group_name   = var.resource_group_name
  location              = var.location
  vm_size               = "Standard_B1ms"
  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  storage_os_disk {
    name          = "os-disk"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro"
    version   = "latest"
  }

  os_profile {
    computer_name  = "mamram"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {}
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.managed_identity.id]
  }
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "bastion-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "config"
    subnet_id            = azurerm_subnet.subnet["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

resource "azurerm_storage_account" "function_app_sa" {
  name                     = "safunctionappwin"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#  resource "azurerm_storage_container" "container" {
#    name                  = "function-code"
#    container_access_type = "private"
#    storage_account_id    = azurerm_storage_account.function_app_sa.id
#  }

# resource "azurerm_storage_blob" "function_code" {
#   name                   = "function_app.zip"
#   storage_account_name   = azurerm_storage_account.function_app_sa.name
#   type                   = "Block"
#   storage_container_name = azurerm_storage_container.container.name
#   source                 = "./function_app.zip"
# }

resource "azurerm_service_plan" "function_app_sp" {
  name                = "app-service-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "EP1"
}

resource "azurerm_linux_function_app" "function_app" {
  name                = "linux-function-app-1"
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id      = azurerm_service_plan.function_app_sp.id
  storage_account_name = azurerm_storage_account.function_app_sa.name

  virtual_network_subnet_id  = azurerm_subnet.subnet[var.subnet_function_app_name].id
  storage_account_access_key = azurerm_storage_account.function_app_sa.primary_access_key

  site_config {
    vnet_route_all_enabled = false
    ip_restriction {
      name       = "DenyPublicTraffic"
      ip_address = "0.0.0.0/0"
      action     = "Deny"
      priority   = 200
    }

    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"          = "python"
    "WEBSITE_RUN_FROM_PACKAGE"          = 1
    "ENABLE_ORYX_BUILD"                 = false
    "GCP_AUDIENCE"                      = "//iam.googleapis.com/projects/${module.project_01.number}/locations/global/workloadIdentityPools/provider-pool/providers/azure"
    "CREDENTIAL_SOURCE"                 = "http://169.254.169.254/metadata/identity/oauthz2/token?api-version=2018-02-01&resource=${var.azure_app_uri}"
    "FORWARDING_IP"                     = "https://34.0.66.120:443"
    "SUBJECT_TOKEN_TYPE"                = "urn:ietf:params:oauth:token-type:jwt"
    "TOKEN_URL"                         = "https://sts.googleapis.com/v1/token"
    "CLOUD_RUN_URL"                     = module.cloud_run.service.urls[0]
    "SERVICE_ACCOUNT_IMPERSONATION_URL" = "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${module.azure_sa.email}:generateIdToken"
    #"CERTIFICATE"      = base64encode(tls_self_signed_cert.default.cert_pem)
  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "function_app_endpoint" {
  name                = "function-app-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.subnet["subnet-private-endpoints"].id

  private_service_connection {
    name                           = "function-app-connection"
    private_connection_resource_id = azurerm_linux_function_app.function_app.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}
resource "azurerm_private_dns_zone" "function_app_dns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "VMLink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.function_app_dns.name
  virtual_network_id    = azurerm_virtual_network.vnets["${var.vnet_vm_name}"].id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "dns_a_record" {
  name                = "linux-function-app-1"
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  zone_name           = azurerm_private_dns_zone.function_app_dns.name
  records             = ["${azurerm_private_endpoint.function_app_endpoint.private_service_connection[0].private_ip_address}"]

  depends_on = [azurerm_private_endpoint.function_app_endpoint, azurerm_private_dns_zone.function_app_dns]
}

resource "azurerm_private_endpoint" "storage_endpoint" {
  name                = "sa-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.subnet["subnet-private-endpoints"].id
  private_service_connection {
    name                           = "storage-account-connection"
    private_connection_resource_id = azurerm_storage_account.function_app_sa.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  location            = var.location
  name                = "vm-identity"
  resource_group_name = var.resource_group_name
}

data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "key_vault" {
  name                     = "examplekv1234"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Get", "List", "Delete", "Create", "Import", "Update",
      "GetIssuers", "ListIssuers", "SetIssuers",
      "DeleteIssuers", "ManageIssuers", "Recover", "Backup", "Restore"
    ]
  }
}

resource "azurerm_key_vault_certificate" "ssc" {
  name         = "my-cert"
  key_vault_id = azurerm_key_vault.key_vault.id

  certificate {
    contents = "${tls_self_signed_cert.default.cert_pem}\n${tls_private_key.default.private_key_pem_pkcs8}"
  }
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_type   = "RSA"
      key_size   = 2048
      reuse_key  = true
    }
    secret_properties {
      content_type = "application/x-pem-file"
    }
    x509_certificate_properties {

      subject            = "CN=azure.com"
      validity_in_months = 12
      key_usage = [
        "digitalSignature",
        "keyEncipherment",
        "keyCertSign"
      ]
    }
  }
}

resource "azurerm_key_vault_access_policy" "function_app_policy" {
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_linux_function_app.function_app.identity[0].principal_id

  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
}


