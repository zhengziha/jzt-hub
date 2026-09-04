---
name: jzt-sql-optimize
description: >-
  JZT SQL optimization workflow: locate slow SQL via SkyWalking trace
  analysis, EXPLAIN and inspect schema via jztsql read-only query, then give
  index/rewrite suggestions. Invoke on SQL优化、慢SQL、加索引、EXPLAIN、
  查询很慢、索引建议.
---

# JZT SQL 优化工作流

组合 `skywalking`（定位慢 SQL 发生在哪） + `jztsql`（看表结构、跑 EXPLAIN）给出优化建议。

## 总体流程

```
1. 拿到 SQL       三个来源：用户直接给 / 代码里读 / SkyWalking 链路热点里抓
2. 定位热点       skywalking：接口或链路里确认 DB 耗时占比、找出具体 SQL
3. 看表结构       jztsql.describe_table 拿 DDL（字段、索引）
4. 执行计划       jztsql.execute_sql 跑 EXPLAIN
5. 给出建议       索引 / SQL 改写 / 分页 LIMIT，并说明依据
```

## 工具细节（按需读取，不要一次全读）

各 MCP 的完整参数说明与避坑清单在 `references/` 目录，**执行到对应步骤前再 Read 对应文件**：

| 文件 | 内容 | 读取时机 |
|---|---|---|
| `references/skywalking-trace.md` | analyze_endpoint / analyze_trace 返回结构、时间参数 | 第 1~2 步用链路定位时 |
| `references/jztsql.md` | 只读约束、实例/库默认值、describe_table / execute_sql 参数 | 第 3 步前 |

若链接失效，回源路径：`/Users/zhengzihang/Documents/my-mcp/` 下各子项目。

## 第 1 步：拿到 SQL

- **用户直接给 SQL** → 跳到第 3 步
- **用户只说"XX 接口慢"** → 走 `jzt-troubleshoot` 的 SkyWalking 步骤：
  ```text
  analyze_endpoint(url="/xxx", minutes=30)      # 拿最慢链路
  analyze_trace(trace_id="...")                  # by_layer_component 看 Mysql 占比、
                                                 # top_self_time_spans 抓出具体 SQL 语句
  ```
- **用户说"某段代码查询慢"** → 从代码里找 SQL（MyBatis mapper / JPA / 手写），再进第 3 步

## 第 2 步：确认 DB 热点（有链路数据时）

`analyze_trace` 返回中重点看：

- `by_layer_component`：`Mysql` 类自耗时占比
- `top_self_time_spans`：哪个 span 的 SQL 自身耗时最长（含完整 SQL tags）
- 结论里引用："该 SQL 自耗时 Xms，占整条链路 Y%"

## 第 3 步：看表结构

```text
describe_table(tb_name="order_info")           # 默认库 saas_clinic，其他库传 db_name
```

记录：现有索引、字段类型、行数估计。WHERE / JOIN / ORDER BY 涉及的列是重点。

## 第 4 步：执行计划

```text
execute_sql(sql_content="EXPLAIN SELECT ...", db_name="saas_clinic")
```

重点看返回行的 `type`（ALL 全表扫最差）、`key`（实际用的索引）、`rows`（扫描行数）、`Extra`（Using filesort / Using temporary）。

## 第 5 步：优化建议模板

1. **索引建议**：`ALTER TABLE x ADD INDEX idx_yyy (col1, col2)` —— 依据：当前 `type=ALL`、`rows=N`，加索引后预期 `ref/range`；遵循最左前缀，等值列在前、范围列在后
2. **SQL 改写**：`SELECT *` → 明确列；深分页 → 游标/子查询定位；避免函数包索引列、隐式类型转换
3. **验证方式**：给出建议后用 `execute_sql` 再跑一次 `EXPLAIN` 对比（jztsql 只读，能验证 SELECT）
4. **落地提示**：加索引等 DDL 需用户在 SQL 平台走变更流程，本工具不执行写操作

## 硬性约束

- **jztsql 只读**：SELECT / EXPLAIN / SHOW 之外的语句会被拒绝，不要尝试；也**不要**把生成的 ALTER/CREATE 拿到该工具执行
- 生产读库（默认实例 `生产-诊所-读库-ALI`）上跑 EXPLAIN 是安全的，但避免无 LIMIT 的大结果集（上限 20000 行）
- 优化前后耗时对比要基于同一时间窗/同一数据量，结论里注明

## 输出结论格式

1. **问题**：哪条 SQL、在哪个接口/链路、耗时多少（有链路数据时）
2. **根因**：EXPLAIN 证据（type/key/rows/Extra）
3. **建议**：索引 DDL（平台执行）/ SQL 改写 / 验证结果
4. **风险**：大表加索引的锁表/耗时提示，建议低峰执行
