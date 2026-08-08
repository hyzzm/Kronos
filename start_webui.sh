#!/bin/bash
# ============================================================
#  Kronos WebUI 一键启动脚本
#  - 自动检查/创建 Python 虚拟环境 (.venv) 并安装依赖
#  - 自动检查本地模型文件
#  - 启动 Flask 服务并打开浏览器
#  用法: ./start_webui.sh
# ============================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBUI_DIR="$PROJECT_DIR/webui"
VENV_DIR="$PROJECT_DIR/.venv"
PY="$VENV_DIR/bin/python"
PORT=7070

echo "🚀 Kronos WebUI 一键启动"
echo "================================="

# ---------- 1. 端口检查：已在运行就直接开浏览器 ----------
if lsof -i :$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "✅ 服务已在运行 (端口 $PORT)"
    open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT" 2>/dev/null
    echo "🌐 http://localhost:$PORT"
    exit 0
fi

# ---------- 2. 虚拟环境 ----------
if [ ! -x "$PY" ]; then
    echo "📦 未找到虚拟环境，正在创建..."
    if ! command -v uv >/dev/null 2>&1; then
        echo "❌ 未找到 uv。请先安装:"
        echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    uv venv --python 3.11 "$VENV_DIR" || { echo "❌ venv 创建失败"; exit 1; }
    echo "📦 安装依赖 (清华 PyPI 镜像)..."
    uv pip install --python "$PY" -r "$PROJECT_DIR/requirements.txt" -r "$WEBUI_DIR/requirements.txt" \
        -i https://pypi.tuna.tsinghua.edu.cn/simple || { echo "❌ 依赖安装失败"; exit 1; }
else
    echo "✅ 虚拟环境就绪"
fi

# ---------- 3. 模型文件检查 ----------
if [ ! -f "$PROJECT_DIR/models/NeoQuasar/Kronos-small/model.safetensors" ]; then
    echo "❌ 模型文件缺失 (models/NeoQuasar/)"
    echo "   请从 hf-mirror.com 下载 NeoQuasar/Kronos-small 与 Kronos-Tokenizer-base"
    exit 1
fi
echo "✅ 模型文件就绪 (Kronos-mini / Kronos-small)"

# ---------- 4. 数据目录 ----------
if [ -z "$(ls -A "$PROJECT_DIR/data" 2>/dev/null)" ]; then
    echo "⚠️  data/ 目录为空，界面将没有可用的数据文件"
    echo "   把 CSV/feather 格式的 K 线数据 (需含 open/high/low/close 列) 放到 $PROJECT_DIR/data/"
fi

# ---------- 5. 启动 ----------
echo "🌐 启动服务: http://localhost:$PORT"
( sleep 2; open "http://localhost:$PORT" 2>/dev/null || xdg-open "http://localhost:$PORT" 2>/dev/null ) &
cd "$WEBUI_DIR"
exec "$PY" app.py
