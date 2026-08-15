#!/bin/bash

# Lấy đường dẫn thư mục chứa script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. Đọc và tự động export biến môi trường từ file .env ở thư mục gốc của project (loại bỏ ký tự \r của Windows)
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    eval "$(tr -d '\r' < "$PROJECT_ROOT/.env")"
    set +a
fi

# 2. Gán giá trị mặc định nếu biến môi trường bị thiếu
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-Demo@@123}"
DB_DATABASE="${DB_DATABASE:-appdb}"

# Debug thông tin kết nối (ẩn bớt mật khẩu)
echo "--- DEBUG INFO ---"
echo "Project Root: $PROJECT_ROOT"
echo "DB Host: $DB_HOST"
echo "DB Port: $DB_PORT"
echo "DB User: $DB_USER"
echo "DB Database: $DB_DATABASE"
echo "DB Password Length: ${#DB_PASSWORD} ký tự"
echo "------------------"

# 3. Định nghĩa thư mục lưu backup
BACKUP_DIR="$PROJECT_ROOT/infra/storage"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/appdb_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

# 4. Thực hiện backup với file .pgpass tạm thời
echo "Bắt đầu sao lưu cơ sở dữ liệu ${DB_DATABASE}..."

# Tạo file pgpass tạm thời
PGPASS_TMP=$(mktemp)
echo "${DB_HOST}:${DB_PORT}:${DB_DATABASE}:${DB_USER}:${DB_PASSWORD}" > "$PGPASS_TMP"
chmod 600 "$PGPASS_TMP"

# Chạy pg_dump với PGPASSFILE
PGPASSFILE="$PGPASS_TMP" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -F c -b -v -f "${BACKUP_FILE}" "${DB_DATABASE}"
RC=$?

# Xóa file pgpass tạm thời
rm -f "$PGPASS_TMP"

if [ $RC -eq 0 ]; then
    echo "Sao lưu thành công! File lưu tại: ${BACKUP_FILE}"
else
    echo "Sao lưu thất bại! Mã lỗi exit code: $RC"
fi