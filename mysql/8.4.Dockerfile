##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
FROM uselagoon/mysql-8.4:26.11.1@sha256:03c40797d5a67f87ce56dba6e85d7f062d359b6d0a5e6da1147cdf3deb443a35

ENV MYSQL_DATA_DIR=/home/db-data \
    MYSQL_DATABASE=drupal \
    MYSQL_USER=drupal \
    MYSQL_PASSWORD=drupal

COPY disable-binlog.cnf /etc/mysql/conf.d/disable-binlog.cnf

USER root

RUN mkdir -p /home/db-data \
    && chown -R mysql:mysql /home/db-data \
    && /bin/fix-permissions /home/db-data \
    && /bin/fix-permissions /etc/mysql/conf.d

USER mysql
