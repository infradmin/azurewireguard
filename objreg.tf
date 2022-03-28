resource "azurerm_network_security_group" "reg" {
  for_each            = var.wg.wglocations
  name                = "az${each.key}wgnsg"
  location            = each.value
  resource_group_name = azurerm_resource_group.main.name
  dynamic "security_rule" {
    for_each = [22, 80, var.wg.port]
    content {
      name                       = "Allow port ${security_rule.value} in"
      priority                   = 1000 + security_rule.value
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value == var.wg.port ? "Udp" : "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_virtual_network" "reg" {
  for_each            = var.wg.wglocations
  name                = "az${each.key}wgvnet"
  location            = each.value
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["172.27.0.0/24"]
  tags                = var.wg.tags
  subnet {
    name           = "subnet"
    address_prefix = "172.27.0.0/24"
    security_group = azurerm_network_security_group.reg[each.key].id
  }
}

resource "azurerm_public_ip" "reg" {
  for_each            = var.wg.wglocations
  name                = "az${each.key}wgip"
  location            = each.value
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  tags                = var.wg.tags
}

resource "azurerm_network_interface" "reg" {
  for_each            = var.wg.wglocations
  name                = "az${each.key}wgnic"
  location            = each.value
  resource_group_name = azurerm_resource_group.main.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${azurerm_virtual_network.reg[each.key].id}/subnets/subnet"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.reg[each.key].id
  }
  tags = var.wg.tags
}

resource "azurerm_linux_virtual_machine" "reg" {
  for_each                        = var.wg.wglocations
  name                            = "az${each.key}wgvm"
  location                        = each.value
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.wg.vmsize
  network_interface_ids           = [azurerm_network_interface.reg[each.key].id]
  admin_username                  = var.admin.name
  admin_password                  = var.admin.disable_ssh_password ? null : var.admin.password
  disable_password_authentication = var.admin.disable_ssh_password
  admin_ssh_key {
    username   = var.admin.name
    public_key = tls_private_key.sshkey.public_key_openssh
  }
  os_disk {
    name                 = "az${each.key}wgvmos"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(templatefile("cloud_config_reg.yaml.tpl", {
    username   = var.admin.name,
    password   = var.admin.password,
    id_rsa     = indent(6, tls_private_key.sshkey.private_key_pem),
    dbpath     = var.wg.dbpath,
    scriptpath = var.wg.scriptpath,
    localip    = azurerm_public_ip.reg[each.key].ip_address,
    remoteip   = azurerm_public_ip.main.ip_address,
    port       = var.wg.port,
    region     = each.key,
    azregion   = each.value,
    index      = index(keys(var.wg.wglocations), each.key)
    }
  ))
  tags       = var.wg.tags
  depends_on = [azurerm_linux_virtual_machine.main]
}
