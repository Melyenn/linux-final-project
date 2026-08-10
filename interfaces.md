# interfaces.md

## 1. Infrastructure

| Name | Role | OS | Private IP | Public IP |
|---|---|---|---|---|
| linux-main | Main service server | Ubuntu 22.04 | 172.31.1.236 | 3.215.241.147 |
| linux-backup | Backup server | Ubuntu 22.04 | 172.31.2.78 | 32.199.99.190 |

---

## 2. Network Ports

| Service | Host | Bind | Port | Exposure |
|---|---|---|---:|---|
| SSH | linux-main | 0.0.0.0 | 22 | Restricted by SG + UFW |
| SSH | linux-backup | 0.0.0.0 | 22 | Restricted by SG + UFW |
| Nginx HTTP | linux-main | 0.0.0.0 | 80 | Public |
| Nginx HTTPS | linux-main | 0.0.0.0 | 443 | Public if TLS enabled |
| Application | linux-main | 127.0.0.1 | 8000 | Local only |
| PostgreSQL | linux-main | 127.0.0.1 | 5432 | Local only |

---

## 3. Hostnames

Main:

linux-main

Backup:

linux-backup

---

## 4. Users

Administration user:

tuan
duyen
viet
vinh
phat

---

## 5. Paths

Application:

/opt/capstone-app

Application environment file:

/etc/capstone-app/app.env

Local backup directory:

/data/backups

Remote backup directory:

/backup

Application log:

<APP_LOG_PATH>

---

## 6. Services

Web server:

nginx

Application systemd service:

capstone-app.service

Database:

postgresql

---

## 7. Backup Interface

Source:

linux-main

Destination:

dev@<BACKUP_PRIVATE_IP>:/backup/

Transport:

SSH + rsync

---

## 8. Security Rules

Publicly exposed:

22/tcp
80/tcp
443/tcp if TLS enabled

Not publicly exposed:

8000/tcp
5432/tcp
3306/tcp

---

## 9. Ownership

Infrastructure + Network:
A

Nginx + Web Security:
B

Application + systemd:
C

Database + Backup:
D

Automation + Alerting: