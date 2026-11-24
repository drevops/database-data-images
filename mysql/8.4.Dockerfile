##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
FROM uselagoon/mysql-8.4:26.11.6@sha256:e4bced6a0278cf063d283b60740e7bf6c33e8eec1161ac4088ceeeb8b5466f68

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
