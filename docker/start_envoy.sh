#!/bin/sh

mkdir -p /etc/ssl

ENV SERVICE_NAME
hostname="$SERVICE_NAME.local"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/envoy.key -out /etc/ssl/envoy.crt -subj "/CN=$hostname"

/usr/local/bin/envoy -c /etc/envoy.yaml
