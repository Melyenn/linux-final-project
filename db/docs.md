# Hướng Dẫn Chi Tiết Triển Khai CSDL & Ứng Dụng Flask

## 1. Cài đặt PostgreSQL trực tiếp trên OS (Hoàn thành: 20:30 10/08/2026)
```bash
# Ubuntu 22.04
sudo apt update && sudo apt install -y postgresql postgresql-contrib
```

## 2. Tạo CSDL & User với đặc quyền tối thiểu
### Lý do:
- Không dùng tài khoản postgres (admin) cho ứng dụng để tránh rủi ro bảo mật. Nếu ứng dụng bị lỗ hổng (SQL Injection), kẻ tấn công không thể chiếm quyền kiểm soát toàn bộ máy chủ database hay các CSDL khác.
- Quyền tối thiểu: User appuser chỉ có quyền thao tác (đọc/ghi) trên CSDL appdb.

### Đọc biến DB_PASSWORD và tạo CSDL, User (Hoàn thành: 21:25 10/08/2026)
```bash
# init database
cat db/init-db.sql | (cd /tmp && sudo -u postgres psql -v db_password='Demo@@123')
```

## 3. Kiểm tra kết nối CSDL (Hoàn thành 21:29 10/08/2026)
```bash
# Kiểm tra kết nối
PGPASSWORD='Demo@@123' psql -h 127.0.0.1 -U appuser -d appdb -c "\conninfo"
```

## 4. Cấu hình CSDL chỉ nghe trên localhost (Hoàn thành 21:33 10/08/2026)
```bash
sudo vim /etc/postgresql/14/main/postgresql.conf #đường dẫn có thể khác nhau

# Tìm và sửa
listen_addresses = 'localhost'
port = 5432

# Restart service
sudo systemctl restart postgresql

# Kiểm tra lại (nếu code local host chỉ hiển thi 127.0.0.1:5432 hoặc [::1]:5432) => đúng. Nếu hiện thị 0.0.0.0:5432 hoặc *:5432 => sai)
sudo ss -tulpn | grep -E "Netid|5432"

```
