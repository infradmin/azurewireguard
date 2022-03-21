# Wireguard deployment automation

## Purpose
To deploy a set of [Wireguard](https://www.wireguard.com/) cloud servers across the world in a fully automated way for a number of people.

## Details
- Microsoft Azure is used in this project (not mandatory but a requirement of my current situation).
- Ubuntu is used as underlying system (not mandatory, just very common and well known OS).
- Deployment should use terraform and be fully automatic, no manual interaction with gateway should be needed.
- Often changed parameters shoud be set in a separate tfvars file (not included here) for ease of use.
- No names for client profiles, just client numbers, everyone knows what number to use.
- Each client has different settings per gateway to reduce the risk of compromise.
- To simplify client configuration web-interface is needed where authorized people can either download a config file (for computer) or scan a QR-code (for smartphone).
- The solution should be more or less fault tolerable, self-healing and keeping same client settings in case of any gateway fails and re-deployed.

## Design
One DB-server and a separate gateway for every chosen region. Each gateway upon deployment tries to get its setings from DB; if fails (DB is inaccessible or empty), then it creates new. If later DB becomes accessible again and it has previous version of configuration — the older one will be taken by the gateway. Also DB server runs web-server with basic uathentication which show all client settings (provides config file download links and demostrates QR-codes). Also each gateway monitors if this central web-server available; if not gateways will run their own web-pages, but they know only their local settings. While central web-server is reachable gateways' ones are unactive. HTTP is used as far as ther are no domain names, only IP-addresses.

## Usage
1. Clone this project.
2. Create settings file named e.g. `my_wg.auto.tfvars` (if it has ".auto." in the name terraform will be loaded automatically, more info [here](https://www.terraform.io/language/values/variables#:~:text=any%20files%20with%20names%20ending%20in%20.auto.tfvars)). Feel free to use any other approach of passing variables to terraform, whichever you prefer. All needed settings can be seen in vars.tf (defaults are provided there for reference).
3. Run `terraform apply`.
4. When finishes, output will show IP-addresses of DB servers and gateways. Wait a few minutes more for all configurations and syncronizations to be done.
5. Copy DB IP to browser and open it (HTTP, port 80). When prompted enter you administrator credentials (same as set in tfvars). Select desired client number and web-page will be filled with this clent settings on different gateways.
6. Apply client configuration to the client.
