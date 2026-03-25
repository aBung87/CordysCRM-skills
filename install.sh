#!/bin/bash

# 设置仓库地址和目标安装路径
REPO_URL="https://github.com/1Panel-dev/CordysCRM-skills"
INSTALL_DIR="$HOME/.openclaw/workspace/skills/cordys-crm"
TEMP_DIR="$HOME/.openclaw/workspace/skills"

# 获取最新的 Git 标签
LATEST_TAG=$(curl -s https://api.github.com/repos/1Panel-dev/CordysCRM-skills/releases/latest | jq -r .tag_name)

# 检查是否成功获取到最新的标签
if [ "$LATEST_TAG" == "null" ] || [ -z "$LATEST_TAG" ]; then
  echo "无法获取最新的版本标签，可能是仓库没有发布版本。请检查 GitHub 仓库的发布设置。"
  exit 1
fi

echo "最新版本：$LATEST_TAG"

# 如果目标目录已存在，直接删除并覆盖
if [ -d "$INSTALL_DIR" ]; then
  echo "目标目录已存在，正在删除并覆盖现有目录..."
  rm -rf "$INSTALL_DIR"
fi

# 克隆指定版本的 CordysCRM-skills 仓库到临时目录
echo "正在克隆 CordysCRM-skills 仓库到临时目录..."
git clone --branch "$LATEST_TAG" "$REPO_URL" "$TEMP_DIR"

# 检查是否克隆成功
if [ ! -d "$TEMP_DIR/skills" ]; then
  echo "错误：克隆的仓库中没有找到 skills 目录。"
  exit 1
fi

# 复制 skills 目录并重命名到目标目录
echo "正在将 skills 目录复制到目标目录并重命名..."
cp -R "$TEMP_DIR/skills" "$INSTALL_DIR"

# 清理临时目录
echo "清理临时克隆的仓库..."
rm -rf "$TEMP_DIR"

echo "安装完成！"