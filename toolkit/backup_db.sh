#!/bin/bash

# 1. Đọc biến môi trường từ file .env (ở thư mục cha)
source ../.env

# 2. Định nghĩa thư mục lưu backup và tên file dựa trên thời gian
BACKUP_DIR="../infra/storage"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/appdb_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

# 3. Sử dụng pg_dump để backup CSDL. 
# Dùng PGPASSWORD để bỏ qua prompt hỏi mật khẩu thủ công.
echo "Bắt đầu sao lưu cơ sở dữ liệu ${DB_DATABASE}..."
PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -F c -b -v -f "${BACKUP_FILE}" "${DB_DATABASE}"

if [ $? -eq 0 ]; then
    echo "Sao lưu thành công! File lưu tại: ${BACKUP_FILE}"
else
    echo "Sao lưu thất bại!"
fi