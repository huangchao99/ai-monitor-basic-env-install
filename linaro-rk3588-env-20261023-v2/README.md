# AI Monitor RK3588 基础环境迁移包（linaro）

当前版本：`linaro-rk3588-env-20261023-v2`。2026-10-23 更新包内 ZLMediaKit 录像缓存，支持报警前置视频证据；保留原有 APT 候选包检测修正。

目录名与版本号统一为 `linaro-rk3588-env-20261023-v2`。

该目录是面向 RK3588/RK3588S 部署机的独立暂存包。它不修改 RK3576 暂存包或上级目录中的原始资源。

## 设计边界

- 目标系统固定为 Ubuntu 22.04 arm64 / RK3588 或 RK3588S。
- 默认运行用户为 `linaro`，可通过 `AI_MONITOR_RUN_USER` 覆盖。
- 安装 MPP/RGA 时，版本已是 `1.5.0-1` / `2.2.0-1` 会直接跳过。
- 如果目标机已安装其他 MPP/RGA 版本，脚本默认中止，不会自动覆盖。
- 替换 RKNN Runtime、`/opt/ffmpeg-rk`、`/opt/ZLMediaKit` 前会备份到 `/var/backups/ai-monitor-basic-env/<时间戳>/`。
- 安装脚本不会安装 systemd 服务，也不会启动或停止任何服务。
- 清理后的资源包不包含 ZLMediaKit 开发期录像、截图、日志和 Git 元数据。

## 文件说明

- `basic-env-install-package.tar.gz`：清理后的离线硬件运行时资源。
- `preflight.sh`：完全只读的部署前检查。
- `install.sh`：基础环境安装脚本。
- `verify.sh`：安装后的只读验证。
- `SHA256SUMS`：迁移文件校验和。

## 当前目标机已知情况（aitest5）

- Ubuntu 22.04.5 arm64，Rockchip RK3588S EVB4。
- NPU、MPP、RGA、DRM 设备节点均存在。
- MPP/RGA 包版本与开发机一致，安装时应被跳过。
- 当前 RKNN Runtime 为 `2.0.0b0`，模型由 Toolkit `2.3.2` 生成；安装包会备份旧文件并安装 Runtime `2.3.2`。
- 尚缺少 `ffmpeg-rk`、ZLMediaKit、Nginx、SQLite、jemalloc、pip、Java、rsync 等组件。
- GPS 为 `/dev/ttyS4`、9600 波特率；`linaro` 已属于 `dialout` 组。
- TCP 5555 已占用；后续业务部署将 Infer/Python 的 ZMQ 端口统一设为 5556。

## 使用顺序

先将本目录列出的发布文件复制到部署机上的独立目录，例如 `/home/linaro/linaro-rk3588-env-20261023-v2`。

第一步只读检查：

```bash
cd /home/linaro/linaro-rk3588-env-20261023-v2
./preflight.sh
```

第二步安装基础环境（会修改目标机，必须在获得授权后执行）：

```bash
cd /home/linaro/linaro-rk3588-env-20261023-v2
sudo ./install.sh
```

第三步只读验证：

```bash
cd /home/linaro/linaro-rk3588-env-20261023-v2
sudo ./verify.sh
```

## APT 说明

安装脚本默认先执行 `apt-get update`，然后安装业务运行及后续应用安装需要的依赖。Java 包按以下顺序选择第一个存在候选版本的包：

1. `openjdk-8-jdk`
2. `openjdk-8-jre-headless`
3. `default-jre-headless`

TurboJPEG 在 `libturbojpeg` 与 `libturbojpeg0` 中选择可用项。

如果现场已经人工更新过 APT 索引，可显式跳过：

```bash
sudo AI_MONITOR_SKIP_APT_UPDATE=1 ./install.sh
```

## MPP/RGA 版本保护

目标机当前版本与包内一致，不需要覆盖。如果以后在另一台机器发现版本不一致，脚本会停止。只有完成兼容性评估后才能显式允许替换：

```bash
sudo AI_MONITOR_ALLOW_ROCKCHIP_PACKAGE_REPLACE=1 ./install.sh
```

不要在当前目标机上使用该参数。

## 不在本包范围内

- AI Monitor Go/Python/前端/Infer 业务程序。
- `/etc/ai-monitor` 现场配置。
- systemd 服务和 Nginx 站点配置。
- 数据库、摄像头、任务、告警、截图、人脸库等业务数据。

## 2026-10-23 报警视频缓存更新

- 离线资源包内 `ZLMediaKit/config.ini` 的 `[rtp_proxy] gop_cache` 从 `1` 改为 `16`。完整安装时会安装该配置，`verify.sh` 检查其不小于 16。
- GOP 是关键帧间的一段视频，不是秒。以常见 1～2 秒关键帧间隔留出报警前最长 10 秒的缓存余量；高帧率、极密关键帧或内部缓存条目上限仍需现场验证。扩大公共缓存会增加每路代理流的内存占用。
- 保持 `enable_mp4=0`，不会开启全天持续录像；是否生成报警视频由业务应用的每算法录像开关决定。摄像头代理流、业务录像配置和数据库由应用管理。
- 本次未替换 ZLM/FFmpeg/RKNN 二进制，也未修改 HTTP 端口、API 密钥、MPP/RGA 或 APT 安装策略。资源包逐项比对，仅 ZLM 配置文件内容发生变化。
- 现有设备只为扩大缓存，无需重装整个基础环境。在维护窗口备份并修改实际使用的 ZLM 配置，然后重启 ZLM、恢复代理流并验证新录像。已经生成的短视频不能补回。
- `install-deps-only.sh` 只安装 APT 依赖，不复制 ZLM 资源，因此单独运行它不会应用此次缓存更新。
- 本基础环境包不包含 Go/Python/前端的录像功能代码；仍需同步更新应用包，并保持 Python 与 Go 的 ZLM 地址、密钥及证据目录配置一致。

发布文件的 `SHA256SUMS` 已重新生成，包含 `install-deps-only.sh`。此次更新前的完整目录另存于上级 `backups/deploy-90005-before-alarm-video-*`，备份无需复制到部署机。
