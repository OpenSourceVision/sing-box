# sing-box 管理工具（reF1nd 内核版）

一个开箱即用的 sing-box 一键安装与管理脚本。内核下载源为 [reF1nd/sing-box-releases](https://github.com/reF1nd/sing-box-releases/releases)，支持正式版 / 测试版切换、systemd 服务管理，并自动注册 `sb` 快捷命令。

## 一键使用（远程调用）

在 Debian / Ubuntu 服务器上以 root 执行：

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/OpenSourceVision/sing-box/main/sing-box.sh)
```

> ⚠️ 不建议用 `curl ... | bash` 的方式运行：管道方式会导致交互式菜单无法正常输入。请使用上面的 `bash <(...)` 写法，或先下载再执行：
>
> ```sh
> curl -fsSL -o /tmp/sing-box.sh https://raw.githubusercontent.com/OpenSourceVision/sing-box/main/sing-box.sh
> bash /tmp/sing-box.sh
> ```

国内网络不好时，可用 jsDelivr CDN：

```sh
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/OpenSourceVision/sing-box@main/sing-box.sh)
```

**首次运行后，脚本会自动把自己注册为 `/usr/local/bin/sb`**，以后在任意位置直接输入：

```sh
sb
```

即可打开管理菜单，无需再次远程调用。

## 功能菜单

```
=== sing-box 管理工具 ===
安装状态: 未安装
运行状态: 未运行
运行版本: -

1. 安装 sing-box 服务（正式版 / 测试版）
2. 卸载 sing-box 服务
3. 启动 sing-box
4. 停止 sing-box
5. 重启 sing-box
6. 查看运行日志
7. 更新 sing-box（正式版 / 测试版）
0. 退出
```

### 版本类型

| 选项 | 说明 | 来源 |
|------|------|------|
| 正式版（stable） | 最新正式发布版 | `releases/latest`（自动排除 pre-release） |
| 测试版（beta） | 最新 pre-release（如 1.15.0-alpha.x） | `releases` 列表中第一个 `prerelease: true` 的条目 |

安装 / 更新完成后会显示：

```
==========================================
 内核所在位置   : /usr/local/bin/sing-box
 配置文件所在位置: /opt/sing-box/config.json
 配置目录       : /opt/sing-box
==========================================
提示: 以后在任意位置输入 sb 即可打开本管理工具
```

## 安装内容说明

| 项目 | 路径 / 说明 |
|------|-------------|
| 内核二进制 | `/usr/local/bin/sing-box`（CLI 版，取 `linux-<arch>-glibc` tar.gz） |
| 配置文件 | `/opt/sing-box/config.json`（已有配置不会被覆盖，目录权限开放可直接用 SFTP 编辑） |
| systemd 服务 | `/etc/systemd/system/sing-box.service`（自动 enable） |
| 快捷命令 | `/usr/local/bin/sb`（脚本自身，内容变化时自动更新） |
| 管理工具菜单 | 安装 / 卸载 / 启动 / 停止 / 重启 / 日志 / 更新 |

## 支持的系统与架构

| 架构（uname -m） | 下载包 | 状态 |
|------------------|--------|------|
| x86_64 | `sing-box-<版本>-linux-amd64-glibc.tar.gz` | ✅ |
| aarch64 | `sing-box-<版本>-linux-arm64-glibc.tar.gz` | ✅ |
| armv7l | `sing-box-<版本>-linux-armv7-glibc.tar.gz` | ✅ |
| 其他 | — | ❌ |

要求：Debian / Ubuntu 等 systemd 发行版；Alpine（OpenRC）暂不支持。

## 安装后常用命令

```sh
sb                                  # 打开管理菜单
systemctl status sing-box           # 查看服务状态
journalctl -u sing-box -f           # 实时跟踪日志
```

修改配置后需重启服务：

```sh
systemctl restart sing-box
```

## 卸载

管理菜单选 `2. 卸载 sing-box 服务`（会保留 `/opt/sing-box` 配置目录）。如需彻底清理：

```sh
systemctl stop sing-box && systemctl disable sing-box
rm -f /usr/local/bin/sing-box /usr/local/bin/sb /etc/systemd/system/sing-box.service
rm -rf /opt/sing-box
```

## 常见问题

### 下载内核很慢 / 直连失败

脚本内置了 GitHub 加速代理（默认 `https://ghfast.top/`），下载失败时会自动回退直连。如需更换或关闭代理，编辑脚本顶部的 `GH_PROXY` 变量，或运行前用环境变量覆盖：

```sh
export GH_PROXY=""                        # 关闭代理，直连下载
export GH_PROXY="https://其他镜像地址/"    # 换用其他加速镜像
```

> 脚本 API 请求（获取版本号）走的是 `api.github.com`，不走该代理；网络完全不通时可配合 `export https_proxy=http://IP:端口` 使用。

### GitHub 访问受限 / 下载失败

设置代理后运行（按实际代理地址修改）：

```sh
export https_proxy=http://192.168.110.110:7890
sb
```

或使用 GitHub Token 提高 API 限额（可选）：

```sh
export GITHUB_TOKEN=ghp_你的token
sb
```

### 提示获取版本号失败

网络无法访问 `api.github.com`，先配置代理或 GITHUB_TOKEN，或改用上面的 jsDelivr 入口下载脚本本体。

### 下载 404

对应版本的架构包不存在或版本号有变，可查看所有可用版本：

```sh
curl -s https://api.github.com/repos/reF1nd/sing-box-releases/releases | grep tag_name
```

## 致谢

- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) — sing-box 内核
- [reF1nd/sing-box-releases](https://github.com/reF1nd/sing-box-releases) — 内核发布仓库
- [sing-box 官方安装脚本](https://sing-box.app/install.sh) — 原始脚本参考

## 免责声明

本项目仅供学习交流使用，请遵守所在地区法律法规，使用风险自负。
