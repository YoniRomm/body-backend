FROM openresty/openresty:1.25.3.1-0-alpine AS base

# Install Go
RUN apk add --no-cache go

WORKDIR /app

# Copy source
COPY . .

# Build Go app
RUN go build -o go-server main.go

# Copy config files
COPY lua-backend/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua-backend/handler.lua /usr/local/openresty/nginx/html/handler.lua

# Start both servers
CMD ["/bin/sh", "-c", "/usr/local/bin/openresty -g 'daemon off;' & /app/go-server"]
