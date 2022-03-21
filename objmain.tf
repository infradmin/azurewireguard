resource "tls_private_key" "sshkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.sshkey.private_key_pem
  filename = "${path.root}/.sshkey/id_rsa"
}

resource "local_file" "public_key_openssh" {
  content  = tls_private_key.sshkey.public_key_openssh
  filename = "${path.root}/.sshkey/id_rsa.pub"
}

resource "azurerm_resource_group" "main" {
  name     = var.wg.rgname
  location = var.wg.rglocation
  tags     = var.wg.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.wg.dbvmprefix}vnet"
  location            = var.wg.rglocation
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["172.27.0.0/24"]
  tags                = var.wg.tags
  subnet {
    name           = "subnet"
    address_prefix = "172.27.0.0/24"
  }
}

resource "azurerm_public_ip" "main" {
  name                = "${var.wg.dbvmprefix}ip"
  location            = var.wg.rglocation
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  tags                = var.wg.tags
}

resource "azurerm_network_interface" "main" {
  name                = "${var.wg.dbvmprefix}nic"
  location            = var.wg.rglocation
  resource_group_name = azurerm_resource_group.main.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${azurerm_virtual_network.main.id}/subnets/subnet"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
  tags = var.wg.tags
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "${var.wg.dbvmprefix}vm"
  location              = var.wg.rglocation
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.wg.vmsize
  network_interface_ids = [azurerm_network_interface.main.id]
  admin_username        = var.admin.name
  #   admin_password                  = var.admin.password
  #   disable_password_authentication = false
  admin_ssh_key {
    username   = var.admin.name
    public_key = tls_private_key.sshkey.public_key_openssh
  }
  os_disk {
    name                 = "${var.wg.dbvmprefix}vmos"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(templatefile("cloud_config_main.yaml.tpl", {
    username   = var.admin.name,
    password   = var.admin.password,
    dbpath     = var.wg.dbpath,
    scriptpath = var.wg.scriptpath
    }
  ))
  tags = var.wg.tags
}
