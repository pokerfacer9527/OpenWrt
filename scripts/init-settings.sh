#!/bin/bash

# 1. 获取所有物理网卡列表
INTERFACES=$(ls /sys/class/net | grep -E 'eth|enp|eno' | sort)
COUNT=$(echo "$INTERFACES" | wc -l)

# 2. 无论几个网口，先强制设置基础 LAN IP
uci set network.lan.ipaddr='192.168.2.1'

# 3. 根据网口数量分配 WAN/LAN
if [ "$COUNT" -gt 1 ]; then
    # 多网口逻辑：最后一个给 WAN，其余给 LAN
    WAN_IF=$(echo "$INTERFACES" | tail -n 1)
    LAN_IFS=$(echo "$INTERFACES" | head -n $((COUNT - 1)))

    # 清空旧的接口绑定，重新绑定 LAN 物理口
    uci del network.lan.device
    uci set network.lan.device='br-lan'
    uci del_list network.lan.ports
    for iface in $LAN_IFS; do
        uci add_list network.lan.ports="$iface"
    done

    # 配置 WAN
    uci set network.wan=interface
    uci set network.wan.proto='dhcp'
    uci set network.wan.device="$WAN_IF"
else
    # 单网口逻辑：唯一的口给 LAN
    SINGLE_IF=$(echo "$INTERFACES")
    uci set network.lan.device="$SINGLE_IF"
    # 单网口通常不需要 WAN，或者后续手动添加虚拟 WAN
    uci del network.wan
fi

uci commit network

# Set default theme to luci-theme-argon
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

exit 0
