#!/usr/bin/env bash
set -euo pipefail

# Chọn python interpreter có pycryptodome
PY_AGENT_ENV="/opt/homebrew/Caskroom/miniconda/base/envs/agent-env/bin/python"
if [ -x "$PY_AGENT_ENV" ]; then
  PYTHON_BIN="$PY_AGENT_ENV"
else
  PYTHON_BIN="python3"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENC_PY="$SCRIPT_DIR/enc.py"
KEY_HTML="$SCRIPT_DIR/key.html"

if [ ! -f "$ENC_PY" ]; then
  echo "Không tìm thấy $ENC_PY" >&2
  exit 1
fi

if [ ! -f "$KEY_HTML" ]; then
  echo "Không tìm thấy $KEY_HTML" >&2
  exit 1
fi

read -r -p "Nhập MESSAGE: " MESSAGE

# Chạy enc.py với biến môi trường MESSAGE, bắt output
ENC_OUTPUT=$(MESSAGE="$MESSAGE" "$PYTHON_BIN" "$ENC_PY")

echo "$ENC_OUTPUT"

# Trích xuất Encrypt và Decrypt từ output
# Lấy phần sau dấu ":" và trim khoảng trắng hai bên
ENCRYPT_VAL=$(printf "%s\n" "$ENC_OUTPUT" | awk -F":" '/^Encrypt:/ {sub(/^ +| +$/,"",$2); print $2; exit}')
DECRYPT_VAL=$(printf "%s\n" "$ENC_OUTPUT" | awk -F":" '/^Decrypt:/ {sub(/^ +| +$/,"",$2); print $2; exit}')

if [ -z "${ENCRYPT_VAL:-}" ] || [ -z "${DECRYPT_VAL:-}" ]; then
  echo "Không thể trích xuất Encrypt/Decrypt từ output." >&2
  exit 1
fi

# Append "Encrypt|Decrypt" vào key.html (định dạng JSON hiện có)
"$PYTHON_BIN" - "$KEY_HTML" "$ENCRYPT_VAL" "$DECRYPT_VAL" << 'PYAPPEND'
import json,sys
path=sys.argv[1]
enc=sys.argv[2]
dec=sys.argv[3]
with open(path,'r',encoding='utf-8') as f:
    data=json.load(f)
if not isinstance(data,dict) or 'key' not in data or not isinstance(data['key'],list):
    print('File key.html không đúng cấu trúc JSON mong đợi.', file=sys.stderr)
    sys.exit(1)
# Trim an toàn trong Python trước khi ghép
enc = enc.strip()
dec = dec.strip()
entry=f"{enc}|{dec}"
data['key'].append(entry)
with open(path,'w',encoding='utf-8') as f:
    json.dump(data,f,ensure_ascii=False,indent=2)
    f.write('\n')
print('Đã cập nhật key.html với mục:', entry)
PYAPPEND

echo
echo "Bạn có muốn đẩy code lên GitHub?"
echo "1) Có"
echo "2) Không"
read -r -p "Chọn 1 hoặc 2: " CHOICE

if [ "${CHOICE}" = "1" ]; then
  git add .
  # Thực hiện commit theo yêu cầu (giữ nguyên tham số người dùng cung cấp)
  git commit -m "update-v2" --no-veri || true
  git push origin main
  echo "Đã push lên origin main."
else
  echo "Bỏ qua bước push."
fi


