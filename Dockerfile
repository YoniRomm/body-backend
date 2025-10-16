# Base image: OpenResty (NGINX + Lua)
FROM openresty/openresty:1.25.3.1-0-alpine

# Set working directory
WORKDIR /usr/local/openresty/nginx/html

# Copy Lua handler and NGINX config
COPY handler.lua /usr/local/openresty/nginx/html/handler.lua
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Expose port
EXPOSE 8080

# Start OpenResty (NGINX + Lua)
CMD ["openresty", "-g", "daemon off;"]
