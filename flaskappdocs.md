## Một ứng dụng chạy được (Flask, FastAPI, hoặc Node.js/Express). Có thể nhỏ, nhưng phải giao tiếp với CSDL và có ít nhất một endpoint đọc và một endpoint ghi. (Hoàn thành)

## Một CSDL quan hệ — PostgreSQL hoặc MySQL: tạo CSDL riêng và một user/role ứng dụng chỉ với quyền cần thiết (nguyên tắc đặc quyền tối thiểu), không dùng tài khoản quản trị của CSDL cho ứng dụng. (Hoàn thành)

## CSDL chỉ nghe trên localhost (bind-address với MySQL, hoặc listen_addresses/pg_hba với PostgreSQL) — không truy cập được từ bên ngoài máy. Chứng minh bằng ss khi demo (Hoàn thành)

## Ứng dụng chạy như một dịch vụ systemd: có .service unit với Restart=on-failure, một EnvironmentFile cho bí mật (chuỗi kết nối/thông tin CSDL), và log đẩy về journald qua stdout/stderr (Hoàn thành 08:40 15/08/2026) 
```bash
sudo cp infra/flaskapp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start flaskapp
sudo systemctl status flaskapp.service
sudo journalctl -u flaskapp.service -n 20 --no-pager
```

## Bí mật để ngoài mã nguồn — trong EnvironmentFile với quyền hạn chế — không hard-code. Báo cáo phải cho thấy quyền của file đó. (Hoàn thành 08:47 15/08/2026)
```bash
$ ls -l .env
-rw------- 1 duyen duyen 22 Aug 11 06:42 .env
```

## Sao lưu CSDL (mysqldump hoặc pg_dump) do bộ công cụ ở Mục 6 đảm nhận, theo phần nền tảng §3.3.
