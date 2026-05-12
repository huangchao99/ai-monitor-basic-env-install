# 智能监控基础环境安装包

本目录用于安装 AI 智能监控项目的基础环境依赖，不包含应用发布包本身。

安装范围：

- Rockchip MPP 运行库和开发包
- Rockchip RGA 运行库和开发包
- RKNN Runtime 动态库和头文件
- `ffmpeg-rk`
- `ZLMediaKit`
- 基础系统依赖包

不包含：

- `ai-monitor-release` 应用发布包安装
- `/etc/ai-monitor/` 配置生成
- `systemd` 服务安装
- 数据库初始化

## 目录说明

- `basic-env-install-package/`
  - 基础环境离线资源
- `basic-env-install-package.zip`
  - 可选压缩包形式；若目录不存在，`install.sh` 会先自动解压
- `install.sh`
  - 一键安装脚本
- `uninstall.sh`
  - 卸载脚本
- `logs/`
  - 安装和卸载日志目录，脚本运行后自动生成

## 环境要求

- Ubuntu 20.04 或 22.04
- `arm64`
- 默认具有 `sudo` 权限
- 需要联网执行 `apt-get update` 和 `apt-get install`

## 安装内容

### apt 安装的系统包

脚本会联网安装以下依赖：

```text
git
build-essential
yasm
pkg-config
libdrm-dev
libx264-dev
libx265-dev
libvpx-dev
libfdk-aac-dev
libmp3lame-dev
libopus-dev
libturbojpeg
libzmq5
libjemalloc2
sqlite3
python3
python3-venv
python3-pip
openjdk-8-jdk
nginx
```

### 离线安装的资源

- `mpp/` 中的运行包和 `-dev` 包
- `rga2/` 中的运行包和 `-dev` 包
- `librknnrt.so` -> `/usr/lib/librknnrt.so`
- `rknn_api.h` -> `/usr/include/rknn_api.h`
- `ffmpeg-rk/` -> `/opt/ffmpeg-rk`
- `ZLMediaKit/` -> `/opt/ZLMediaKit`

说明：

- `dbgsym` 包不会安装
- 如果只有 `basic-env-install-package.zip`，安装脚本会先自动解压出 `basic-env-install-package/`
- 如果 `/opt/ffmpeg-rk` 或 `/opt/ZLMediaKit` 已存在，安装脚本会先备份为 `.bak.时间戳`

## 使用方法

安装：

```bash
cd /home/hzhy/ai-monitor-basic-env-install
chmod +x install.sh uninstall.sh
./install.sh
```

如果当前用户不是 root，脚本会自动使用 `sudo`。

## 卸载方法

```bash
cd /home/hzhy/ai-monitor-basic-env-install
./uninstall.sh
```

卸载脚本会移除：

- `/usr/lib/librknnrt.so`
- `/usr/include/rknn_api.h`
- `/opt/ffmpeg-rk`
- `/opt/ZLMediaKit`
- `mpp/rga` 的运行包和 `-dev` 包

卸载脚本不会移除这些通用系统依赖：

- `python3`
- `python3-pip`
- `nginx`
- `sqlite3`
- `openjdk-8-jdk`
- 其他通过 `apt` 安装的公共包

这是刻意保守处理，避免误伤系统上其他项目。

## 日志

安装日志示例：

```text
logs/install-YYYYMMDD-HHMMSS.log
```

卸载日志示例：

```text
logs/uninstall-YYYYMMDD-HHMMSS.log
```

## 安装完成后的建议检查

可手工确认以下文件存在：

```bash
ls -l /usr/lib/librknnrt.so
ls -l /usr/include/rknn_api.h
ls -l /opt/ffmpeg-rk/bin/ffmpeg
ls -l /opt/ZLMediaKit/MediaServer
```

也可确认关键包：

```bash
dpkg -s librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0
dpkg -s librga2 librga-dev
dpkg -s libjemalloc2 libzmq5 sqlite3 python3 python3-pip openjdk-8-jdk nginx
```

## 注意事项

- 当前脚本默认走在线 `apt` 安装，目标机无网络时会失败。
- 当前脚本固定按 Ubuntu ARM64 基础环境设计。
- `ZLMediaKit/config.ini` 中已引用 `/opt/ffmpeg-rk/bin/ffmpeg`，因此不要随意修改这两个目录的安装位置。
