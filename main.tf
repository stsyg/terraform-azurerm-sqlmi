#############################################################################################
#
# Build SQLMI and failover group in two regions 
#
#############################################################################################
#
# Request / check region quota limits https://docs.microsoft.com/en-us/azure/azure-sql/database/quota-increase-request?view=azuresql
# Additional info https://blobeater.blog/2021/12/09/sql-managed-instance-failover-groups-quick-tips/
# Used code published in GitHub https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples/sql-azure/managed_instance_failover_group
#

# Configure the Microsoft Azure Provider
 provider "azurerm" {
  features {}

}

# Create Resource two groups
resource "azurerm_resource_group" "primary" {
name = "rg-primary3-sqlmi"
location = "canadacentral"
}

resource "azurerm_resource_group" "secondary" {
  name     = "rg-secondary3-sqlmi"
  location = "canadaeast"
}

# Create two vNets
resource "azurerm_virtual_network" "primary" {
  name                = "vnet-sqlmi-primary"
  resource_group_name = azurerm_resource_group.primary.name
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.primary.location
} 

resource "azurerm_virtual_network" "secondary" {
  name                = "vnet-sqlmi-secondary"
  resource_group_name = azurerm_resource_group.secondary.name
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.secondary.location
} 

# Create two subnets
resource "azurerm_subnet" "primary" {
  name                 = "subnet-sqlmi-primary"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes      = ["10.1.1.0/24"]

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name    = "Microsoft.Sql/managedInstances"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet" "secondary" {
  name                 = "subnet-sqlmi-secondary"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes      = ["10.2.1.0/24"]

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name    = "Microsoft.Sql/managedInstances"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action", "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"]
    }
  }
}

# Create two NSGs
resource "azurerm_network_security_group" "primary" {
  name                = "sqlmi-security-group-primary"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
}

resource "azurerm_network_security_group" "secondary" {
  name                = "sqlmi-security-group-secondary"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
}

