---
name: jzt-docs-requirements
description: >-
  JZT requirements & docs workflow: search/read Confluence PRD and design
  docs, refine requirements from code, write results back to Confluence,
  enrich context with SEPP defects. Invoke on 需求梳理、PRD、查文档、写文档、
  建页面、根据代码整理需求.
---

# JZT 需求梳理与文档工作流

组合 `confluence-mcp-server`（需求/文档读写） + `sepp`（缺陷上下文） + 代码阅读，完成"查需求 → 对照代码 → 梳理产出 → 写回文档"。

## 工具细节（按需读取，不要一次全读）

各 MCP 的完整参数说明与避坑清单在 `references/` 目录，**执行到对应场景前再 Read 对应文件**：

| 文件 | 内容 | 读取时机 |
|---|---|---|
| `references/confluence.md` | CQL 语法、读写工具参数、格式转换 | 场景 A / C 前 |
| `references/sepp-defects.md` | query_defects 多人解析、状态过滤 | 场景 B 第 4 步前 |
| `references/jztsql.md` | describe_table 参数、默认库 saas_clinic | 场景 B 第 3 步前 |

若链接失效，回源路径：`/Users/zhengzihang/Documents/my-mcp/` 下各子项目。

## 典型场景与流程

### 场景 A：查需求 / PRD / 设计文档

```
1. list_spaces() 确认目标空间（不确定空间 key 时）
2. search_pages(cql='text ~ "用户登录" AND space = "PRD"', limit=10)
3. get_page(page_id="...")            # 内容自动含 Markdown 版本 body.markdown
4. 需要结构时 get_child_pages(parent_id="...") 拉子页树
```

CQL 示例：

```
title ~ "API" AND type = "page"
space = "PRD" AND label = "2024"
```

### 场景 B：根据代码梳理需求

```
1. 梳理代码：入口(Controller/路由) → 用例 → 服务层 → 数据模型，列出功能点、
   分支条件、依赖（MQ/定时任务/外部接口）
2. confluence.search_pages 找对应 PRD/设计文档做对照
   - 代码有、文档没有 → 标记"未文档化的隐含逻辑"
   - 文档有、代码没有 → 标记"可能未实现/已下线"，提示用户确认
3. jztsql.describe_table 补充数据模型（字段含义从 DDL 注释/命名推断）
4. sepp.query_defects(summary="相关关键词") 关联历史缺陷，佐证行为
5. 输出：功能清单 + 流程说明 + 与文档差异表；经用户确认后写回 Confluence
```

### 场景 C：写回 Confluence

```
create_page(title="xxx 需求梳理", space_key="TECH",
            content="# Markdown 内容", content_format="markdown",
            parent_id="可选父页面")
update_page(page_id="...", content="...", content_format="markdown")
```

- 写操作前**必须**向用户复述：目标空间/父页面、标题、动作（新建/更新/删除）
- `delete_page` 除用户明确要求外不要调用
- 支持 Markdown 直接写入；drawio/mermaid 由服务端转换，复杂图建议先小范围验证

## 工具速查

| 工具 | 用途 |
|---|---|
| `search_pages(cql, limit)` | CQL 全文/标题/空间检索 |
| `get_page(page_id)` | 读页面（含 Markdown） |
| `get_page_by_title(title, space_key)` | 按精确标题定位 |
| `list_spaces` / `get_space_content` / `get_child_pages` | 空间与页面树导航 |
| `create_page` / `update_page` / `delete_page` | 写操作（先确认再执行） |
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

1. 搜索命中过多：CQL 加 `space =`、`title ~` 收窄，别一次拉全文
2. 页面 ID 从搜索结果的 `id` 字段取，不要凭 URL 猜
3. 更新页面会整体替换内容：先 `get_page` 取最新版本，在其基础上改，避免覆盖他人编辑
4. SEPP 缺陷描述可能口语化，用 `summary` 模糊过滤即可，别指望结构化字段齐全
5. 从代码推断的需求要标注"代码推断"，与 PRD 原文区分开
