---
name: jzt-docs-requirements
description: >-
  JZT requirements & docs workflow: search/read Confluence PRD and design
  docs via the confluence CLI, refine requirements from code, write results
  back to Confluence with -f files, enrich context with SEPP defects.
  Invoke on 需求梳理、PRD、查文档、写文档、建页面、根据代码整理需求.
---

# JZT 需求梳理与文档工作流

组合 `confluence` **CLI**（需求/文档读写） + `sepp`（缺陷上下文） + 代码阅读，完成"查需求 → 对照代码 → 梳理产出 → 写回文档"。

> Confluence 已瘦身为 CLI：读页/搜页/建页/覆盖页一律用 `confluence` 命令，**正文只走 `-f` 文件**；MCP 仅保留 `upload_drawio`，**没有** `create_page` / `update_page`。带 Confluence 链接时禁止 WebFetch（无登录会拿到登录页）。

## 工具细节（按需读取，不要一次全读）

各 CLI / MCP 的完整参数说明与避坑清单在 `references/` 目录，**执行到对应场景前再 Read 对应文件**：

| 文件 | 内容 | 读取时机 |
|---|---|---|
| `references/confluence.md` | CLI 命令（fetch / page create / page update / search）、正文走文件、退出码 | 场景 A / C 前 |
| `references/reference/cli.md` | confluence CLI 子命令细节与错误码 | CLI 报错/参数拿不准时 |
| `references/sepp-defects.md` | query_defects 多人解析、状态过滤 | 场景 B 第 4 步前 |
| `references/jztsql.md` | describe_table 参数、默认库 saas_clinic | 场景 B 第 3 步前 |

若链接失效，回源路径：`/Users/zhengzihang/Documents/my-mcp/` 下各子项目。

## 典型场景与流程

### 场景 A：查需求 / PRD / 设计文档

```bash
confluence --version                                    # 找不到命令时用仓库 venv（见 references/confluence.md）
confluence search '用户登录' --space PRD --limit 10      # 关键词搜索，不必写 CQL
confluence fetch <url_or_pageId> -o /tmp/page.md        # 正文落盘后 Read，别打 stdout
```

- 页面 URL 与 pageId 等价，直接当位置参数传（`viewpage.action?pageId=308041444` 也行）
- 不确定空间 key 时先 `confluence search '关键词'` 不加 `--space` 再收窄
- 大页不要 `--print-body`；页面树导航 MCP 的 `get_child_pages` 已下线，用 `confluence search --space KEY` 按标题检索子页

### 场景 B：根据代码梳理需求

```
1. 梳理代码：入口(Controller/路由) → 用例 → 服务层 → 数据模型，列出功能点、
   分支条件、依赖（MQ/定时任务/外部接口）
2. confluence search 找对应 PRD/设计文档做对照（拿到后 `fetch -o` 落盘再读）
   - 代码有、文档没有 → 标记"未文档化的隐含逻辑"
   - 文档有、代码没有 → 标记"可能未实现/已下线"，提示用户确认
3. jztsql.describe_table 补充数据模型（字段含义从 DDL 注释/命名推断）
4. sepp.query_defects(summary="相关关键词") 关联历史缺陷，佐证行为
5. 输出：功能清单 + 流程说明 + 与文档差异表；经用户确认后写回 Confluence
```

### 场景 C：写回 Confluence

先把正文写到文件（如 `/tmp/xxx-需求梳理.md`），再用 CLI 提交：

```bash
confluence page create --space TECH --title 'xxx 需求梳理' -f /tmp/xxx.md [--parent PARENT_ID_OR_URL]
confluence page update <url_or_pageId> -f /tmp/xxx.md --force --comment '同步本地文档'
```

- **覆盖是整页替换**：先 `confluence fetch -o` 取最新版本，在其基础上改，避免覆盖他人编辑
- agent / 非 TTY 的 `page update` **必须**加 `--force`；缺参数退出码 2
- 写操作前**必须**向用户复述：目标空间/父页面、标题、动作（新建/更新/删除）
- `delete_page` 除用户明确要求外不要调用；CLI 也不提供内联正文（禁用 `-c` / 把 Markdown 贴进命令）
- 支持 Markdown 直接写入；drawio 用 MCP `upload_drawio`，复杂图建议先小范围验证

## 工具速查

| 命令 / 工具 | 用途 |
|---|---|
| `confluence search [关键词] --space KEY --limit N` | 检索（不必写 CQL） |
| `confluence fetch <url_or_id> [-o file]` | 读页，`-o` 落 Markdown |
| `confluence page create --space KEY --title T -f file` | 新建页 |
| `confluence page update <url_or_id> -f file --force` | 整页覆盖 |
| MCP `upload_drawio` | 唯一保留的 MCP 写工具（上传图形） |
| `sepp.query_defects` / `query_my_defects` | 缺陷上下文 |
| `jztsql.describe_table` / `execute_sql` | 数据模型与数据佐证 |

## 梳理产出模板（写回前给用户过目）

```markdown
# <系统/模块> 需求梳理
## 1. 功能清单（表格：功能点 / 入口 / 触发条件 / 状态）
## 2. 核心流程（按角色或接口分节，含分支逻辑）
## 3. 数据模型（表 + 关键字段 + 关系）
## 4. 与现有文档差异（新增/废弃/不一致，标注证据：页面 ID、代码位置）
## 5. 待确认项
```

## 常见坑

1. 搜索命中过多：加 `--space` 收窄或用更精确的短语，别一次拉全文
2. 页面 ID 从搜索结果 JSON 的 `id` 字段取，不要凭 URL 猜；URL 与 pageId 可直接当位置参数
3. 更新页面会整体替换内容：先 `fetch -o` 取最新版本，在其基础上改，避免覆盖他人编辑
4. SEPP 缺陷描述可能口语化，用 `summary` 模糊过滤即可，别指望结构化字段齐全
5. 从代码推断的需求要标注"代码推断"，与 PRD 原文区分开
6. 找不到 `confluence` 命令 / 版本低于 `references/confluence.md` 的 frontmatter `version`：
   在 `/Users/zhengzihang/Documents/my-mcp/confluence-skill` 执行 `pip install -e .` 后再用
7. 别再调用 MCP 的 `create_page` / `update_page`（已下线），也别用 WebFetch 读 Confluence 链接

## 经验沉淀（任务结束前执行）

给出结论后、结束任务前，对照以下条件自检，**满足任一则在本 skill 目录的 `lessons.md` 末尾追加一条**：

1. CLI/MCP 调用报错/被拒，且本文档与 `references/` 均未提到该坑
2. 按本文档步骤走不通、调整做法后成功 → 记录调整点
3. 产出了比本文档模板更优的结论结构或梳理手法
4. CLI 实际行为与 `references/` 文档不符（参数、返回结构、默认值）

一切顺利则**不要记录**（避免噪音）。

条目格式（**只追加，不改本文档正文**；正文由人工定期从 lessons 蒸馏更新）：

```markdown
## 2026-09-15 | 场景一句话
- 经验：遇到什么坑 / 更好的做法
- 证据：命令与报错信息 / 页面 ID / 代码位置
```