# Create inbound and outbound rules for two NSGs
resource "azurerm_network_security_rule" "allow_management_inbound" {
  name                        = "allow_management_inbound"
  priority                    = 106
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["9000", "9003", "1438", "1440", "1452"]
#tfsec:ignore:azure-network-no-public-ingress
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_management_inbound_sec" {
  name                        = "allow_management_inbound"
  priority                    = 106
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["9000", "9003", "1438", "1440", "1452"]
  source_address_prefix       = "*"
#tfsec:ignore:azure-network-no-public-ingress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_misubnet_inbound" {
  name                        = "allow_misubnet_inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.1.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_misubnet_inbound_sec" {
  name                        = "allow_misubnet_inbound_sec"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.2.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_health_probe_inbound" {
  name                        = "allow_health_probe_inbound"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_health_probe_inbound_sec" {
  name                        = "allow_health_probe_inbound_sec"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_tds_inbound" {
  name                        = "allow_tds_inbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_tds_inbound_sec" {
  name                        = "allow_tds_inbound_sec"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_redirect_inbound" {
  name                        = "allow_redirect_inbound"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11000-11999"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_redirect_inbound_sec" {
  name                        = "allow_redirect_inbound_sec"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11000-11999"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_geodr_inbound" {
  name                        = "allow_geodr_inbound"
  priority                    = 1200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5022"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_geodr_inbound_sec" {
  name                        = "allow_geodr_inbound_sec"
  priority                    = 1200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5022"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny_all_inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "deny_all_inbound_sec" {
  name                        = "deny_all_inbound_sec"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_management_outbound" {
  name                        = "allow_management_outbound"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "12000"]
  source_address_prefix       = "*"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_management_outbound_sec" {
  name                        = "allow_management_outbound_sec"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "12000"]
  source_address_prefix       = "*"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_misubnet_outbound" {
  name                        = "allow_misubnet_outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.1.1.0/24"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_misubnet_outbound_sec" {
  name                        = "allow_misubnet_outbound_sec"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.2.1.0/24"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_redirect_outbound" {
  name                        = "allow_redirect_outbound"
  priority                    = 1100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11000-11999"
  source_address_prefix       = "VirtualNetwork"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_redirect_outbound_sec" {
  name                        = "allow_redirect_outbound_sec"
  priority                    = 1100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11000-11999"
  source_address_prefix       = "VirtualNetwork"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "allow_geodr_outbound" {
  name                        = "allow_geodr_outbound"
  priority                    = 1200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5022"
  source_address_prefix       = "VirtualNetwork"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "allow_geodr_outbound_sec" {
  name                        = "allow_geodr_outbound_sec"
  priority                    = 1200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5022"
  source_address_prefix       = "VirtualNetwork"
#tfsec:ignore:azure-network-no-public-egress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}
resource "azurerm_network_security_rule" "deny_all_outbound" {
  name                        = "deny_all_outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.primary.name
  network_security_group_name = azurerm_network_security_group.primary.name
}

resource "azurerm_network_security_rule" "deny_all_outbound_sec" {
  name                        = "deny_all_outbound_sec"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.secondary.name
  network_security_group_name = azurerm_network_security_group.secondary.name
}

# Associate newly created NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "primary" {
  subnet_id                 = azurerm_subnet.primary.id
  network_security_group_id = azurerm_network_security_group.primary.id
}

resource "azurerm_subnet_network_security_group_association" "secondary" {
  subnet_id                 = azurerm_subnet.secondary.id
  network_security_group_id = azurerm_network_security_group.secondary.id
}

# Create two Route Tables
resource "azurerm_route_table" "primary" {
  name                          = "routetable-sqlmi-pri"
  location                      = azurerm_resource_group.primary.location
  resource_group_name           = azurerm_resource_group.primary.name
  disable_bgp_route_propagation = false

  depends_on = [
    azurerm_subnet.primary,
  ]
}
resource "azurerm_route_table" "secondary" {
  name                          = "routetable-sqlmi-sec"
  location                      = azurerm_resource_group.secondary.location
  resource_group_name           = azurerm_resource_group.secondary.name
  disable_bgp_route_propagation = false

  depends_on = [
    azurerm_subnet.secondary,
  ]
}

# Associate route tables with subnets
resource "azurerm_subnet_route_table_association" "primary" {
  subnet_id      = azurerm_subnet.primary.id
  route_table_id = azurerm_route_table.primary.id
}

resource "azurerm_subnet_route_table_association" "secondary" {
  subnet_id      = azurerm_subnet.secondary.id
  route_table_id = azurerm_route_table.secondary.id
}

# Create global vNet peering between Primary and Secondary vNets
resource "azurerm_virtual_network_peering" "peer_pri2sec" {
  name                         = "peer-vnet-pri-with-sec"
  resource_group_name          = azurerm_resource_group.primary.name
  virtual_network_name         = azurerm_virtual_network.primary.name
  remote_virtual_network_id    = azurerm_virtual_network.secondary.id
  allow_virtual_network_access = true
}
# Create global vNet peering between Secondary and Primary vNets
resource "azurerm_virtual_network_peering" "peer_sec2pri" {
  name                         = "peer-vnet-sec-with-pri"
  resource_group_name          = azurerm_resource_group.secondary.name
  virtual_network_name         = azurerm_virtual_network.secondary.name
  remote_virtual_network_id    = azurerm_virtual_network.primary.id
  allow_virtual_network_access = true

  depends_on = [
    azurerm_virtual_network_peering.peer_pri2sec,
  ]
}

# Create Primary SQL MI instance
resource "azurerm_mssql_managed_instance" "primary" {
  name                         = "sqlmiprimaryst010622"
  resource_group_name          = azurerm_resource_group.primary.name
  location                     = azurerm_resource_group.primary.location
  administrator_login          = "mradministrator"
  administrator_login_password = "STthisIsDog11"
  license_type                 = "BasePrice"
  subnet_id                    = azurerm_subnet.primary.id
  sku_name                     = "GP_Gen5"
  vcores                       = 4
  storage_size_in_gb           = 32

  depends_on = [
    azurerm_subnet_network_security_group_association.primary,
    azurerm_subnet_route_table_association.primary,
  ]

  tags = {
    environment = "dev"
  }
}

# Create Secondary SQL MI instance
resource "azurerm_mssql_managed_instance" "secondary" {
  name                         = "sqlmisecondaryst010622"
  resource_group_name          = azurerm_resource_group.secondary.name
  location                     = azurerm_resource_group.secondary.location
  administrator_login          = "mradministrator"
  administrator_login_password = "STthisIsDog11"
  license_type                 = "BasePrice"
  subnet_id                    = azurerm_subnet.secondary.id
  dns_zone_partner_id          = azurerm_mssql_managed_instance.primary.id
  sku_name                     = "GP_Gen5"
  vcores                       = 4
  storage_size_in_gb           = 32

  depends_on = [
    azurerm_subnet_network_security_group_association.secondary,
    azurerm_subnet_route_table_association.secondary,
    azurerm_mssql_managed_instance.primary,
  ]

  tags = {
    environment = "dev"
  }
}

# Create Failover Group between Primary and Secondary SQL MI instances
 resource "azurerm_mssql_managed_instance_failover_group" "fgroup" {
  name                        = "dev3-stsqlmi-failover-group"
#  resource_group_name         = azurerm_resource_group.primary.name
  location                    = azurerm_mssql_managed_instance.primary.location
  managed_instance_id       = azurerm_mssql_managed_instance.primary.id
  partner_managed_instance_id = azurerm_mssql_managed_instance.secondary.id

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60

  }
}