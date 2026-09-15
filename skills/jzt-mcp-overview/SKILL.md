---
name: jzt-mcp-overview
description: >-
  Capability map of JZT MCP servers (ELK logs, SkyWalking tracing, jztsql
  read-only SQL, Confluence docs, SEPP defect management). Invoke when unsure
  which JZT MCP to use, or user asks 查日志/链路/慢SQL/性能/需求文档/缺陷
  and needs routing to the right tool.
---

# JZT MCP 能力总览与路由

本 skill 介绍 `~/Documents/my-mcp` 下 5 个相互独立的 MCP 各自能解决什么问题，以及如何选择与组合。详细组合工作流见姊妹 skills：`jzt-troubleshoot`（故障排查）、`jzt-sql-optimize`（SQL 优化）、`jzt-docs-requirements`（需求/文档）。

## 能力地图

| 服务 | 项目目录 | 形态 | 解决什么 | 核心入口 |
|---|---|---|---|---|
| `elk` | elk-mcp-server | **CLI**（MCP 已废弃） | 按项目/环境/时间窗查 Kibana 日志，按 TID 拉整条链路日志 | `elk list-projects` `elk search` `elk trace` `elk expand` |
| `skywalking` | mcp-server-skywalking | MCP | 接口性能指标（p99/吞吐/成功率）、慢链路检索、链路耗时热点与空档分析 | `analyze_endpoint` `list_services` `search_endpoints` `get_endpoint_performance` `search_slow_traces` `analyze_trace` |
| `jztsql` | jztsql-mcp-server | MCP | 经 SQL 平台只读查库：表 DDL、SELECT/EXPLAIN/SHOW | `list_instances` `list_databases` `describe_table` `execute_sql` |
| `confluence` | confluence-skill | **CLI**（主）+ MCP（仅 `upload_drawio`） | Confluence 知识库读写：搜索、读页面(Markdown)、建/覆盖页面 | `confluence search` `confluence fetch` `confluence page create/update -f` |
| `sepp` | jzt-sepp-mcp-server | MCP | 能效平台缺陷管理：按负责人查缺陷、缺陷监控与钉钉/企微/飞书提醒 | `query_defects` `query_my_defects` `get_users` `monitor_add` `monitor_list` |

> XXL-Job MCP（任务调度后台）规划中，尚未提供 MCP 工具。
> elk 的 MCP 工具已废弃：日志场景一律用 `elk` CLI（stdout 为 JSON，便于裁剪），不要接入 `elk-logs` MCP。

## 问题路由表

| 用户的问题 | 用哪个 |
|---|---|
| 服务报错/日志/堆栈/TraceId | `elk` CLI |
| 接口慢/超时/成功率/p99/耗时在哪一步 | `skywalking` |
| 查数据、看表结构、EXPLAIN、慢 SQL | `jztsql`（只读） |
| 找 PRD/需求/设计文档，写文档 | `confluence` CLI |
| 查我/某人的缺陷、缺陷监控提醒 | `sepp` |
| 线上故障定位（日志+链路+数据+缺陷联动） | `jzt-troubleshoot` 工作流 |
| SQL 优化（链路热点 + EXPLAIN 联动） | `jzt-sql-optimize` 工作流 |
| 根据代码梳理需求、写回文档 | `jzt-docs-requirements` 工作流 |

## 文档分层（渐进式披露）

- **场景层**（本 hub 的 4 个 skill）：解决"什么场景按什么顺序组合哪些 CLI/MCP"，正文只保留编排步骤
- **工具层**（各子项目内的 skill/README）：完整参数、返回结构、避坑清单；由场景 skill 的 `references/` 目录**软链引用**，执行到对应步骤时按需 Read，不必预先加载
- 唯一事实来源在各子项目：工具用法变更改子项目文件即可，hub 自动同步

## 关键约束（务必遵守）

