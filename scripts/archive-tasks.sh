#!/bin/bash

# TASK 文档归档脚本
# 用途：定期归档超过指定天数的 TASK 文档，保持项目根目录整洁
# 用法：archive-tasks.sh [-t DAYS]
#   -t DAYS  指定归档阈值天数（默认 30 天）
#   -h       显示帮助

set -e

AGENT_DIR=".agents"
HISTORY_DIR="$AGENT_DIR/history"
DAYS_OLD=30

# 解析命令行参数
while getopts ":t:h" opt; do
    case $opt in
        t)
            if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                echo "错误: -t 参数须为正整数，收到: $OPTARG"
                exit 1
            fi
            DAYS_OLD="$OPTARG"
            ;;
        h)
            echo "用法: $0 [-t DAYS]"
            echo "  -t DAYS  指定归档阈值天数（默认 30 天）"
            echo "  -h       显示帮助"
            exit 0
            ;;
        :)
            echo "错误: -$OPTARG 需要一个参数"
            exit 1
            ;;
        \?)
            echo "错误: 未知选项 -$OPTARG"
            exit 1
            ;;
    esac
done

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "TASK 文档归档工具"
echo "========================================"
echo ""

# 检查 .agents 目录是否存在
if [ ! -d "$AGENT_DIR" ]; then
    echo "错误: $AGENT_DIR 目录不存在"
    exit 1
fi

# 统计需要归档的文件
count=$(find "$AGENT_DIR" -maxdepth 1 -name "TASK-*.md" -mtime +${DAYS_OLD} 2>/dev/null | wc -l)

if [ "$count" -eq 0 ]; then
    echo -e "${GREEN}✓ 无需归档的 TASK 文档${NC}"
    echo "  所有 TASK 文档都在 ${DAYS_OLD} 天以内"
    exit 0
fi

echo "发现 $count 个超过 ${DAYS_OLD} 天的 TASK 文档"
echo ""

# 列出将被归档的文件
echo "将归档以下文件："
while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    file_date=$(date -r "$file" +%Y-%m-%d)
    echo "  - $filename (最后修改: $file_date)"
done < <(find "$AGENT_DIR" -maxdepth 1 -name "TASK-*.md" -mtime +${DAYS_OLD} -print0)
echo ""

# 询问确认
read -p "是否继续归档？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

echo ""
echo "开始归档..."
echo ""

# 归档计数器
archived=0

# 执行归档
while IFS= read -r -d '' file; do
    # 提取年月
    year_month=$(date -r "$file" +%Y-%m)
    
    # 创建归档目录
    mkdir -p "$HISTORY_DIR/$year_month"
    
    # 移动文件
    filename=$(basename "$file")
    file_stamp=$(date -r "$file" +%Y%m%d-%H%M%S)

    dest="$HISTORY_DIR/$year_month/$filename"
    if [ -e "$dest" ]; then
        base="${filename%.md}"
        i=1
        while [ -e "$dest" ]; do
            dest="$HISTORY_DIR/$year_month/${base}__dup${i}__${file_stamp}.md"
            i=$((i + 1))
        done
    fi

    echo "  ✓ $filename → $HISTORY_DIR/$year_month/$(basename "$dest")"
    mv "$file" "$dest"
    
    archived=$((archived + 1))
done < <(find "$AGENT_DIR" -maxdepth 1 -name "TASK-*.md" -mtime +${DAYS_OLD} -print0)

echo ""
echo "========================================"
echo -e "${GREEN}归档完成！${NC}"
echo "========================================"
echo ""
echo "共归档 $archived 个 TASK 文档"
echo ""
echo "提示："
echo "  • 归档位置: $HISTORY_DIR/"
echo "  • 如需查看归档文件: ls -R $HISTORY_DIR/"
echo "  • CHANGELOG.md 中的引用路径可能需要更新"
echo ""
