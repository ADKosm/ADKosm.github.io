#!/bin/bash

set -xe

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# -----------------------------------------------------------------------------

mkdir -p $DIR/compose-1

cat > $DIR/compose-1/Dockerfile <<END
FROM python:3.7

WORKDIR /sync-folder

ENTRYPOINT ["python3", "-m", "http.server", "--bind", "0.0.0.0", "8080"]
END

cat > $DIR/compose-1/docker-compose.yaml <<END
version: "3.7"

services:
  file-server:
    build:
      context: .  # Указываем директорию, где лежит Dockerfile
    ports:
      - 9090:8080  # Указываем, какие порты пробросить
    volumes:
      - ./:/sync-folder  # Указываем, какие директории примонтировать
END

# --------------------------------------------------------------------------------

mkdir -p $DIR/proxy-system-2

cat > $DIR/proxy-system-2/Dockerfile <<END
FROM python:3.7

WORKDIR /sync-folder

ENTRYPOINT ["python3", "-m", "http.server", "--bind", "0.0.0.0", "8080"]
END

cat > $DIR/proxy-system-2/configuration.nginx <<END
user root;
worker_processes  4;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  4096;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;s
    keepalive_timeout   65;

    server {
        listen  8888;

        location /file-server-1 {
            proxy_pass http://file-server-1:8080;   # Перенаправляем в соседний контейнер по именно контейнера!
            rewrite ^/file-server-1/(.*) /$1 break;  # Удаляем префикс /web-server-1
        }

        location /file-server-2 {
            proxy_pass http://file-server-2:8080;
            rewrite ^/file-server-2/(.*) /$1 break;
        }
    }
}
END

cat > $DIR/proxy-system-2/docker-compose.yaml <<END
version: "3.7"

services:
  file-server-1:
    build:
      context: .
    volumes:
      - ./:/shared/folder # Текущая директория
      - ./config.txt:/etc/file-config.txt:ro
  file-server-2:
    build:
      context: .
    volumes:
      - ./config.txt:/etc/file-config.txt:ro
      - /etc:/shared/folder # Директория /etc
  proxy:
    image: nginx:1.17
    volumes:
      - ./configuration.nginx:/etc/nginx/nginx.conf:ro
    ports:
      - 8888:8888
END
