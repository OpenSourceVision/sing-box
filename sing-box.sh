#!/bin/bash
# ============================================================
# sing-box 管理工具（reF1nd 内核版）
# 配套内核源: https://github.com/reF1nd/sing-box-releases/releases
# 适用: Debian / Ubuntu（systemd），CLI 版（tar.gz 安装到 /usr/local/bin）
# 用法: bash sing-box.sh
# ============================================================

RELEASE_REPO="reF1nd/sing-box-releases"
BIN_PATH="/usr/local/bin/sing-box"
CONF_DIR="/etc/sing-box"
CONF_FILE="${CONF_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

# ---------- 状态查询 ----------

get_version() {
  if [ -x "$BIN_PATH" ]; then
    "$BIN_PATH" version 2>/dev/null | head -n 1 | awk '{print $3}'
  else
    echo "-"
  fi
}

is_installed() {
  [ -x "$BIN_PATH" ] && echo "已安装" || echo "未安装"
}

is_running() {
  if systemctl is-active --quiet sing-box 2>/dev/null; then
    echo "运行中"
  else
    echo "未运行"
  fi
}

# ---------- 版本号获取 ----------
# 参数: stable = 最新正式版 / beta = 最新测试版（含 pre-release）

get_tag() {
  local mode="$1"
  local tag=""
  echo "正在获取最新$([ "$mode" = "beta" ] && echo -n "测试" || echo -n "正式")版本号..."
  if [ "$mode" = "beta" ]; then
    if [ -n "$GITHUB_TOKEN" ]; then
      tag=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${RELEASE_REPO}/releases" \
        | grep '"tag_name"' | head -n 1 | sed 's/.*"v\(.*\)".*/\1/')
    else
      tag=$(curl -s "https://api.github.com/repos/${RELEASE_REPO}/releases" \
        | grep '"tag_name"' | head -n 1 | sed 's/.*"v\(.*\)".*/\1/')
    fi
  else
    if [ -n "$GITHUB_TOKEN" ]; then
      tag=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${RELEASE_REPO}/releases/latest" \
        | grep '"tag_name"' | head -n 1 | sed 's/.*"v\(.*\)".*/\1/')
    else
      tag=$(curl -s "https://api.github.com/repos/${RELEASE_REPO}/releases/latest" \
        | grep '"tag_name"' | head -n 1 | sed 's/.*"v\(.*\)".*/\1/')
    fi
  fi
  echo "$tag"
}

# ---------- 核心安装（参数: stable / beta）----------

do_install() {
  local mode="${1:-stable}"

  # 架构映射: x86_64 -> amd64, aarch64 -> arm64
  case "$(uname -m)" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    armv7l)  arch="armv7" ;;
    *) echo "不支持的架构: $(uname -m)"; return 1 ;;
  esac

  local tag
  tag=$(get_tag "$mode")
  if [ -z "$tag" ]; then
    echo "获取版本号失败，请检查网络（可设置 export https_proxy=http://IP:端口 后重试）"
    return 1
  fi

  local url="https://github.com/${RELEASE_REPO}/releases/download/v${tag}/sing-box-${tag}-linux-${arch}-glibc.tar.gz"
  local tmpfile="/tmp/sing-box-${tag}.tar.gz"

  echo "下载: $url"
  curl --fail -Lo "$tmpfile" "$url" || { echo "下载失败"; return 1; }

  echo "安装中..."
  tar -xzf "$tmpfile" -C /tmp
  install -m 755 "/tmp/sing-box-${tag}-linux-${arch}-glibc/sing-box" "$BIN_PATH"
  rm -rf "$tmpfile" "/tmp/sing-box-${tag}-linux-${arch}-glibc"

  # 配置文件（不覆盖已有配置）
  mkdir -p "$CONF_DIR"
  if [ ! -f "$CONF_FILE" ]; then
    cat > "$CONF_FILE" <<'EOF'
{
  "log": { "level": "info" },
  "inbounds": [],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
EOF
    echo "已生成默认配置: $CONF_FILE（请自行修改）"
  fi

  # systemd 服务（不覆盖已有服务文件）
  if [ ! -f "$SERVICE_FILE" ]; then
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${BIN_PATH} -D ${CONF_DIR} -C ${CONF_DIR} run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
  fi

  systemctl daemon-reload
  systemctl enable sing-box --now
  echo ""
  echo "安装完成！（$([ "$mode" = "beta" ] && echo -n "测试版" || echo -n "正式版" )）"
  "$BIN_PATH" version | head -n 1
  echo ""
  echo "=========================================="
  echo " 内核所在位置   : $BIN_PATH"
  echo " 配置文件所在位置: $CONF_FILE"
  echo " 配置目录       : $CONF_DIR"
  echo "=========================================="
  echo "提示: 以后在任意位置输入 sb 即可打开本管理工具"
  echo "下一步: 编辑 $CONF_FILE 后执行 systemctl restart sing-box"
}

