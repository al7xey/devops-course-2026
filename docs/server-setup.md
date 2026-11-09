# Конфигурация devops-vm

## 1–3. Виртуальная машина и SSH

Ubuntu Server 24.04.5 LTS, VirtualBox, 2 vCPU и 2 ГБ ОЗУ. enp0s3 — NAT 10.0.2.15/24, enp0s8 — Host-only 192.168.56.103/24. На Windows SSH-алиас devops использует Host-only и порт 2222. Проброс NAT 127.0.0.1:2222 → 2222 гостя. Учётная запись devops входит в sudo. Публичные ключи в authorized_keys с режимом 600, каталог .ssh — 700.

## 4–7. Защита, имена и снимки

В sshd запрещены root, парольная и интерактивная аутентификация. Разрешён devops, MaxAuthTries 3. UFW ограничивает частоту входа по 2222/tcp и допускает HTTP/HTTPS на 80/443. Клиент использует devops.local → 192.168.56.103 через локальный DNS/hosts или curl --resolve. Снимки из исходной истории: 01-clean-install и 04-nginx-https. Проверка настроек: AUDIT_THROUGH=5 sudo -E bash scripts/audit.sh.

## 8. Веб-сервер

Nginx раздаёт /var/www/devops-site на devops.local. Режимы каталога и файлов 755/644, владелец devops, рабочие процессы www-data. HTTP 80 отвечает 301 на HTTPS. /etc/ssl/certs/devops.crt содержит SAN devops.local, ключ /etc/ssl/private/devops.key принадлежит root (600). Конфигурация в sites-available/devops-site включена ссылкой в sites-enabled. Обновление с хоста: scripts/deploy.sh --dry-run, затем scripts/deploy.sh. CA_CERT указывает на скопированный публичный сертификат, CURL_RESOLVE опционально задаёт адрес сервера для проверки HTTPS.

## 9. Контейнеризация

Проект ПР7 из app/ размещается в /home/devops/app. Docker Engine и Compose ставятся из официального apt-репозитория Docker. Файл .env создаётся из .env.example с собственным паролем и правами 600. docker compose up -d --build --wait запускает приложение и PostgreSQL. Nginx направляет /app/ в http://127.0.0.1:5000/. PostgreSQL доступен только в backend под именем db. Именованный том db_data переживает down. Проверки: docker compose ps, docker compose port app 5000, curl с CA на /app/health и AUDIT_THROUGH=7 sudo -E bash scripts/audit.sh.

КР2 варианта 4 устанавливается отдельно в /home/devops/kr2. Файл .env с новым паролем имеет режим 600. Redis доступен под именем redis, использует внутреннюю сеть backend и том redis_data. У приложения есть также frontend, опубликован только 127.0.0.1:8004. Nginx обслуживает kv.devops.local с отдельным сертификатом и проксирует к этому порту. Проверки: /health, /whoami, счётчик /, diff правил UFW и sudo bash scripts/audit.sh.
