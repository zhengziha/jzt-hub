# 慢 SQL 深度分析方法论（数据驱动）

适用：首轮 EXPLAIN 结论不够、需要设计联合索引、或分页 COUNT/LIST 慢的场景。
来源：zs-saas 项目实战沉淀（slow-sql-analysis），工具调用名已对齐当前 MCP。

## 1. 多 trace 采样原则

- 用 `search_slow_traces`（支持 service_name / endpoint_name / min_trace_duration_ms / limit 过滤，按耗时降序）取 **≥10 个**慢 trace，再逐个 `analyze_trace`，找共性问题，不要只看 1-2 个就下结论
- 按 SQL 类型分类统计（主表 COUNT / 主表 LIST / JOIN 查询等），记录各自耗时与占比
- 关注 P95/P99 而不只是平均耗时，避免遗漏偶发慢查询
- ⚠️ EXPLAIN 用的 SQL 必须与 trace tag（`db.statement`）中的一致，不要自行增删条件，否则结论与链路对不上；注意 tag 中的 SQL 可能被截断

## 2. 数据分布统计（设计索引前必做）

用 `execute_sql` 对 WHERE 涉及字段做 GROUP BY，**用数据支撑索引设计，不凭经验猜**：

```sql
-- 单字段分布
SELECT status, COUNT(*) FROM <表名> GROUP BY status ORDER BY COUNT(*) DESC;

-- 组合条件分布
SELECT type, status, COUNT(*) FROM <表名> GROUP BY type, status ORDER BY COUNT(*) DESC;
```

计算选择性（不同值数 / 总记录数），形成表格：

| 字段 | 不同值数 | 总记录数 | 选择性 | 过滤效果 |
|------|---------|---------|--------|---------|
| is_delete | 2 | 300万 | 低 | 差（不建议单独放前） |
| type | 6 | 300万 | 高 | 好 |

## 3. 联合索引设计规则

```sql
ALTER TABLE <表名> ADD INDEX idx_xxx (
    <高选择性等值字段>, <等值字段>, ..., <排序字段>
);
```

- 等值条件在前，范围条件在后，ORDER BY 字段放最后（前提：前面全是等值）
- 高选择性字段放前面（依据第 2 步的分布统计，不是直觉）

## 4. MyBatis Plus 分页 COUNT 陷阱（Java 项目高频）

`Page` + `selectPage` 会自动生成 `SELECT COUNT(1) FROM (原SQL)` 包裹查询：

- **原 SQL 的 JOIN 会被带入 COUNT**，COUNT 不需要关联表时白白多算 → 自定义 COUNT 去掉 JOIN：

```sql
-- 优化前（分页插件自动生成，带 JOIN）
SELECT COUNT(1) FROM main_table a LEFT JOIN t2 ON ... LEFT JOIN t3 ON ... WHERE ...;
-- 优化后（自定义 COUNT）
SELECT COUNT(1) FROM main_table a WHERE ...;
```

- 动态 SQL（`<if>`）可能导致某些分支缺少关键过滤条件 → 全表扫描，检查 Service 层条件构建逻辑
- 大表 COUNT 可用子查询先收敛：`SELECT COUNT(1) FROM (SELECT id FROM t WHERE ...) x;`

## 5. 代码层面检查清单

- 定位 Mapper XML / Service 条件构建代码，确认动态 SQL 分支
- 分页插件自动 COUNT 与手写 LIST 是否一致
- 是否 `SELECT *`、函数包索引列、隐式类型转换

## 6. 常见陷阱

| 陷阱 | 现象 | 解决方案 |
|------|------|----------|
| JOIN 带入 COUNT | COUNT 比必要得多算 | 自定义 COUNT 去 JOIN |
| 低选择性字段放索引前 | 过滤效果差 | 分布统计后高选择性在前 |
| 动态条件缺关键条件 | 偶发全表扫描 | 保证关键条件始终存在 |
| 只看平均耗时 | 漏掉偶发慢查询 | 看 P95/P99 |
| 只优化 COUNT 忽略 LIST | 分页仍慢 | 两类 SQL 都分析 |
| EXPLAIN 的 SQL 与 trace 不一致 | 结论对不上 | 严格用 trace 中的 SQL |

## 7. 分析报告输出模板

```markdown
# 慢 SQL 分析报告

## 一、接口概览
| 接口 | PV | avg_rt | p95_rt | p99_rt |

## 二、链路分析（≥10 个 trace）
| trace_id | 耗时 | SQL 类型 | COUNT 耗时 | LIST 耗时 |

## 三、数据分布统计
（第 2 步的选择性表格）

## 四、EXPLAIN 优化前后对比

## 五、优化建议
| 优先级 | 优化点 | 预期效果 |

## 六、后续跟进
索引变更（平台流程）/ 代码改造 / 性能验证 / 监控告警
```
