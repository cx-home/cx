# Minimal cxstore service image. Build `cx` from the repo and copy the static
# binary in; mount the config at /etc/cxstore/cxstore.service.cx.
FROM debian:stable-slim
COPY cx /usr/local/bin/cx
COPY cxstore.service.cx /etc/cxstore/cxstore.service.cx
EXPOSE 8443
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD cx store-health --url http://127.0.0.1:8443/cx-store/v1/ready || exit 1
ENTRYPOINT ["cx", "store-serve", "--config", "/etc/cxstore/cxstore.service.cx", "--allow-net"]
