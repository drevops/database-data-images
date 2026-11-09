##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
FROM uselagoon/mysql-8.4:26.11.0@sha256:4428eca08694c0b08566c4145ff0baf0c546b8294d7b1b990254a428c9fb0d03

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
