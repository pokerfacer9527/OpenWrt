#!/bin/bash

# 1. 获取所有物理网卡接口（排除 lo 和 虚拟网卡）
INTERFACES=$(ls /sys/class/net | grep -E 'eth|enp|eno' | sort)
# 获取网卡总数
COUNT=$(echo "$INTERFACES" | wc -l)

if [ "$COUNT" -gt 1 ]; then
    # 最后一个网卡作为 WAN
    WAN_IF=$(echo "$INTERFACES" | tail -n 1)
    # 其余网卡作为 LAN
    LAN_IFS=$(echo "$INTERFACES" | head -n $((COUNT - 1)))

    # 2. 配置 LAN (包含 IP 修改)
    uci set network.lan.device='br-lan'
    uci set network.lan.ipaddr='192.168.2.1'
    uci set network.lan.netmask='255.255.255.0'
    
    # 清空旧的 bridge 成员并添加新的
    uci del network.lan.ports
    for iface in $LAN_IFS; do
        uci add_list network.lan.ports="$iface"
    done

    # 3. 配置 WAN
    uci set network.wan=interface
    uci set network.wan.proto='dhcp'
    uci set network.wan.device="$WAN_IF"
    
    # 4. 配置 WAN6 (可选)
    uci set network.wan6=interface
    uci set network.wan6.proto='dhcpv6'
    uci set network.wan6.device="$WAN_IF"

    uci commit network
fi

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

exit 0
