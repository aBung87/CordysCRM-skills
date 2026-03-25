# Cordys CRM Skill for OpenClaw

像与人交谈一样与你的 **Cordys CRM 工作区**交互。  
商机、联系人、潜在客户 —— 全部通过自然对话与你的 AI 助理完成。

这个 Skill 将 **Cordys CRM CLI** 包装进 **OpenClaw 会话环境**：

1. 你用自然语言描述需求
2. AI 解析意图
3. 自动转换为 `cordys` CLI 命令
4. 执行 API 请求并返回结果

借助 Prompt 的动态调优机制，用户可以在 **不修改任何代码**的情况下控制：

- 输出格式
- 过滤条件
- 排序规则
- 分页逻辑

从而让 AI 更贴合真实 CRM 业务场景。

---

# 为什么这个 Skill 有用

| 系统视角 | 用户意图 | 输出 |
|---|---|---|
| 👂 监听自然语言 | 提供模块 / 条件 / 字段 | ⚙️ 转换为 CLI / API 请求 |
| 📦 简化重复任务 | 分页 / 搜索 / CRUD | ✅ 自动执行 |
| 📊 数据同步 | 查看销售管道 / 客户数据 | 🕓 可结合 cron 自动化 |

---
# 项目结构

```
CordysCRM-skills/
├── README.md             # 当前说明
└── skills/               # 可直接打包的 skill 内容
    ├── SKILL.md          # Skill 的元数据与使用说明
    ├── references/       # 额外的 API/领域文档
    │   └── crm-api.md    # Cordys CRM 的字段/请求体规范
    └── scripts/          # 可执行的 CLI 脚本（Shell + Python）
        ├── cordys
        └── cordys.py
```

## 如何在 OpenClaw 中安装

```bash
curl -fsSL https://raw.githubusercontent.com/1Panel-dev/CordysCRM-skills/install.sh | bash
```

然后确认 `scripts/cordys` 可执行：

```bash
./scripts/cordys help
```

## 说明

- `SKILL.md` 中的内容由 OpenClaw 读取，用于指导 AI 生成命令与流程。
- `references/crm-api.md` 提供 Cordys API 的字段、示例与约定，只有在 skill 触发时才会被加载。
- `scripts/` 下提供了 Shell 与 Python 两种 CLI 实现，OpenClaw 会依照环境优先选择 Shell 版本，遇到兼容问题会 fallback 到 Python 版本。

如需本地测试或打包，请以 `skills/` 为根，使用 `scripts/package_skill.py skills/` 生成 `.skill` 文件。
