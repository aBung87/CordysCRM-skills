#!/bin/bash

# 设置仓库地址和目标安装路径
REPO_URL="https://github.com/1Panel-dev/CordysCRM-skills"
INSTALL_DIR="$HOME/.openclaw/workspace/skills/cordys-crm"

# 获取最新的 Git 标签
LATEST_TAG=$(curl -s https://api.github.com/repos/1Panel-dev/CordysCRM-skills/releases/latest | jq -r .tag_name)

# 检查是否成功获取到最新的标签
if [ -z "$LATEST_TAG" ]; then
  echo "无法获取最新的版本标签，请检查网络或 GitHub API。"
  exit 1
fi

echo "最新版本：$LATEST_TAG"

# 如果目标目录已存在，先删除它
if [ -d "$INSTALL_DIR" ]; then
  echo "目标目录已存在，删除原有安装目录..."
  rm -rf "$INSTALL_DIR"
fi

# 克隆指定版本的 CordysCRM-skills 仓库
echo "正在克隆 CordysCRM-skills 仓库..."
git clone --branch "$LATEST_TAG" "$REPO_URL" "$INSTALL_DIR"

# 复制 skills 目录到目标路径
echo "正在复制 skills 目录..."
cp -R "$INSTALL_DIR/skills" "$INSTALL_DIR"

echo "安装完成！"