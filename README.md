A lightweight Bash script designed to route all system TCP and DNS traffic through a transparent Tor proxy nested inside an active OpenVPN connection. It utilizes `iptables` to enforce strict network boundaries and features a leak-proof kill-switch to ensure traffic never bypasses the secure tunnel.

🚀 How It Works

The script establishes a sequential, nested tunnel architecture:
`System Traffic` ➔ `NetworkManager OpenVPN Interface` ➔ `Tor Network (Transparent Proxy)`

1. **VPN Verification:** Dynamically detects your active OpenVPN network interface (e.g., `tun0` or `vpn0`).
2. **NAT Redirection:** Bypasses local loopbacks, exempts NetworkManager to keep the core VPN alive, and forces all other system TCP and DNS requests directly into Tor's `TransPort` and `DNSPort`.
3. **Strict Kill-Switch:** Implements an `iptables` filter rule that explicitly rejects any non-loopback outbound traffic on the VPN interface that doesn't originate from the Tor daemon itself.

 📋 Prerequisites

Before running the script, ensure your system has the following components installed and configured:

* **Linux OS** (Tested on Arch Linux / Debian-based systems)
* **Tor** (with transparent proxying enabled in `torrc`)
* **iptables**
* **NetworkManager** (with an active OpenVPN profile)

### Tor Configuration (`/etc/tor/torrc`)
To allow this script to route system traffic, your Tor daemon must be configured to listen for transparent proxy and DNS requests. Append the following lines to your `/etc/tor/torrc` file:

  VirtualAddrNetworkIPv4 10.192.0.0/10
  
  AutomapHostsOnResolve 1
  
  TransPort 9040
  
  DNSPort 5353


!! Note: Restart your Tor service (sudo systemctl restart tor) after making these changes. !!

🛠️ Configuration Details
If your Linux distribution uses a different user for the Tor daemon, update the variable at the top of the script:

Arch Linux / Fedora: TOR_UID="tor"

Debian / Ubuntu: TOR_UID="debian-tor"

⚠️ Security Disclaimer
This script modifies system routing and firewall rules (iptables). While it includes a strict kill-switch to mitigate leaks, routing an entire operating system's traffic through Tor can still present unique fingerprinting risks (e.g., system updates, application user-agents, non-browser traffic). Use mindfully and verify your IP/DNS leak status using tools like dnsleaktest.com or check.torproject.org after activation.
