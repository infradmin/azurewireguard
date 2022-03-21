variable "azure" {
  type = object({
    tenant_id       = string,
    subscription_id = string,
    client_id       = string,
    client_secret   = string
  })
  default = {
    subscription_id = "abcdefgh-ijkl-mnop-qrst-uvwxyz123456"
    tenant_id       = "abcdefgh-ijkl-mnop-qrst-uvwxyz123456"
    client_id       = "abcdefgh-ijkl-mnop-qrst-uvwxyz123456"
    client_secret   = "secret"
  }
}

variable "admin" {
  type = object({
    name     = string,
    password = string
  })
  default = {
    name     = "azureadmin",
    password = "passwd4Azure"
  }
}

variable "wg" {
  type = object({
    rgname      = string,
    rglocation  = string,
    dbvmprefix  = string,
    wglocations = map(string),
    vmsize      = string,
    dbpath      = string,
    scriptpath  = string,
    port        = number,
    tags        = map(string)
  })
  default = {
    rgname     = "rg01",
    rglocation = "westeurope",
    dbvmprefix = "wgdb",
    wglocations = {
      eus = "eastus",
      sea = "southeastasia"
    },
    vmsize     = "Standard_B1s",
    dbpath     = "/srv/wg",
    scriptpath = "/usr/local/scripts",
    port       = 12345,
    tags = {
      service = "VPN"
      type    = "Wireguard"
    }
  }
}
