#[1] Use Debian 11 base image for ARM64v8
FROM arm64v8/debian:11
ARG DEBIAN_NAME=bullseye
ARG DEBIAN_FRONTEND=noninteractive

# Package versions
ARG NODEJS_VERSION=16
ARG PG_VERSION=14

ARG DEBS_PATH=tmp/dpkg

#[2] Install default packages from the web
RUN apt-get update \
    && apt-get -y --no-install-recommends install \
        apt \
        apt-utils \
        apt-transport-https \
        curl \
        dpkg \
        mount \
        psmisc \
        lsb-release \
        sudo \
        gnupg \
        ca-certificates \
        dirmngr \
        mdadm \
        iproute2 \
        ethtool \
        procps \
        systemd-timesyncd \
        vim-tiny \
        zstd \
        xz-utils \
        openssh-server \
    && rm -rf /var/lib/apt/lists/*

#[3] Install NodeJS on debian (https://github.com/nodesource/distributions#debinstall)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

#[4] Install systemd, followed by removing some files
RUN apt-get update \
    && apt-get -y --no-install-recommends install systemd \
    && find /etc/systemd/system \
        /lib/systemd/system \
        -path '*.wants/*' \
        -not -name '*journald*' \
        -not -name '*systemd-tmpfiles*' \
        -not -name '*systemd-user-sessions*' \
        -exec rm \{} \; \
    && rm -rf /var/lib/apt/lists/*
STOPSIGNAL SIGKILL

#[5] Installing postgress
RUN curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${DEBIAN_NAME}-pgdg main" > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update \
    && apt-get -y --no-install-recommends install postgresql-${PG_VERSION} \
    && rm -rf /var/lib/apt/lists/*

#[6]
COPY source/${DEBS_PATH}/*.deb /${DEBS_PATH}/
#[7]
COPY source/lib /lib/

#[8] Adding ubnt repository
RUN apt-get -y --no-install-recommends install /${DEBS_PATH}/ubnt-archive-keyring_*_arm64.deb \
    && echo 'deb https://apt.artifacts.ui.com bullseye main release beta' > /etc/apt/sources.list.d/ubiquiti.list \
    && chmod 666 /etc/apt/sources.list.d/ubiquiti.list \
    && apt-get update 

#[9]     
RUN apt-get -y --no-install-recommends install /${DEBS_PATH}/*.deb unifi-protect 
    #&& rm -f /${DEBS_PATH}/*.deb \
    #&& rm -rf /var/lib/apt/lists/* 

#[10]
RUN echo "exit 0" > /usr/sbin/policy-rc.d \
    && sed -i 's/redirectHostname: unifi//' /usr/share/unifi-core/app/config/config.yaml \
    && mv /sbin/mdadm /sbin/mdadm.orig \
    && mv /sbin/ubnt-tools /sbin/ubnt-tools.orig \
    && mv /usr/sbin/smartctl /usr/sbin/smartctl.orig \
    && systemctl enable storage_disk dbpermissions \
    && pg_dropcluster --stop 9.6 main \
    && sed -i 's/rm -f/rm -rf/' /sbin/pg-cluster-upgrade \
    && sed -i 's/OLD_DB_CONFDIR=.*/OLD_DB_CONFDIR=\/etc\/postgresql\/9.6\/main/' /sbin/pg-cluster-upgrade

#[11]
COPY source/sbin /sbin/
#[12]
COPY source/usr /usr/

VOLUME ["/srv", "/data", "/persistent"]

CMD ["/lib/systemd/systemd"]
