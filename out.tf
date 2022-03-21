output "IPs" {
  value = merge({ "db" = azurerm_public_ip.main.ip_address }, { for i in keys(var.wg.wglocations) : "reg_${i}" => azurerm_public_ip.reg[i].ip_address })
}
