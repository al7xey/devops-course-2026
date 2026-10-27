# Настройка сервера

## 8. Веб-сервер
- Пакет: nginx 1.24.0 (apt), rsync
- Конфигурация: /etc/nginx/sites-available/devops-site (ссылка в sites-enabled; default отключён)
- Каталог ресурса: /var/www/devops-site, владелец devops, права 755/644
- Сертификат: /etc/ssl/certs/devops.crt (644); ключ: /etc/ssl/private/devops.key (600, root)
- Срок действия: 365 дней
