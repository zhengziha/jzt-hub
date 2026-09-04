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

| MCP 服务名 | 项目目录 | 解决什么 | 核心工具 |
|---|---|---|---|
| `elk-logs` | elk-mcp-server | 按项目/环境/时间窗查 Kibana 日志，按 TraceId 拉整条链路日志 | `list_projects` `search_logs` `search_by_trace_id` `expand_log_hit` |
| `skywalking` | mcp-server-skywalking | 接口性能指标（p99/吞吐/成功率）、慢链路检索、链路耗时热点分析 | `analyze_endpoint` `list_services` `search_endpoints` `get_endpoint_performance` `search_slow_traces` `analyze_trace` |
| `jztsql` | jztsql-mcp-server | 经 SQL 平台只读查库：表 DDL、SELECT/EXPLAIN/SHOW | `list_instances` `list_databases` `describe_table` `execute_sql` |
| `confluence-mcp-server` | confluence-skill | Confluence 知识库读写：CQL 搜索、读页面(Markdown)、建/改/删页面 | `search_pages` `get_page` `create_page` `update_page` `list_spaces` `get_child_pages` |
| `sepp` | jzt-sepp-mcp-server | 能效平台缺陷管理：按负责人查缺陷、缺陷监控与钉钉/企微/飞书提醒 | `query_defects` `query_my_defects` `get_users` `monitor_add` `monitor_list` |

> XXL-Job MCP（任务调度后台）规划中，尚未提供 MCP 工具。

## 问题路由表

| 用户的问题 | 用哪个 MCP |
|---|---|
| 服务报错/日志/堆栈/TraceId | `elk-logs` |
| 接口慢/超时/成功率/p99/耗时在哪一步 | `skywalking` |
| 查数据、看表结构、EXPLAIN、慢 SQL | `jztsql`（只读） |
| 找 PRD/需求/设计文档，写文档 | `confluence-mcp-server` |
| 查我/某人的缺陷、缺陷监控提醒 | `sepp` |
| 线上故障定位（日志+链路+数据+缺陷联动） | `jzt-troubleshoot` 工作流 |
| SQL 优化（链路热点 + EXPLAIN 联动） | `jzt-sql-optimize` 工作流 |
| 根据代码梳理需求、写回文档 | `jzt-docs-requirements` 工作流 |

## 文档分层（渐进式披露）

- **场景层**（本 hub 的 4 个 skill）：解决"什么场景按什么顺序组合哪些 MCP"，正文只保留编排步骤
- **工具层**（各子项目内的 skill/README）：完整参数、返回结构、避坑清单；由场景 skill 的 `references/` 目录**软链引用**，执行到对应步骤时按需 Read，不必预先加载
- 唯一事实来源在各子项目：工具用法变更改子项目文件即可，hub 自动同步

## 关键约束（务必遵守）

- **jztsql 只读**：仅 SELECT / EXPLAIN / SHOW；写操作会被拒绝。默认实例 `生产-诊所-读库-ALI`，默认库 `saas_clinic`，结果上限 20000 行。
- **elk-logs 先摘要后展开**：默认 `mode=summary`，仅对关键命中用 `expand_log_hit` 展开完整堆栈；不确定项目+环境时先 `list_projects` 确认，别盲目跨候选聚合。
- **skywalking 时区**：`SKYWALKING_TZ` 必须与 OAP 服务端一致（默认 Asia/Shanghai），否则指标时间桶全为 0。
- **trace_id 是桥梁**：SkyWalking 的 `trace_id` 与 ELK 日志中的 TID 同源，可互相切换查询。
- **confluence 删除/更新先确认**：`delete_page`、`update_page` 会改动线上文档，执行前向用户确认页面标题与 ID。
- **sepp 默认查"我"**：不指定负责人时使用默认用户；多人查询传名称列表，解析失败的看返回中的 `missing` 字段。

## 各 MCP 接入要点

| MCP | 启动命令 | 配置 |
|---|---|---|
| `elk-logs` | `python -m elk_mcp.server` | `config.yaml`（kibana 地址/账号、项目与 data_view_id 映射） |
| `skywalking` | `python -m skywalking_mcp` | 环境变量 `SKYWALKING_URL` / `SKYWALKING_TZ` |
| `jztsql` | 包入口 `main()` | `JZTSQL_BASE_URL` / `JZTSQL_USERNAME` / `JZTSQL_PASSWORD` |
| `confluence-mcp-server` | `python -m src.main` | `CONFLUENCE_BASE_URL` / `CONFLUENCE_USERNAME` / `CONFLUENCE_API_TOKEN` |
| `sepp` | `uv run python -m sepp_mcp serve` | `SEPP_USERNAME`/`SEPP_PASSWORD` 或 `SEPP_AUTH_TOKEN` |

统一 mcpServers 配置示例（路径按本机调整）：

```json
{
  "mcpServers": {
    "elk-logs": {
      "command": "/Users/zhengzihang/Documents/my-mcp/elk-mcp-server/.venv/bin/python",
      "args": ["-m", "elk_mcp.server"],
      "cwd": "/Users/zhengzihang/Documents/my-mcp/elk-mcp-server"
    },
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

1. 先按路由表选定 MCP，再调用；一次任务通常 1～3 个 MCP 足够。
2. 调用前确认必需上下文（项目/环境/时间窗/库名/空间），缺了先问用户或用 `list_*` 工具查。
3. 涉及写操作（confluence 建改删页、sepp 建监控）先向用户复述将执行的动作。
4. 结论中注明数据来源（哪个 MCP、什么时间窗/范围）。
