# 1. Cài đặt các gói phần mềm & Khởi tạo dịch vụ hệ thống

Phần này hướng dẫn cập nhật danh mục gói của hệ điều hành sạch, cài đặt các công cụ CLI bổ trợ, công cụ kiểm duyệt mã nguồn, và kích hoạt các dịch vụ nền tảng.

## 1.1 Cài đặt các gói phần mềm

Thực thi lệnh APT sau để cài đặt toàn bộ các công cụ phụ trợ cần thiết:

```bash
# Cập nhật danh mục gói và cài đặt các công cụ bổ trợ
sudo apt update && sudo apt install -y \
  shellcheck \
  nginx \
  curl \
  jq \
  tree \
  auditd \
  audispd-plugins
```

## 1.2 Vai trò của các công cụ

- `shellcheck`: Công cụ phân tích tĩnh mã nguồn Bash (LINTing) đảm bảo không còn lỗi cú pháp hay cảnh báo.
- `nginx`: Web server đóng vai trò reverse proxy và làm mục tiêu thử nghiệm cho health-check cũng như tính năng tự động rollback khi deploy.
- `curl`, `jq`, `tree`: Bộ công cụ dòng lệnh để giao tiếp với Telegram Bot API qua HTTP, xử lý dữ liệu JSON và hiển thị cây thư mục.
- `auditd`, `audispd-plugins`: Khung kiểm toán cấp Kernel Linux giúp theo dõi vết truy cập/chỉnh sửa các tập tin hệ thống nhạy cảm.

## 1.3 Kích hoạt dịch vụ

Bật và khởi chạy các dịch vụ hệ thống ngay lập tức:

```bash
# Kích hoạt và khởi chạy dịch vụ cùng hệ thống khi khởi động
sudo systemctl enable --now nginx auditd
```

# 2. Kiến trúc Thư mục & Gia cố Bảo mật

Khởi tạo cấu trúc thư mục chuẩn đã được định nghĩa trong `interfaces.md` và áp dụng phân quyền POSIX nghiêm ngặt.

## 2.1 Tạo thư mục & Phân quyền sở hữu

Thực thi các lệnh sau để tạo các thư mục vận hành mục tiêu và gán quyền sở hữu phù hợp:

```bash
# Tạo các thư mục ứng dụng, nhật ký log, sao lưu và cấu hình môi trường
sudo mkdir -p /opt/myapp /var/log/myapp /var/backups/myapp /etc/myapp

# Gán quyền sở hữu cho tài khoản người dùng (viet:viet) đối với các thư mục vận hành
sudo chown -R viet:viet /opt/myapp /var/log/myapp /var/backups/myapp

# Thiết lập phân quyền chuẩn
sudo chmod 755 /opt/myapp /var/log/myapp
sudo chmod 700 /var/backups/myapp

# Gán quyền sở hữu root cho thư mục cấu hình hệ thống
sudo chown -R root:root /etc/myapp
```

## 2.2 Khởi tạo tệp môi trường bí mật (/etc/myapp/app.env)

Tạo tệp cấu hình môi trường tập trung chứa các thông số mặc định và thông tin xác thực cảnh báo:

```bash
# Khởi tạo tệp môi trường 
sudo nano /etc/myapp/app.env
```
File .env mẫu

```bash
DB_DATABASE=<your_db_database>
DB_USER=<your_db_user>
DB_PASSWORD=<your_db_password>
DB_HOST=<your_db_host>
DB_PORT=<your_db_port>

TELEGRAM_BOT_TOKEN=TOKEN_TELEGRAM
TELEGRAM_CHAT_ID=CHAT_ID
ALERT_EMAIL_TO=GMAIL_@gmail.com
ALERT_EMAIL_FROM=GMAIL_@gmail.com
ALERT_CHANNEL="all"

CPU_THRESHOLD=80
RAM_THRESHOLD=85
DISK_THRESHOLD=90
```

## 2.3 Khởi tạo tệp cấu hình dịch vụ Gửi Mail (/etc/msmtprc)

```bash
# Khởi tạo tệp msmtprc
sudo nano /etc/msmtprc
```

File msmtprc mẫu

```bash
# Set default values for all following accounts.
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

# Gmail Configuration
account        gmail
host           smtp.gmail.com
port           587
from           YOUR_GMAIL_ADDRESS@gmail.com
user           YOUR_GMAIL_ADDRESS@gmail.com
password       "16_KY_TU_APP_PASSWORD"

# Set a default account
account default : gmail
```

## 2.4 Khởi tạo Dịch vụ Systemd (/etc/systemd/system/myapp.service)

```bash
# Khởi tạo tệp service unit
sudo nano /etc/systemd/system/myapp.service
```

```bash
# Nạp lại danh sách dịch vụ và kích hoạt tự động chạy khi khởi động
sudo systemctl daemon-reload
sudo systemctl enable myapp.service
```

## 2.5 Gia cố bảo mật các tệp chứa bí mật

Giới hạn quyền truy cập cho các tệp nhạy cảm (`app.env` và `msmtprc`) để ngăn ngừa lộ mật khẩu CSDL và thông tin xác thực Mail:

