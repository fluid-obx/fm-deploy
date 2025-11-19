FROM jrei/systemd-ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

###############################################################################
# 1. Ensure UID/GID 1000 is free; create fmserver:fmsadmin
###############################################################################
RUN set -eux; \
    if getent passwd 1000 >/dev/null 2>&1; then \
        uname="$(getent passwd 1000 | cut -d: -f1)"; \
        userdel -r "$uname" || true; \
    fi; \
    if getent group 1000 >/dev/null 2>&1; then \
        gname="$(getent group 1000 | cut -d: -f1)"; \
        groupdel "$gname" || true; \
    fi; \
    groupadd -g 1000 fmsadmin; \
    useradd -u 1000 -g fmsadmin -m -s /bin/bash fmserver

###############################################################################
# 2. Pre-seed Microsoft Core Fonts EULA
###############################################################################
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" \
    | debconf-set-selections

###############################################################################
# 3. Install dependencies
###############################################################################
RUN set -eux; \
    apt update; \
    apt install -y --no-install-recommends \
        apt-utils \
        debconf-utils \
        ca-certificates \
        curl \
        wget \
        nano \
        sudo \
        gnupg \
        iputils-ping \
        dnsutils \
        unzip \
        zip \
        expect \
        net-tools \
        logrotate \
        lsb-release \
        openssl \
        policycoreutils \
        ufw \
        sysstat \
        acl \
        apache2-bin \
        apache2-utils \
        fonts-baekmuk \
        fonts-liberation2 \
        fonts-noto \
        fonts-takao \
        fonts-wqy-zenhei \
        ttf-mscorefonts-installer \
        init \
        unixodbc \
        unixodbc-dev \
        odbcinst \
        odbc-mariadb; \
    apt autoremove -y; \
    apt clean; \
    rm -rf /var/lib/apt/lists/*

###############################################################################
# 4. Install NGINX (latest from nginx.org)
###############################################################################
RUN set -eux; \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | \
        gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu noble nginx" \
        > /etc/apt/sources.list.d/nginx.list; \
    apt update; \
    apt install -y --no-install-recommends nginx; \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80 443 2399 5003

USER root