##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
FROM uselagoon/mysql-8.4:26.11.3@sha256:6be67199b7a60c309dd44e5f0f9015ef3e68accfbf99f31f579745fb49d68c84

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