```bash
# Cấp quyền đọc file app.env cho user chạy service (viet)
sudo chown viet:viet /etc/myapp/app.env
sudo chmod 640 /etc/myapp/app.env

# Bảo mật tuyệt đối tệp msmtprc chứa mật khẩu SMTP (chỉ root truy cập)
sudo chown root:root /etc/msmtprc
sudo chmod 600 /etc/msmtprc

# Kiểm tra lại danh mục phân quyền
ls -l /etc/myapp/app.env /etc/msmtprc


# Kết quả kỳ vọng: 
  #-rw------- 1 root root ... /etc/myapp/app.env
  #-rw------- 1 root root ... /etc/msmtprc
```

# 3. Khởi tạo Thư mục Toolkit & Kiểm duyệt Chất lượng Mã nguồn

Thiết lập thư mục làm việc của bộ công cụ, cấp quyền thực thi và kiểm tra chất lượng mã nguồn.

## 3.1 Cấu hình Thư mục & Phân quyền

Tạo thư mục làm việc cho người dùng và cấp cờ thực thi (+x) cho toàn bộ các script:

```bash
# Chuyển về thư mục home của user và tạo thư mục toolkit
mkdir -p ~/toolkit
cd ~/toolkit

# Cấp quyền thực thi cho tất cả tệp script shell
chmod +x ~/toolkit/*.sh
```

## 3.2 Kiểm duyệt Chất lượng bằng Shellcheck

Quét toàn bộ mã nguồn script trong bộ công cụ để đảm bảo không dính lỗi cú pháp hay cảnh báo nào:

```bash
# Chạy phân tích tĩnh mã nguồn trên toàn bộ các script
shellcheck ~/toolkit/*.sh
```

- Kết quả kỳ vọng: Lệnh kết thúc thành công và không in ra bất kỳ dòng lỗi hay cảnh báo nào (Clean 100%).

# 4. Kịch bản Kiểm thử Vận hành Chi tiết (Test Cases)

Thực thi các kịch bản kiểm thử sau đây để xác nhận khả năng tự động hóa, phát hiện sự cố và gửi cảnh báo theo thời gian thực.

### Test Case 4.1: Kiểm thử Module Cảnh báo Trực tiếp (send_alert.sh)

Xác nhận khả năng kết nối tới Telegram Bot API và dịch vụ Email.

```bash
# Thực thi gửi tin nhắn cảnh báo trực tiếp qua Telegram và Email
~/toolkit/send_alert.sh -c all "TEST_ALERT" "Direct test notification from EC2 Sandbox."
```

- Kết quả kỳ vọng trên Terminal:

```text
[INFO] Sending alert via Telegram Bot...
[INFO] Telegram alert delivered successfully.
[INFO] Sending alert via Email (msmtp) to viet.admin@lab.local...
[INFO] Email alert dispatched successfully.
```

- Kết quả thực tế kỳ vọng: Thông báo đẩy xuất hiện ngay lập tức trên thiết bị Telegram và hòm thư Gmail.

### Test Case 4.2: Giám sát Sức khỏe Hệ thống (health-check.sh)

#### Kịch bản 4.2.1: Điều kiện Vận hành Bình thường

```bash
# Chạy health-check trong trạng thái hệ thống ổn định
~/toolkit/health_check.sh
```

- Kết quả kỳ vọng:

```text
[INFO] System health status: ALL CHECKS PASSED OK.
```

- Mã thoát (Exit Code): `0`

#### Kịch bản 4.2.2: Giả lập Dịch vụ Sập & Kích hoạt Cảnh báo

```bash
# 1. Giả lập sự cố ngắt dịch vụ Nginx
sudo systemctl stop nginx

# 2. Thực thi script giám sát health-check
~/toolkit/health-check.sh
```

- Kết quả kỳ vọng:

```text
[WARN] Service 'nginx': INACTIVE/FAILED
[WARN] Port 80: NOT LISTENING
========================================================
[CRITICAL] System health breach(es) detected:
- Service 'nginx' is not running
- Port 80 is not listening
========================================================
[INFO] Triggering alert dispatcher...
[INFO] Telegram alert delivered successfully.
```

- Bước Phục hồi:

```bash
# Khởi động lại dịch vụ Nginx sau khi kiểm thử xong
sudo systemctl start nginx
```

### Test Case 4.3: Triển khai An toàn & Tự động Rollback (deploy.sh)

#### Kịch bản 4.3.1: Triển khai Thành công

```bash

# Giải phóng Port 5000 (nếu bị tiến trình rác chiếm dụng) và khởi động lại dịch vụ
sudo fuser -k 5000/tcp
sudo systemctl restart myapp.service

# Kiểm tra phản hồi trực tiếp từ API Endpoint
curl -i http://localhost:5000/products

# Kiểm tra trạng thái chi tiết và 20 dòng log mới nhất
sudo systemctl status myapp.service
sudo journalctl -u myapp.service -n 20 --no-pager

# Thực thi quy trình triển khai mã nguồn ứng dụng
~/toolkit/deploy.sh

# Lấy địa chỉ IP chính của máy chủ để truy cập từ bên ngoài
hostname -I | awk '{print $1}'
```

