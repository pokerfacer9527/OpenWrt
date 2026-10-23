#!/bin/bash
# 预置 OpenClash 内核 + GeoIP/GeoSite
#
# 2026-10 修复说明：
#   OpenClash 的 core 分支已删除 dev/ 与 premium/ 两个目录，只剩 meta/ 与 smart/。
#   原脚本写死 dev + premium，导致：curl 404 -> gunzip/tar 报错 -> 把 0 字节内核文件打进固件
#   （编译不报错，但刷机后 OpenClash 起不来）。现改为：
#     1) 只从仍然存活的 meta/ 下载内核；
#     2) 全部下载到临时文件并校验非空、可解包后才落盘，失败则不留空文件；
#     3) 用 Meta 内核填充 clash / clash_tun 槽位，避免固件里出现 0 字节内核。
set -u

ARCH="${1:-amd64}"
CORE_DIR="files/etc/openclash/core"
mkdir -p "$CORE_DIR"

BASE="https://raw.githubusercontent.com/vernesong/OpenClash/core/master"
META_URL="$BASE/meta/clash-linux-${ARCH}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

# fetch_core <url> <输出文件> <说明>
fetch_core() {
  _url="$1"; _out="$2"; _desc="$3"; _tmp="/tmp/core-dl.$$"
  rm -f "$_tmp" "$_out"
  if curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 20 --max-time 900 "$_url" -o "$_tmp" \
     && [ -s "$_tmp" ] && tar tzf "$_tmp" >/dev/null 2>&1; then
    if tar xzOv --file "$_tmp" > "$_out" 2>/dev/null && [ -s "$_out" ]; then
      chmod +x "$_out"
      echo "[ok]   ${_desc}: $(basename "$_out") $(wc -c < "$_out") bytes"
    else
      echo "[FAIL] ${_desc}: 解包失败 -> $_url"
      rm -f "$_out"
    fi
  else
    echo "[FAIL] ${_desc}: 下载失败 -> $_url"
    rm -f "$_out"
  fi
  rm -f "$_tmp"
}

# fetch_data <url> <输出文件> <说明>
fetch_data() {
  _url="$1"; _out="$2"; _desc="$3"
  if curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 20 --max-time 900 "$_url" -o "$_out" && [ -s "$_out" ]; then
    echo "[ok]   ${_desc}: $(wc -c < "$_out") bytes"
  else
    echo "[FAIL] ${_desc} -> $_url"
    rm -f "$_out"
  fi
}

# 1) Meta 内核（现行 OpenClash 默认内核）
fetch_core "$META_URL" "$CORE_DIR/clash_meta" "Meta 内核"

# 2) 原版(dev)/Tun(premium) 内核上游已删除，无法预置；
#    用 Meta 内核填坑，避免 OpenClash 因核心文件缺失/0 字节而报错。
if [ -s "$CORE_DIR/clash_meta" ]; then
  cp -f "$CORE_DIR/clash_meta" "$CORE_DIR/clash"
  cp -f "$CORE_DIR/clash_meta" "$CORE_DIR/clash_tun"
  echo "[info] 已用 Meta 内核填充 clash / clash_tun（上游 dev、premium 目录已删除）"
fi

# 3) GeoIP / GeoSite
fetch_data "$GEOIP_URL"  "files/etc/openclash/GeoIP.dat"  "GeoIP.dat"
fetch_data "$GEOSITE_URL" "files/etc/openclash/GeoSite.dat" "GeoSite.dat"

chmod +x "$CORE_DIR"/clash* 2>/dev/null
echo "----- ${CORE_DIR} -----"
ls -la "$CORE_DIR" || true
echo "----- files/etc/openclash -----"
ls -la files/etc/openclash || true
