##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
FROM uselagoon/mysql-8.4:26.11.2@sha256:cc25b3fb886182e4ab8fc697ff0389c3aecc68260a997e91fd208e41aa885287

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
