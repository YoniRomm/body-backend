FROM alpine:latest
RUN apk add --no-cache openresty go

COPY lua-backend/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua-backend/handler.lua /usr/local/openresty/nginx/html/handler.lua
COPY go-server /usr/local/bin/go-server

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
