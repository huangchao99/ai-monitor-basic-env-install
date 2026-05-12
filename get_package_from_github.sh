#!/bin/bash
set -e

# 依赖包下载链接（替换成你实际的 Releases 链接）
DEPS_URL="https://github.com/huangchao99/ai-monitor-basic-env-install/releases/download/v1.0.0/basic-env-deps.tar.gz"

echo "正在下载基础环境依赖包..."
# 尝试用 wget 或 curl 下载
if command -v wget &> /dev/null; then
    wget -O deps.tar.gz "$DEPS_URL"
else
    curl -L -o deps.tar.gz "$DEPS_URL"
fi

echo "解压中..."
tar -xzf deps.tar.gz

#echo "开始安装..."
# 这里写你原来的安装逻辑，比如拷贝 .so 文件等
#cd basic-env-install-package
# ... 你的 install.sh 原有内容 ...

#echo "安装完成！"
