#!/bin/bash

# 设置仓库地址和目标安装路径
REPO_URL="https://github.com/1Panel-dev/CordysCRM-skills"
INSTALL_DIR="$HOME/.openclaw/workspace/skills/cordys-crm"

# 获取最新的 Git 标签
LATEST_TAG=$(curl -s https://api.github.com/repos/1Panel-dev/CordysCRM-skills/releases/latest | jq -r .tag_name)

# 检查是否成功获取到最新的标签
if [ "$LATEST_TAG" == "null" ] || [ -z "$LATEST_TAG" ]; then
  echo "无法获取最新的版本标签，可能是仓库没有发布版本。请检查 GitHub 仓库的发布设置。"
  exit 1
fi

echo "最新版本：$LATEST_TAG"

# 如果目标目录已存在，提示用户是否覆盖
if [ -d "$INSTALL_DIR" ]; then
  echo "目标目录已存在：$INSTALL_DIR"
  read -p "确定要覆盖已有的 skills 目录吗？[yes/no]: " user_input
  if [[ "$user_input" != "yes" ]]; then
    echo "安装取消。"
    exit 0
  fi
  echo "正在删除并覆盖现有目录..."
  rm -rf "$INSTALL_DIR"
fi

# 克隆指定版本的 CordysCRM-skills 仓库
echo "正在克隆 CordysCRM-skills 仓库..."
git clone --branch "$LATEST_TAG" "$REPO_URL" "$INSTALL_DIR"

# 强制覆盖 skills 目录
echo "正在覆盖 skills 目录..."
rm -rf "$INSTALL_DIR/skills"  # 删除已存在的 skills 目录
cp -R "$INSTALL_DIR/skills" "$INSTALL_DIR"  # 复制新的 skills 目录

echo "安装完成！"