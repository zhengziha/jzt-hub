#!/bin/bash
# jzt-hub skills 项目级安装脚本
# 把 jzt-hub 的 skills 以软链方式安装到目标项目的各 AI IDE skills 目录。
# 软链指向本仓库，jzt-hub 更新后所有项目自动生效。
#
# 用法:
#   ./link.sh /path/to/target-project <ide...|all> [--agents]
#
#   ide       IDE 简称: trae | cursor | claude | qoder，可传多个
#   all       安装到全部 IDE 目录
#   --agents  同时在项目 AGENTS.md 追加 skills 索引（供 Codex 等
#             不支持 skills 目录、但会读 AGENTS.md 的 agent 使用）
set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HUB_DIR/skills"
USAGE_IDES="trae | cursor | claude | qoder | all"
TARGET="${1:?用法: $0 /path/to/target-project <ide...|all> [--agents]，IDE 可选: $USAGE_IDES}"
TARGET="$(cd "$TARGET" && pwd)"
shift

# IDE 简称 -> 项目级 skills 目录（按需增删，需同步修改 ALL_IDES 与 case）
ALL_IDES=(trae cursor claude qoder)
ide_to_dir() {
  case "$1" in
    trae)   echo ".trae/skills" ;;   # Trae
    cursor) echo ".cursor/skills" ;; # Cursor
    claude) echo ".claude/skills" ;; # Claude Code
    qoder)  echo ".qoder/skills" ;;  # Qoder
    *)      return 1 ;;
  esac
}

AGENTS=0
SELECTED=()
for arg in "$@"; do
  case "$arg" in
    --agents) AGENTS=1 ;;
    all)      SELECTED=("${ALL_IDES[@]}") ;;
    *)
      ide_to_dir "$arg" >/dev/null || { echo "未知 IDE: ${arg}（可选: ${USAGE_IDES}）" >&2; exit 1; }
      SELECTED+=("$arg")
      ;;
  esac
done

[ "${#SELECTED[@]}" -gt 0 ] || { echo "错误: 未指定 IDE（可选: ${USAGE_IDES}）" >&2; exit 1; }

echo "目标项目: $TARGET"
for skill in "$SKILLS_DIR"/*/; do
  name="$(basename "$skill")"
  for ide in "${SELECTED[@]}"; do
    dir="$(ide_to_dir "$ide")"
    dest_dir="$TARGET/$dir"
    dest="$dest_dir/$name"
    mkdir -p "$dest_dir"
    if [ -L "$dest" ]; then
      rm "$dest"
      ln -s "$SKILLS_DIR/$name" "$dest"
      echo "  更新软链: $dir/$name"
    elif [ -e "$dest" ]; then
      echo "  跳过(已存在同名非软链文件): $dir/$name"
    else
      ln -s "$SKILLS_DIR/$name" "$dest"
      echo "  新建软链: $dir/$name"
    fi
  done
done

if [ "$AGENTS" = "1" ]; then
  agents_file="$TARGET/AGENTS.md"
  marker="<!-- jzt-hub-skills -->"
  if [ -f "$agents_file" ] && grep -q "$marker" "$agents_file"; then
    echo "  AGENTS.md 已包含索引，跳过"
  else
    {
      echo ""
      echo "$marker"
      echo "## JZT MCP Skills"
      echo ""
      echo "处理以下任务时，先阅读对应 SKILL.md（软链于 .trae/skills/，任选其一）："
      echo "注：日志走 \`elk\` CLI、文档读写走 \`confluence\` CLI，其余为 MCP 工具。"
      echo ""
      echo "- [.trae/skills/jzt-mcp-overview/SKILL.md](.trae/skills/jzt-mcp-overview/SKILL.md) — 5 个 JZT 服务(ELK/SkyWalking/jztsql/Confluence/SEPP)的能力地图与问题路由"
      echo "- [.trae/skills/jzt-troubleshoot/SKILL.md](.trae/skills/jzt-troubleshoot/SKILL.md) — 线上故障排查工作流(链路+elk CLI 日志+数据+缺陷)"
      echo "- [.trae/skills/jzt-sql-optimize/SKILL.md](.trae/skills/jzt-sql-optimize/SKILL.md) — 慢 SQL 定位与优化工作流"
      echo "- [.trae/skills/jzt-docs-requirements/SKILL.md](.trae/skills/jzt-docs-requirements/SKILL.md) — 需求梳理与 Confluence 文档工作流(confluence CLI 读写)"
      echo ""
    } >>"$agents_file"
    echo "  已追加索引: AGENTS.md"
  fi
fi

echo "完成。注意: 软链为绝对路径，若目标项目仓库被他人 clone，需在其本机重跑本脚本。"
