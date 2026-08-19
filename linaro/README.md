# AI Monitor RK3576 基础环境迁移包（linaro）

该目录是面向部署机 `linaro@192.168.254.107` 的独立暂存包。它不修改上级目录中的原始脚本或原始 `basic-env-deps.tar.gz`。

## 设计边界

- 目标系统固定为 Ubuntu 22.04 arm64 / RK3576。
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
- `build-clean-package.sh`：在开发机上从上级原始包重新生成清理包。
- `SHA256SUMS`：迁移文件校验和。

## 当前目标机已知情况

- Ubuntu 22.04.5 arm64，RK3576。
- RKNPU 驱动为 v0.9.8，与开发机一致。
- MPP/RGA 包版本与开发机一致，安装时应被跳过。
- `/usr/lib/librknnrt.so` 比开发机版本旧，且缺少 `/usr/include/rknn_api.h`。
- 尚缺少 `ffmpeg-rk`、ZLMediaKit、Nginx、SQLite、jemalloc、pip、Java、rsync 等组件。
- TCP 5555 已被 `adbd` 占用；后续业务部署必须将 Infer/Python 的 ZMQ 端口统一改为 5556。

## 使用顺序

先将整个 `linaro` 目录复制到部署机，例如 `/home/linaro/ai-monitor-basic-env-install`。

第一步只读检查：

```bash
cd /home/linaro/ai-monitor-basic-env-install
./preflight.sh
```

第二步安装基础环境（会修改目标机，必须在获得授权后执行）：

```bash
cd /home/linaro/ai-monitor-basic-env-install
sudo ./install.sh
```

第三步只读验证：

```bash
cd /home/linaro/ai-monitor-basic-env-install
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

