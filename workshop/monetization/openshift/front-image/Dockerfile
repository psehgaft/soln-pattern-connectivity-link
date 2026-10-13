ARG FRONT_BASE_IMAGE=getlago/front:v1.41.0
FROM ${FRONT_BASE_IMAGE}

# The upstream image assumes a root container and privileged port 80. OpenShift
# restricted-v2 runs an assigned non-root UID, so prepare writable paths and use
# an unprivileged listener. The runtime SCC still assigns the actual UID.
USER 0
RUN chmod 0777 /usr/share/nginx/html \
 && mkdir -p /var/cache/nginx/client_temp \
               /var/cache/nginx/proxy_temp \
               /var/cache/nginx/fastcgi_temp \
               /var/cache/nginx/uwsgi_temp \
               /var/cache/nginx/scgi_temp \
 && chmod -R 0777 /var/cache/nginx \
 && find /etc/nginx -type f -name '*.conf' -exec sed -i -E \
      -e 's#/run/nginx\.pid#/tmp/nginx.pid#g' \
      -e 's/listen[[:space:]]+80([;[:space:]])/listen 8080\1/g' \
      -e 's/listen[[:space:]]+\[::\]:80([;[:space:]])/listen [::]:8080\1/g' {} \;
