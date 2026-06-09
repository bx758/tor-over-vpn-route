#!/bin/bash

TOR_UID="tor"
TRANS_PORT="9040"
DNS_PORT="5353"
TOR_SERVICE="tor"

# --- DETECT VPN INTERFACE ---
VPN_INTERFACE=$(ip route | grep -E '^default dev (tun|vpn)[0-9]' | awk '{print $3}' | head -n 1)
if [ -z "$VPN_INTERFACE" ]; then
    VPN_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tun|vpn)[0-9]' | head -n 1)
fi

start_tor() {
    if [ -z "$VPN_INTERFACE" ]; then
        echo "[-] Error: No active OpenVPN interface found."
        echo "    Please connect your OpenVPN connection in NetworkManager first!"
        exit 1
    fi

    echo "[+] Active VPN interface detected: $VPN_INTERFACE"
    echo "[+] Starting Tor..."
    systemctl start $TOR_SERVICE

    # Clear existing rules cleanly
    iptables -F
    iptables -t nat -F

    # ==================== 1. NAT TABLE (TRAFFIC REDIRECTION) ====================
    
    # Rule 1: Skip local loopback networks immediately 
    iptables -t nat -A OUTPUT -d 127.0.0.0/8 -j RETURN

    # Rule 2: Exempt NetworkManager's service slice so your OpenVPN stays alive.
    iptables -t nat -A OUTPUT -m cgroup --path "system.slice/NetworkManager.service" -j RETURN

    # Rule 3: Allow Tor daemon user to talk out across the OpenVPN interface
    iptables -t nat -A OUTPUT -o "$VPN_INTERFACE" -m owner --uid-owner $TOR_UID -j RETURN

    # Rule 4: Route system DNS requests strictly to Tor's DNS port
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT

    # Rule 5: Force all other system TCP traffic into Tor's transparent port
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports $TRANS_PORT


    # ==================== 2. FILTER TABLE (KILL-SWITCH & EXEMPTIONS) ====================
    
    # RULE 6: Allow all already ESTABLISHED or RELATED sockets to bypass rules.
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Rule 7: Absolute loopback pass-through 
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT

    # Rule 8: Allow the Tor user to use the VPN interface completely
    iptables -A OUTPUT -o "$VPN_INTERFACE" -m owner --uid-owner $TOR_UID -j ACCEPT

    # Rule 9: Allow DNS packets through the filter table so they can hit the NAT redirect engine
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # Rule 10: THE LEAK-PROOF KILL-SWITCH
    iptables -A OUTPUT -o "$VPN_INTERFACE" ! -d 127.0.0.0/8 -j REJECT

    echo "[+] Nested Tunnel Active: System -> NetworkManager VPN ($VPN_INTERFACE) -> Tor Network"
}

stop_tor() {
    echo "[-] Disabling Tor proxy..."
    iptables -F
    iptables -t nat -F
    systemctl stop $TOR_SERVICE
    echo "[+] Tor proxy disabled. OpenVPN connection and system DNS remain active."
}

case "$1" in
    start) start_tor ;;
    stop) stop_tor ;;
    restart) stop_tor; start_tor ;;
    *) echo "Usage: $0 {start|stop|restart}"; exit 1 ;;
esac
