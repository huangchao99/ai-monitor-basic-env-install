# 192.168.254.103 基础环境安装记录

日期：2026-10-10；目标用户：linaro；Ubuntu 22.04.5 arm64 / RK3588S。

源：../linaro-rk3588。原运行库压缩包 SHA256 校验通过；源目录 install.sh 和 verify.sh 已更新而 SHA256SUMS 未同步，本副本核查内容和 Bash 语法后重新生成校验清单。原目录未修改。

本次已完成基础环境安装。verify.sh 返回 failures=0，dpkg --audit 无异常。

- Runtime 已从 2.0.0b0 升级为 2.3.2。
- 旧 Runtime 备份：/var/backups/ai-monitor-basic-env/20261010-165307/usr/lib/librknnrt.so。
- MPP 1.5.0-1、RGA 2.2.0-1 与包内一致，安装脚本跳过替换。
- 硬件 FFmpeg、ZLMediaKit 已安装，两者动态库解析正常；FFmpeg 列出 H264/HEVC 等 rkmpp 解码器。
- 新装 38 个 APT 包，0 升级、0 删除；包括 Nginx、SQLite CLI、jemalloc、pip/venv、rsync、TurboJPEG、OpenJDK 8。
- Python 3.10.12 虚拟环境创建和环境内 pip 调用验证通过。
- Nginx 由 APT 包安装时自动启用并启动，目前占用 80，仍为默认站点。
- ZLMediaKit 和智能监控业务服务尚未安装为 systemd 服务或启动。
- TCP 5555 保留给 adbd；业务包统一使用 5556。

安装过程处理：USB 默认路由无法访问软件源，临时为软件源 IPv4 地址添加经 WLAN 的 /32 路由，结束已清除。没有更改默认路由或持久网络配置。APT 索引已通过 WLAN 更新。目标机启用 jammy-proposed 且大量软件包被 hold，本次通过独立 apt-preferences 排除 proposed 候选，使用正式仓库，不修改系统 sources.list 或全局 APT 配置。

文件：apt-ipv4.conf、apt-preferences、install-target.sh 是本目标机的安装辅助文件，含固定目标目录及 WLAN 网关，仅适用于本机环境。install-target.sh 跳过更新索引是因为本次索引已经更新，未来安装前应重新检查索引和网络；不要将其作为其他机器的通用安装入口。

尚未验证实际摄像头硬件解码、NPU 模型推理或 GPS 报文，这些属于后续业务部署验收。
