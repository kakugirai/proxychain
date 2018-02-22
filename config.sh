#!/usr/bin/env bash

# ============================ Setting ===========================
VIRTUAL_HOST_NAME='' # v2ray.example.com
VMESS_PORT='' # Port number used by VMess. Port number higher than 10000 is recommended.
VMESS_UUID='' # Run `curl https://www.uuidgenerator.net/api/version1` to generator one
ALTERID='' # Depends on users you have. Each user may consume 0.1MB memory. For my 1GB memory machine, I set it to 3000.
LETSENCRYPT_EMAIL='' # Your email address


# ============================ Server Config ===========================
echo '{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbound": {
        "port": '$VMESS_PORT',
        "protocol": "vmess",
        "settings": {
            "clients": [{
                "id": "'$VMESS_UUID'",
                "level": 1,
                "alterId": '$ALTERID'
            }]
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {
                "connectionReuse": true,
                "path": "/"
            }
        },
        "detour": {
            "to": "vmess-detour"
        }
    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    },
    "inboundDetour": [{
        "protocol": "vmess",
        "port": "10000-11000",
        "tag": "vmess-detour",
        "settings": {},
        "allocate": {
            "strategy": "random",
            "concurrency": 5,
            "refresh": 5
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {
                "connectionReuse": true,
                "path": "/"
            }
        }
    }],
    "outboundDetour": [{
        "protocol": "blackhole",
        "settings": {},
        "tag": "blocked"
    }],
    "routing": {
        "strategy": "rules",
        "settings": {
            "rules": [{
                "type": "field",
                "ip": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "100.64.0.0/10",
                    "127.0.0.0/8",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.0.0.0/24",
                    "192.0.2.0/24",
                    "192.168.0.0/16",
                    "198.18.0.0/15",
                    "198.51.100.0/24",
                    "203.0.113.0/24",
                    "::1/128",
                    "fc00::/7",
                    "fe80::/10"
                ],
                "outboundTag": "blocked"
            }]
        }
    }
}' > server.json

# ============================ Client Config ===========================
echo '{
    "log": {
        "loglevel": "warning"
    },
    "inbound": {
        "listen": "127.0.0.1",
        "port": 1081,
        "protocol": "socks",
        "settings": {
            "auth": "noauth",
            "udp": true,
            "ip": "127.0.0.1"
        }
    },
    "outbound": {
        "protocol": "vmess",
        "settings": {
            "vnext": [{
                "address": "'$VIRTUAL_HOST_NAME'",
                "port": '$VMESS_PORT',
                "users": [{
                    "id": "'$VMESS_UUID'",
                    "level": 1,
                    "alterId": '$ALTERID'
                }]
            }]
        },
        "mux": {
            "enabled": true,
            "concurrency": 8
        },
        "streamSettings": {
            "security": true,
            "tlsSettings": {
                "serverName": "'$VIRTUAL_HOST_NAME'",
                "allowInsecure": false
            }
        }
    },
    "outboundDetour": [{
        "protocol": "freedom",
        "settings": {},
        "tag": "direct"
    }],
    "routing": {
        "strategy": "rules",
        "settings": {
            "rules": [{
                "type": "field",
                "port": "54-79",
                "outboundTag": "direct"
            }, {
                "type": "field",
                "port": "81-442",
                "outboundTag": "direct"
            }, {
                "type": "field",
                "port": "444-65535",
                "outboundTag": "direct"
            }, {
                "type": "field",
                "domain": [
                    "gc.kis.scr.kaspersky-labs.com"
                ],
                "outboundTag": "direct"
            }, {
                "type": "chinasites",
                "outboundTag": "direct"
            }, {
                "type": "field",
                "ip": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "100.64.0.0/10",
                    "127.0.0.0/8",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.0.0.0/24",
                    "192.0.2.0/24",
                    "192.168.0.0/16",
                    "198.18.0.0/15",
                    "198.51.100.0/24",
                    "203.0.113.0/24",
                    "::1/128",
                    "fc00::/7",
                    "fe80::/10"
                ],
                "outboundTag": "direct"
            }, {
                "type": "chinaip",
                "outboundTag": "direct"
            }]
        }
    }
}' > client.json

# ============================ Docker Config ===========================
echo 'version: "3"

services:
  v2ray:
    container_name: v2ray
    image: v2ray/official
    restart: unless-stopped
    command: v2ray -config=/etc/v2ray/server.json
    expose:
      - "'$VMESS_PORT'" # v2ray port
    ports:
      - "'$VMESS_PORT':'$VMESS_PORT'" # v2ray port
      - "'$VMESS_PORT':'$VMESS_PORT'/udp" # v2ray udp port
    volumes:
      - ./v2ray_logs:/var/log/v2ray/
      - ./server.json:/etc/v2ray/server.json:ro
    environment:
      - "VIRTUAL_HOST='$VIRTUAL_HOST_NAME'"
      - "VIRTUAL_PORT='$VMESS_PORT'"
      - "LETSENCRYPT_HOST='$VIRTUAL_HOST_NAME'"
      - "LETSENCRYPT_EMAIL='$LETSENCRYPT_EMAIL'"

  nginx:
    image: nginx
    labels:
      com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy: "true"
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/vhost.d:/etc/nginx/vhost.d
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/certs:/etc/nginx/certs:ro

  nginx-gen:
    image: jwilder/docker-gen
    command: -notify-sighup nginx -watch -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
    container_name: nginx-gen
    restart: unless-stopped
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/vhost.d:/etc/nginx/vhost.d
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/certs:/etc/nginx/certs:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro

  nginx-letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: nginx-letsencrypt
    restart: unless-stopped
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/vhost.d:/etc/nginx/vhost.d
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/certs:/etc/nginx/certs:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      NGINX_DOCKER_GEN_CONTAINER: "nginx-gen"
      NGINX_PROXY_CONTAINER: "nginx"' > docker-compose.yml


# ============================ Nginx Config ============================
mkdir -p nginx/vhost.d/
echo 'proxy_redirect off;
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $http_host;
if ($http_upgrade = "websocket" ) {
    proxy_pass http://v2ray:'$VMESS_PORT';
}' > nginx/vhost.d/'$VIRTUAL_HOST_NAME'_location