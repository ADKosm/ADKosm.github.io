#!/bin/bash

set -xe

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# -----------------------------------------------------------------------------

mkdir -p /machine-info
touch /machine-info/node-1

cat > $DIR/run-vis.sh <<END
docker service create \\
  --name=viz \\
  --publish=8080:8080/tcp \\
  --constraint=node.role==manager \\
  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \\
  dockersamples/visualizer
END

cat > $DIR/configuration.nginx <<END
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
    tcp_nopush          on;
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


cat > $DIR/docker-compose.yaml <<END
version: "3.7"

services:
  file-server-1:
    image: halverneus/static-file-server
    deploy:
      mode: replicated
      replicas: 2  # Добавляем 2 реплики этого сервиса
    volumes:
      - /machine-info:/web  # Директория с информацией про машину
  file-server-2:
    image: halverneus/static-file-server
    volumes:
      - /etc:/web
  proxy:
    image: nginx:1.17
    ports:
      - 8888:8888
    configs:
      - source: nginx-config
        target: /etc/nginx/nginx.conf  # Подключаем конфигурацию

networks:
  backnet:
    external: true  # Используем созданную извне сеть с названием backnet

configs:  # Задаем файлы конфигураций, которые необходимо распределить по кластеру
  nginx-config:
    file: ./configuration.nginx
END