- **jztsql 只读**：仅 SELECT / EXPLAIN / SHOW；写操作会被拒绝。默认实例 `生产-诊所-读库-ALI`，默认库 `saas_clinic`，`limit_num` 默认 100（上限 20000）。
- **elk 用 CLI 且 `--env` 必填**：dev/test/pre 走共享 ES，prod/stg 走独立生产 os-elk；默认 `summary` 模式，只对关键命中 `expand -o` 落盘，别把全文打 stdout；camelCase/路径要加双引号。
- **confluence 走 CLI、正文只走文件**：读页 `fetch [-o]`、写页 `page create/update -f 文件`（覆盖需 `--force`）；**不要**用 WebFetch 读 Confluence 链接，MCP 已无 `create_page`/`update_page`（仅剩 `upload_drawio`）。
- **skywalking 时区**：`SKYWALKING_TZ` 必须与 OAP 服务端一致（默认 Asia/Shanghai），否则指标时间桶全为 0；链路数据默认保留约 7 天。
- **trace_id 是桥梁**：SkyWalking 的 `trace_id` 与 ELK 日志中的 TID 同源，可互相切换查询。
- **写操作先确认**：confluence 建/覆盖/删页、sepp 建监控，执行前向用户复述动作与目标。
- **sepp 默认查"我"**：不指定负责人时使用默认用户；多人查询传名称列表，解析失败的看返回中的 `missing` 字段。

## 各服务接入要点

| 服务 | 推荐入口 | MCP 启动命令 | 配置 |
|---|---|---|---|
| `elk` | CLI：`elk-mcp-server/.venv/bin/elk` | 无（MCP 已废弃，勿接入） | `config.yaml`（kibana 地址/账号、项目与 data_view_id 映射） |
| `skywalking` | MCP：`.venv/bin/skywalking-mcp` | `python -m skywalking_mcp` | 环境变量 `SKYWALKING_URL` / `SKYWALKING_TZ` |
| `jztsql` | MCP：`.venv/bin/jztsql-mcp` | `python -m jztsql_mcp` | `JZTSQL_BASE_URL` / `JZTSQL_USERNAME` / `JZTSQL_PASSWORD` |
| `confluence` | CLI：`confluence-skill/.venv/bin/confluence` | `python -m src.main`（仅 `upload_drawio`） | 仓库 `.env`：`CONFLUENCE_BASE_URL` / `USERNAME` / `API_TOKEN` |
| `sepp` | MCP：`uv run python -m sepp_mcp serve` | 同上 | `SEPP_USERNAME`/`SEPP_PASSWORD` 或 `SEPP_AUTH_TOKEN` |

CLI 找不到命令时，在对应子项目执行 `pip install -e .`（sepp 用 `uv sync`）重装。

统一 mcpServers 配置示例（路径按本机调整；elk 已改 CLI，不在其中）：

```json
{
  "mcpServers": {
    "skywalking": {
      "command": "/Users/zhengzihang/Documents/my-mcp/mcp-server-skywalking/.venv/bin/python",
      "args": ["-m", "skywalking_mcp"]
    },
    "jztsql": {
      "command": "/Users/zhengzihang/Documents/my-mcp/jztsql-mcp-server/.venv/bin/python",
      "args": ["-m", "jztsql_mcp"]
    },
    "confluence": {
      "command": "/Users/zhengzihang/Documents/my-mcp/confluence-skill/.venv/bin/python",
      "args": ["-m", "src.main"],
      "cwd": "/Users/zhengzihang/Documents/my-mcp/confluence-skill"
    },
    "sepp": {
      "command": "uv",
      "args": ["--directory", "/Users/zhengzihang/Documents/my-mcp/jzt-sepp-mcp-server", "run", "python", "-m", "sepp_mcp"]
    }
  }
}
```

## 行为准则

1. 先按路由表选定服务，再调用；一次任务通常 1～3 个服务足够。
2. 调用前确认必需上下文（项目/环境/时间窗/库名/空间），缺了先问用户或用 `list_*` 工具查。
3. 涉及写操作（confluence 建改删页、sepp 建监控）先向用户复述将执行的动作。
4. 结论中注明数据来源（哪个服务、什么时间窗/范围）。

## 经验沉淀（任务结束前执行）

给出结论后、结束任务前，对照以下条件自检，**满足任一则在本 skill 目录的 `lessons.md` 末尾追加一条**：

1. CLI/MCP 调用报错/被拒，且本文档与 `references/` 均未提到该坑
2. 路由选错（本应选别的服务/命令）导致多绕了一圈 → 记录正确的路由判断依据
3. 子项目文档与实际行为不符（参数、返回结构、默认值）
4. 出现了本文档能力地图没覆盖的新工具/新能力

一切顺利则**不要记录**（避免噪音）。

条目格式（**只追加，不改本文档正文**；正文由人工定期从 lessons 蒸馏更新）：

```markdown
## 2026-09-15 | 场景一句话
- 经验：遇到什么坑 / 更好的做法
- 证据：命令与报错信息 / 工具返回 / 代码位置
```
