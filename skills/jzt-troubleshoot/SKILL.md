---
name: jzt-troubleshoot
description: >-
  End-to-end JZT troubleshooting workflow combining SkyWalking traces, ELK
  logs, jztsql data checks and SEPP defect lookup. Invoke on 线上故障、接口
  报错、超时、服务异常、排障、定位根因 (troubleshooting, root cause).
---

# JZT 故障排查工作流

组合 `skywalking` + `elk-logs` + `jztsql` + `sepp` 定位线上问题根因。四个 MCP 相互独立，按下面的顺序与桥接点组合使用。

## 总体流程

```
1. 明确范围   服务/项目 + 环境(dev/test/pre) + 时间窗 + 现象（接口 URL / 报错信息 / TraceId）
2. 链路入手   skywalking.analyze_endpoint  → 性能汇总、错误率、最慢链路、耗时热点
3. 日志佐证   elk-logs（summary → TID 关联 → expand）拿具体报错与堆栈
4. 数据核实   jztsql 查表数据/表结构，验证业务数据假设
5. 缺陷查重   sepp.query_defects 看是否已知缺陷/他人已报
6. 输出结论   时间、服务、根因、证据（链路+日志+数据）、建议
```

## 工具细节（按需读取，不要一次全读）

各 MCP 的完整参数说明、返回结构与避坑清单在 `references/` 目录，**执行到对应步骤前再 Read 对应文件**：

| 文件 | 内容 | 读取时机 |
|---|---|---|
| `references/skywalking-trace.md` | 6 个工具参数、时间参数约定、Entry 端点/时区坑 | 第 2 步前 |
| `references/elk-logs.md` | query_string 引号规则、summary→expand 模式 | 第 3 步前 |
| `references/jztsql.md` | 只读约束、实例/库默认值、登录机制 | 第 4 步前 |
| `references/sepp-defects.md` | query_defects 多人解析、监控语义 | 第 5 步前 |

若 `references/` 链接失效（目录被移动），回源路径：`/Users/zhengzihang/Documents/my-mcp/` 下各子项目。

## 第 1 步：明确范围（缺了就先问）

- **服务名**：从用户当前工程名推断（如 `zs-saas-crm-admin`），ELK 项目名形如 `saas-{env}-{service}`
- **环境**：dev / test / pre，用户没说就问一次
- **时间窗**：未知先用 `now-6h` / `now-1d`，再收窄；SkyWalking 也可用 `start_time`/`end_time` 回溯历史故障
- **入口信息**：接口 URL、TraceId、报错文案，有哪个用哪个

## 第 2 步：SkyWalking 链路分析

```text
analyze_endpoint(url="/xxx/yyy", service_name="可选,已知服务时传", minutes=30)
# 返回: resolved_endpoint / performance(含成功率、p99、趋势) / slowest_traces / trace_analysis / findings
```

- 只知道服务不知道接口：先 `list_services` → `search_endpoints`
- 拿到 `slowest_traces` 中某条 `trace_id` 后：`analyze_trace(trace_id=...)`
  - 看 `top_self_time_spans`（自耗时 Top）：定位慢在哪个服务/组件
  - 看 `by_layer_component`：Mysql / Cache / HTTP / MQ 哪层耗时
  - 看 `errors`：错误 span 直接给根因线索
- 注意：端点指标只在 Entry 端点所在服务上产生，`analyze_endpoint` 已内置解析，优先用它而不是手工查指标。

## 第 3 步：ELK 日志佐证

**桥接点：SkyWalking 的 `trace_id` ≈ ELK 日志里的 TID**

```text
# 有 TraceId：直接拉同链路各 span 的日志
search_by_trace_id(trace_id="<trace_id>", project="zs-saas-crm-admin", env="test", from_time="now-6h")

# 无 TraceId：关键词摘要检索
search_logs(project="zs-saas-crm-admin", env="test", service="zs-saas-crm-admin",
            query='"/xxx/yyy" AND ERROR', from_time="now-6h", size=20)
```

- 强制 `mode=summary` 起步；驼峰、接口路径要加引号（ES query_string）
- 只对关键 ERROR 命中做 `expand_log_hit(index=hit._index, doc_id=hit._id)` 展开完整堆栈
- `total=0` 时读返回的 `hints` / `meta`（实际 query、索引、时间窗）再改查询

## 第 4 步：jztsql 数据核实

当日志/链路指向数据问题（数据不存在、状态不对、配置缺失）：

```text
describe_table(tb_name="xxx")          # 先看 DDL：字段、索引
execute_sql(sql_content="SELECT ... LIMIT 100")   # 只读核实；默认库 saas_clinic
```

- 只读：SELECT / EXPLAIN / SHOW；需要写库时明确告诉用户该工具不支持
- 默认实例 `生产-诊所-读库-ALI`（生产读库），跨实例先 `list_instances` / `list_databases`

## 第 5 步：SEPP 缺陷查重

```text
get_users(keyword="姓名")               # 需要时查 userId
query_defects(responsers=["张三","李四"], status="处理中")   # 多人合并查询
query_my_defects()                      # 查"我"的
```

判断是否已知问题：有在途缺陷 → 关联缺陷单号给用户；无 → 建议用户提单。

## 输出结论格式

1. **结论**：一句话根因
2. **证据**：
   - 链路：哪条 trace、慢/错在哪个 span（服务+组件+耗时占比）
   - 日志：时间、error_type、关键 message 摘录
   - 数据：查了哪张表、关键数据是什么
3. **关联缺陷**：SEPP 缺陷单号（如有）
4. **建议下一步**：修复方向 / 需要用户确认的信息

## 常见坑

1. 时间窗不一致导致"链路有、日志没有"：两个 MCP 用同一时间窗再查一次
2. SkyWalking 指标全 0：时区问题（`SKYWALKING_TZ` 与 OAP 不一致）
3. ELK 搜不到驼峰/路径：没加引号被分词
4. jztsql 查生产读库有延迟，刚写入的数据可能查不到
5. 别跳过第 1 步直接查：没有项目+环境会在 ELK 跨全部候选项目聚合，噪音大
