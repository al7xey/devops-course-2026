# Конфигурация devops-vm

## 1–3. Виртуальная машина и SSH

Ubuntu Server 24.04.5 LTS, VirtualBox, 2 vCPU и 2 ГБ ОЗУ. enp0s3 — NAT 10.0.2.15/24, enp0s8 — Host-only 192.168.56.104/24. На Windows SSH-алиас devops использует Host-only и порт 2222. Проброс NAT 127.0.0.1:32223 → 2222 гостя. Учётная запись devops входит в sudo. Публичные ключи в authorized_keys с режимом 600, каталог .ssh — 700.

## 4–7. Защита, имена и снимки

В sshd запрещены root, парольная и интерактивная аутентификация. Разрешён devops, MaxAuthTries 3. UFW ограничивает частоту входа по 2222/tcp и допускает HTTP/HTTPS на 80/443. Клиент использует devops.local → 192.168.56.104 через локальный DNS/hosts или curl --resolve. Снимки из исходной истории: 01-clean-install и 04-nginx-https. Проверка настроек: AUDIT_THROUGH=5 sudo -E bash scripts/audit.sh.

## 8. Веб-сервер

Nginx раздаёт /var/www/devops-site на devops.local. Режимы каталога и файлов 755/644, владелец devops, рабочие процессы www-data. HTTP 80 отвечает 301 на HTTPS. /etc/ssl/certs/devops.crt содержит SAN devops.local, ключ /etc/ssl/private/devops.key принадлежит root (600). Конфигурация в sites-available/devops-site включена ссылкой в sites-enabled. Обновление с хоста: scripts/deploy.sh --dry-run, затем scripts/deploy.sh. CA_CERT указывает на скопированный публичный сертификат, CURL_RESOLVE опционально задаёт адрес сервера для проверки HTTPS.

## 9. Контейнеризация

Проект ПР7 из app/ размещается в /home/devops/app. Docker Engine и Compose ставятся из официального apt-репозитория Docker. Файл .env создаётся из .env.example с собственным паролем и правами 600. docker compose up -d --build --wait запускает приложение и PostgreSQL. Nginx направляет /app/ в http://127.0.0.1:5000/. PostgreSQL доступен только в backend под именем db. Именованный том db_data переживает down. Проверки: docker compose ps, docker compose port app 5000, curl с CA на /app/health и AUDIT_THROUGH=7 sudo -E bash scripts/audit.sh.

КР2 варианта 4 устанавливается отдельно в /home/devops/kr2. Файл .env с новым паролем имеет режим 600. Redis доступен под именем redis, использует внутреннюю сеть backend и том redis_data. У приложения есть также frontend, опубликован только 127.0.0.1:8004. Nginx обслуживает kv.devops.local с отдельным сертификатом и проксирует к этому порту. Проверки: /health, /whoami, счётчик /, diff правил UFW и sudo bash scripts/audit.sh.


## 10. Проверка и восстановление 16 ноября 2026

Основная VirtualBox VM devops-vm останавливается на этапе загрузки ядра. Исходные диски и снимки сохранены. Для повторного выполнения используется существующая резервная VM devops-vm-labs, hostname внутри Ubuntu — devops-vm. Перед изменениями создан recovery-before-completion-20261116. У второго адаптера был отключён виртуальный кабель: VBoxManage controlvm devops-vm-labs setlinkstate2 on.

Host-only enp0s8: статический 192.168.56.104/24 через /etc/netplan/60-lab-hostonly.yaml, NAT enp0s3: DHCP. WSL Ubuntu — только SSH/rsync/curl-клиент; Docker и Nginx работают внутри VirtualBox. В ~/.ssh/config WSL псевдоним devops указывает на 192.168.56.104:2222 и IdentityFile ~/.ssh/devops_vm. Публичный ключ добавлен в authorized_keys через уже доверенное SSH-подключение Windows; закрытый ключ не копируется на сервер. Ключ хоста проверен через доверенный канал.

/etc/hosts WSL: 192.168.56.104 devops.local kv.devops.local. WSL ControlMaster/ControlPersist повторно используют соединение и предотвращают блокировку UFW LIMIT из-за серии отдельных scp/ssh.

Docker Engine 29.10.0 и Docker Compose v5.7.1 установлены из подписанного APT-репозитория download.docker.com (Ubuntu noble). После добавления devops в docker требуется новое SSH-соединение.

Повторная доставка: сначала rsync --dry-run, затем rsync с --exclude=.env --exclude=.git. Секреты генерируются openssl rand -hex 32 только внутри ВМ, режим 600. Для app используются python:3.12-slim и postgres:16-alpine; для КР2 redis:7-alpine.
