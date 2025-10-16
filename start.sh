#!/bin/sh
openresty -g 'daemon off;' &
/usr/local/bin/go-server &
wait -n