do_uninstall() {
  if [ ! -x "$BIN_PATH" ]; then
    echo "sing-box 未安装"
    return 1
  fi
  printf "确认卸载？(配置目录 %s 会保留) [y/N]: " "$CONF_DIR"
  read -r confirm
  case "$confirm" in
    [yY]|[yY][eE][sS])
      systemctl stop sing-box 2>/dev/null
      systemctl disable sing-box 2>/dev/null
      rm -f "$SERVICE_FILE" "$BIN_PATH"
      systemctl daemon-reload
      echo "卸载完成。配置目录 $CONF_DIR 已保留，如需删除请手动 rm -rf $CONF_DIR"
      ;;
    *) echo "已取消" ;;
  esac
}

# ---------- 安装/更新 子菜单（正式版 / 测试版）----------
# 参数: "安装" 或 "更新"

version_submenu() {
  local action="$1"
  while true; do
    echo ""
    echo "--- $action sing-box ---"
    echo "1. 正式版（stable）"
    echo "2. 测试版（beta / pre-release）"
    echo "0. 返回主菜单"
    echo "----------------------"
    printf "请选择版本类型: "
    read -r vchoice
    case "$vchoice" in
      1) do_install stable; pause; return ;;
      2) do_install beta;   pause; return ;;
      0) return ;;
      *) ;;
    esac
  done
}

pause() {
  echo ""
  printf "按回车返回主菜单..."
  read -r
}

# ---------- 注册快捷命令 sb ----------
# 把本脚本复制到 /usr/local/bin/sb，以后在任意位置输入 sb 即可打开本工具

ensure_sb_command() {
  # 仅 root 可安装；非 root 直接跳过
  [ "$(id -u)" = "0" ] || return 0

  local self target="/usr/local/bin/sb"
  self=$(readlink -f "$0" 2>/dev/null || echo "$0")

  # 当前就是通过 sb 命令运行的，无需重复安装
  [ "$self" = "$target" ] && return 0

  # 脚本内容有变化（或首次运行）时才重新复制
  if [ ! -f "$target" ] || ! cmp -s "$0" "$target"; then
    if install -m 755 "$0" "$target" 2>/dev/null; then
      echo ""
      echo ">>> 已注册快捷命令: sb （以后在任意位置直接输入 sb 即可打开本工具）"
    fi
  fi
}

# ---------- 菜单 ----------

show_menu() {
  clear
  echo "=== sing-box 管理工具 ==="
  echo "安装状态: $(is_installed)"
  echo "运行状态: $(is_running)"
  echo "运行版本: $(get_version)"
  echo ""
  echo "1. 安装 sing-box 服务（正式版 / 测试版）"
  echo "2. 卸载 sing-box 服务"
  echo "3. 启动 sing-box"
  echo "4. 停止 sing-box"
  echo "5. 重启 sing-box"
  echo "6. 查看运行日志"
  echo "7. 更新 sing-box（正式版 / 测试版）"
  echo "0. 退出"
  echo "========================"
  printf "请输入选项编号: "
}

while true; do
  ensure_sb_command
  show_menu
  read -r choice
  echo ""
  case "$choice" in
    1) version_submenu "安装" ;;
    2) do_uninstall; pause ;;
    3) systemctl start sing-box && echo "已启动"; sleep 1 ;;
    4) systemctl stop sing-box && echo "已停止"; sleep 1 ;;
    5) systemctl restart sing-box && echo "已重启"; sleep 1 ;;
    6) journalctl -u sing-box -n 50 --no-pager; pause ;;
    7) version_submenu "更新" ;;
    0) exit 0 ;;
    *) ;;
  esac
done
