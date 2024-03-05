//18 Aug 2023  Chet Camlin
//This module will create three VM's with public ips.  It will use the ssh keys in your
// home dir .ssh directroy

//provider information
terraform {
  required_version = ">=0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.46.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}
//must have features block
provider "azurerm" {
  features {}
}
//create a random string to use thruout the code if needed
resource "random_string" "main" {
  length  = 4
  upper   = false
  special = false
}

//name from var file
resource "azurerm_resource_group" "main" {
  name     = "RG-${var.prefix}"
  location = var.location
}
//standard vnet
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
//standard subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

//standard public ip
resource "azurerm_public_ip" "main" {

  for_each            = var.vm_map
  name                = "${each.value.name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  lifecycle {
    ignore_changes = [tags]
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "main" {
  name                = "LXNetworkSecurityGroup"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  lifecycle {
    ignore_changes = [tags]
  }
}

//need a nic
resource "azurerm_network_interface" "main" {
  for_each = var.vm_map

  name                = "${each.value.name}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    public_ip_address_id          = azurerm_public_ip.main[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "main" {
  for_each                  = var.vm_map
  network_interface_id      = azurerm_network_interface.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  for_each            = var.vm_map
  name                = each.value.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ls"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.main[each.key].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}
//set your shutdown schedule for each vm
resource "azurerm_dev_test_global_vm_shutdown_schedule" "main" {
  for_each           = var.vm_map
  virtual_machine_id = azurerm_linux_virtual_machine.main[each.key].id
  location           = azurerm_resource_group.main.location
  enabled            = true
  lifecycle {
    ignore_changes = [tags]
  }
  daily_recurrence_time = "2300"
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }
}