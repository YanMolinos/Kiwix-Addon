ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install kiwix-serve from Alpine repositories matching the base image branch.
RUN set -eux; \
    ALPINE_BRANCH="$(cut -d. -f1,2 /etc/alpine-release)"; \
    COMMUNITY_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_BRANCH}/community"; \
    grep -q "${COMMUNITY_REPO}" /etc/apk/repositories || echo "${COMMUNITY_REPO}" >> /etc/apk/repositories; \
    apk add --no-cache kiwix-tools nginx

# Add-on launcher / Inicializador do add-on
COPY --chmod=755 run.sh /run.sh
COPY zims/ /opt/kiwix/zims/

CMD ["/run.sh"]
