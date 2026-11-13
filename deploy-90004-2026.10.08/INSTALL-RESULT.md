# 90004 基础环境安装结果

日期：2026-10-08。目标 LAN IP：192.168.110.160。

连接：`ssh -o ProxyCommand='nc -X connect -x frp.dtu2.xyz:5002 %h %p' linaro@90004.frp.dtu2.xyz`。

## 包来源

- 原目录：`/home/hzhy/ai-monitor-basic-env-install/linaro-rk3588`。
- 原压缩包 SHA256 校验通过；归档内 RKNN Runtime 确认为 2.3.2。
- install.sh、verify.sh 与 Git 提交 a7c21a3 一致；原校验清单未随脚本更新。
- 在独立副本重新生成校验清单，原目录未修改。
- 部署版本：2026.10.08-linaro-rk3588-90004-v1。

## 目标机与安装

- RK3588S EVB4、Ubuntu 22.04.5 arm64，内存约 8 GiB。
- 目标安装目录：`/home/linaro/ai-monitor-basic-env-2026.10.08-90004`。
- APT 索引更新成功；安装模拟为新增 38 包、升级 0、删除 0。
- 安装命令：`sudo env AI_MONITOR_SKIP_APT_UPDATE=1 DEBIAN_FRONTEND=noninteractive ./install.sh`。
- 安装成功，旧 Runtime 备份在 `/var/backups/ai-monitor-basic-env/20261008-172518/usr/lib/librknnrt.so`。
- MPP 1.5.0-1、RGA 2.2.0-1 原版本保留。
- RKNN Runtime：2.0.0b0 → 2.3.2；RKNPU 驱动 v0.9.8。
- 已安装 `/opt/ffmpeg-rk`、`/opt/ZLMediaKit`，以及 Java 8、Nginx、SQLite、rsync、Python venv/pip 等依赖。

## 验证与下一步

- `sudo ./verify.sh`：failures=0。
- FFmpeg/ZLMediaKit 动态库无缺失；FFmpeg 列出 h264_rkmpp、hevc_rkmpp 等解码器。
- Nginx active，系统包安装后自动启动；尚未安装 AI Monitor 业务服务单元。
- 尚未执行实际摄像头解码和 RKNN 模型推理；应在业务部署后验证。
- 5555 已占用，后续业务配置使用 5556。
- GPS `/dev/ttyS4` 存在且可访问，但未验证有效 NMEA 数据。
- 下一阶段：构建当前代码的 RK3588 业务包，核对模型和数据库种子、配置后再部署。

目标机日志：安装目录下 `apt-update.log`、`install-console.log`、`verify.log` 和 `logs/`。
