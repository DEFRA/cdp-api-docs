FROM nginxinc/nginx-unprivileged:1.29.8-alpine3.23

ENV TZ="Europe/London"

# curl for the CDP platform healthcheck, aws-cli for the S3 sync.
USER root
RUN apk add --no-cache aws-cli curl \
 && mkdir -p /srv \
 && chown nginx:nginx /srv

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY scripts/log.sh /usr/local/lib/cdp-api-docs/log.sh
COPY --chmod=755 scripts/entrypoint.sh scripts/sync.sh /usr/local/bin/

USER nginx

ENV PORT=8085
ENV SYNC_ENABLED=true
ENV SYNC_INTERVAL_SECONDS=60
EXPOSE ${PORT}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
