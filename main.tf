resource "azurerm_resource_group" "rg-aks" {
    name        = var.rg_name
    location    = var.rg_location
    tags = {
        "Grupo" = var.group
    }
}

resource "azurerm_public_ip" "public_ip"{
    name = "public-ip"
    resource_group_name = azurerm_resource_group.rg-aks.name
    location = azurerm_resource_group.rg-aks.location
    allocation_method = "Static"
    
    tags = {
      "Grupo" = var.group
    }
}

resource "azurerm_virtual_network" "vnet-aks" {
  name = "my-vnet"
  address_space = ["12.0.0.0/16"]
  location = azurerm_resource_group.rg-aks.location
  resource_group_name = azurerm_resource_group.rg-aks.name
}

resource "azurerm_subnet" "subnet-aks" {
  name = "internal"
  resource_group_name = azurerm_resource_group.rg-aks.name
  virtual_network_name = azurerm_virtual_network.vnet-aks.name
  address_prefixes = ["12.0.0.0/20"]
}

resource "azurerm_network_interface" "netint" {
    name =  "networkinterface"
    location = azurerm_resource_group.rg-aks.location
    resource_group_name = azurerm_resource_group.rg-aks.name

    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.subnet-aks.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = azurerm_public_ip.public_ip.id

    }
}

resource "azurerm_linux_virtual_machine" "vm_ansible" {
    name = "vm_ansible"
    resource_group_name = azurerm_resource_group.rg-aks.name
    location = azurerm_resource_group.rg-aks.location
    size = "Standard_B1s"
    network_interface_ids = [ azurerm_network_interface.netint.id, ]
    
    os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }

    source_image_reference {
      publisher = "Canonical"
      offer = "UbuntuServer"
      sku = "16.04-LTS"
      version = "latest"
    }

    computer_name = "hostname"
    admin_username = "mmorales"
    admin_password = "mmorales123._"

    disable_password_authentication = false
}

resource "azurerm_container_registry" "acr-aks" {
  name = "acraksS1G6"
  resource_group_name = azurerm_resource_group.rg-aks.name
  location = azurerm_resource_group.rg-aks.location
  sku = "Basic"
  admin_enabled = true
}

resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-sec1"  
  location = azurerm_resource_group.rg-aks.location
  resource_group_name = azurerm_resource_group.rg-aks.name
  dns_prefix = "aks1"
  kubernetes_version = "1.24.6"

  default_node_pool {
    name = "default"
    node_count = 1
    vm_size = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.subnet-aks.id
    enable_auto_scaling = true
    max_count = 3
    min_count = 1
  }

  service_principal {
    client_id = "XXXXXXXXXXXXXXXXXXXXXXX"
    client_secret = "XXXXXXXXXXXXXXXXXXXXXX"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  role_based_access_control_enabled = true
}

resource "azurerm_kubernetes_cluster_node_pool" "aks-adicional" {
  name = "adicional"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size = "Standard_D2_v2"
  max_pods = 80
  node_count = 1
  node_labels = {
    "node_name" = "Adicional"
  }
}