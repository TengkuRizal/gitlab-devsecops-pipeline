FROM nginxinc/nginx-unprivileged:1.28-alpine
USER root
RUN apk update \
    && apk upgrade --no-cache libcrypto3 libssl3 \
    && rm -rf /var/cache/apk/*
USER 101
