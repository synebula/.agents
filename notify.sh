#!/usr/bin/env bash

# 通知脚本 - 用于 AI Agents 任务完成通知

set -euo pipefail
# ============================================================================
# 常量定义
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# 工具函数
# ============================================================================

# 截断过长文本
truncate_text() {
  local text="$1" max_len="${2:-40}"
  ((${#text} > max_len)) && echo "${text:0:max_len-3}..." || echo "$text"
}

# 发送通知
# 参数: $1=icon, $2=agent, $3=title, $4=body
send_notification() {
  local icon="$1" agent="$2" title="$3" body="$4"

  command -v notify-send >/dev/null 2>&1 || return 1
  notify-send -i "$icon" -a "$agent" "$title" "$body"
}

# 播放提示音
play_sound() {
  command -v paplay >/dev/null 2>&1 && paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 || true
}

# ============================================================================
# Stdin Hook (Claude Code / Qoder) 信息提取
# ============================================================================

# 从 stdin hook JSON 输入中提取通知信息
# 参数: $1=hook_input (JSON)
# 返回: 设置全局变量 agent, icon, body
parse_stdin_hook_info() {
  local hook_input="$1"
  body=""
  command -v jq >/dev/null 2>&1 || return 1

  local transcript_path
  transcript_path=$(jq -r '.transcript_path // empty' <<< "$hook_input" 2>/dev/null || true)

  # 根据 transcript_path 路径特征区分 Agent
  if [[ "$transcript_path" == *"/.qoder/"* ]]; then
    agent="Qoder"
    icon="$SCRIPT_DIR/clients/qoder/qoder.png"
  else
    agent="Claude Code"
    icon="$SCRIPT_DIR/clients/claude/claude.png"
  fi

  # 优先从本会话 transcript 中解析最后一次有效 user 输入作为通知正文
  if [ -f "${transcript_path:-}" ]; then
    body=$(jq -r '
      select((.type == "user" or .role == "user" or .message.role == "user") and (.isMeta | not))
      | if (.message.content | type) == "string" then .message.content
        elif (.message.content | type) == "array" then (.message.content[] | select(.type == "text") | .text)
        elif (.content | type) == "string" then .content
        else empty end
    ' "$transcript_path" 2>/dev/null | grep -vE '^<local-command|^<command-name>' | tail -n 1 || true)
  fi
}

# ============================================================================
# Codex 信息提取
# ============================================================================

# 从 Codex CLI 参数中提取通知信息
# 参数: $@ = 命令行参数
# 返回: 设置全局变量 agent, icon, body
parse_codex_info() {
  agent="Codex"
  icon="$SCRIPT_DIR/clients/codex/openai.png"
  body=""
  command -v jq >/dev/null 2>&1 && [ $# -ge 1 ] || return 0

  # 最后一个参数可能是带 input-messages 的 JSON
  local last_arg="${*: -1}"
  if [[ "$last_arg" == \{* ]]; then
    body=$(jq -r '.["input-messages"] | .[-1] // empty' <<< "$last_arg" 2>/dev/null || true)
  fi
}

# ============================================================================
# 主逻辑
# ============================================================================

main() {
  local agent="" icon="" body=""

  # 读取 stdin（如果有）
  local hook_input=""
  [ -t 0 ] || hook_input="$(cat)"

  # 根据输入来源解析信息
  if [ -n "$hook_input" ]; then
    parse_stdin_hook_info "$hook_input"
  else
    parse_codex_info "$@"
  fi

  body="$(truncate_text "$body" 40)"
  send_notification "$icon" "$agent" "任务已完成" "$body"
  play_sound
}

main "$@"