- Kết quả kỳ vọng:

```text
[INFO] Deployment completed successfully! Application is live and healthy.
```

#### Kịch bản 4.3.2: Giả lập Lỗi Cấu hình & Tự động Rollback

```bash
# 1. Chèn một tệp cấu hình Nginx bị lỗi cú pháp
echo "server {" | sudo tee /etc/nginx/sites-enabled/broken.conf

# 2. Thực thi quy trình deploy
~/toolkit/deploy.sh
```

- Kết quả kỳ vọng:

```text
[INFO] Testing Nginx configuration syntax...
nginx: [emerg] unexpected end of file, expecting "}" in /etc/nginx/sites-enabled/broken.conf:2
[ERROR] Deployment error occurred on line 125 with exit code 1.
[WARN] Deployment failed! Executing automatic rollback...
[INFO] Restoring previous application codebase from /var/backups/myapp/releases/previous_release...
[INFO] Rollback completed. System restored to previous working version.
[INFO] Triggering failure alert notification...
```

- Bước Dọn dẹp:

```bash
# Xóa tệp cấu hình bị lỗi và reload lại Nginx
sudo rm -f /etc/nginx/sites-enabled/broken.conf
sudo systemctl reload nginx
```

### Test Case 4.4: Xoay vòng Log & Chính sách Retention (log-rotate.sh)

Xác nhận khả năng làm rỗng log đang chạy, nén gzip, và tự động dọn dẹp các tệp log vượt quá số lượng retention.

```bash
# 1. Tải dữ liệu giả lập vào tệp log đang hoạt động
echo "2026-08-14 18:00:00 [INFO] Active log entry" > /var/log/myapp/app.log

# 2. Giả lập 7 tệp nén log cũ từ quá khứ
for i in {1..7}; do
    echo "Old log archive $i" | gzip > "/var/log/myapp/app.log.${i}.gz"
done

# 3. Thực thi xoay vòng log giữ lại 5 thế hệ (N=5)
~/toolkit/log-rotate.sh -f /var/log/myapp/app.log -k 5

# 4. Kiểm tra danh sách tệp trong thư mục sau khi xoay log
ls -1 /var/log/myapp/
```

- Kết quả Danh sách Thư mục Kỳ vọng:

```text
app.log
app.log.1.gz
app.log.2.gz
app.log.3.gz
app.log.4.gz
app.log.5.gz
```

- Ghi chú Kiểm chứng: Tệp `app.log` được làm rỗng về 0 bytes, `app.log.1.gz` chứa dữ liệu log vừa xoay, còn các bản archive `app.log.6.gz` và `app.log.7.gz` đã bị tự động xóa bỏ.

### Test Case 4.5: Vết Kiểm toán Bảo mật Auditd (auditd.rules)

Xác nhận Linux Kernel ghi nhận dấu vết kiểm toán khi các tệp tin hệ thống nhạy cảm bị truy cập.

```bash
# 1. Nạp quy tắc kiểm toán tùy chỉnh vào Kernel
sudo cp ~/toolkit/auditd.rules /etc/audit/rules.d/capstone.rules
sudo augenrules --load

# 2. Kiểm tra các quy tắc đang hoạt động trong Kernel
sudo auditctl -l
# Kết quả kỳ vọng: -w /etc/shadow -p rwa -k identity_shadow

# 3. Giả lập hành vi truy cập đọc tệp nhạy cảm /etc/shadow
sudo cat /etc/shadow > /dev/null

# 4. Truy xuất vết log kiểm toán bằng từ khóa key
sudo ausearch -k identity_shadow --start recent -i
```

- Kết quả Log Auditd Kỳ vọng:

```text
type=SYSCALL msg=audit(...): arch=x86_64 syscall=openat success=yes ... comm=cat exe=/usr/bin/cat key=identity_shadow
```

### Test Case 4.6: Giao diện CLI Menu Điều phối (menu.sh)

#### Kịch bản 4.6.1: Điều phối bằng Cờ Tham số Dòng lệnh

```bash
# Hiển thị tài liệu hướng dẫn CLI
~/toolkit/menu.sh -h

# Thực thi trực tiếp chức năng health-check
~/toolkit/menu.sh -c
```

#### Kịch bản 4.6.2: Giao diện Menu Tương tác TUI

```bash
# Khởi chạy menu tương tác
~/toolkit/menu.sh
```

- Giao diện Kỳ vọng:

```text
========================================================
   CAPSTONE SYSTEM OPERATIONS & AUTOMATION TOOLKIT
========================================================
1) Deploy Application (deploy.sh)
2) Run System Backup    (backup_db.sh)
3) Restore System Data (restore.sh)
4) Run Health Check     (health-check.sh)
5) Rotate Log Files     (log-rotate.sh)
6) Exit
========================================================
Select an option [1-6]:
```
