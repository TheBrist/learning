resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_func_app_name
  address_prefixes     = ["10.1.255.0/27"]
}

resource "azurerm_public_ip" "vpn_public_ip_0" {
  name                = "azure-to-gcp-ip-0"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vpn_public_ip_1" {
  name                = "azure-to-gcp-ip-1"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "vpn-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  sku           = "VpnGw1"
  active_active = true
  enable_bgp    = true

  ip_configuration {
    name                          = "gatewayConfig-0"
    public_ip_address_id          = azurerm_public_ip.vpn_public_ip_0.id
    subnet_id                     = azurerm_subnet.gateway_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  ip_configuration {
    name                          = "gatewayConfig-1"
    public_ip_address_id          = azurerm_public_ip.vpn_public_ip_1.id
    subnet_id                     = azurerm_subnet.gateway_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  bgp_settings {
    asn = var.gcp_bgp_asn

    peering_addresses {
      apipa_addresses       = [var.apipa_address_0]
      ip_configuration_name = "gatewayConfig-0"
    }

    peering_addresses {
      apipa_addresses       = [var.apipa_address_1]
      ip_configuration_name = "gatewayConfig-1"
    }
  }
}

resource "azurerm_local_network_gateway" "local_gw0" {
  name                = "gcp-local-network-gateway-0"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = module.vpn_ha.gateway.vpn_interfaces[0].ip_address

  address_space = ["10.6.0.0/24"]

  bgp_settings {
    asn                 = var.azure_bgp_asn
    bgp_peering_address = module.vpn_ha.bgp_peers["remote-0"].ip_address
  }
}

resource "azurerm_local_network_gateway" "local_gw1" {
  name                = "gcp-local-network-gateway-1"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = module.vpn_ha.gateway.vpn_interfaces[1].ip_address
  address_space       = ["10.6.0.0/24"]
  bgp_settings {
    asn                 = var.azure_bgp_asn
    bgp_peering_address = module.vpn_ha.bgp_peers["remote-1"].ip_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection0" {
  name                = "azure-to-gcp-vpn-connection-0"
  location            = var.location
  resource_group_name = var.resource_group_name

  type = "IPsec"

  virtual_network_gateway_id = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_gw0.id

  enable_bgp = true
  shared_key = var.shared_secret

}

resource "azurerm_virtual_network_gateway_connection" "vpn_connection1" {
  name                = "azure-to-gcp-vpn-connection-1"
  location            = var.location
  resource_group_name = var.resource_group_name

  type = "IPsec"

  virtual_network_gateway_id = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_gw1.id

  enable_bgp = true
  shared_key = var.shared_secret
}

module "vpn_ha" {
  source     = "./modules/net-vpn-ha"
  project_id = var.project_id_01
  region     = var.region
  network    = module.vpc.self_link
  name       = "vpn-to-azure"
  router_config = {

    asn    = var.azure_bgp_asn
    create = true
    custom_advertise = {
      all_subnets = true
      ip_ranges = {
        "10.1.0.0/24" = "default"
      }
  } }

  peer_gateways = {
    default = {
      external = {
        redundancy_type = "TWO_IPS_REDUNDANCY"
        interfaces      = [azurerm_public_ip.vpn_public_ip_0.ip_address, azurerm_public_ip.vpn_public_ip_1.ip_address]
      }
    }
  }

  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = var.apipa_address_0
        asn     = var.gcp_bgp_asn
      }
      bgp_session_range               = "169.254.21.2/30"
      peer_external_gateway_interface = 0
      vpn_gateway_interface           = 0
      shared_secret                   = var.shared_secret
    }

    remote-1 = {
      bgp_peer = {
        address = var.apipa_address_1
        asn     = var.gcp_bgp_asn
      }
      bgp_session_range               = "169.254.22.1/30"
      peer_external_gateway_interface = 1
      vpn_gateway_interface           = 1
      shared_secret                   = var.shared_secret
    }
  }
}