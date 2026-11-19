##
# Database data captured inside of the container.
#
# The upstream image declares the data directory as a VOLUME, which Docker
# does not export, so a different data directory is used.
#
# The upstream entrypoint is replaced by a modified copy; entrypoint.bash
# marks each local change with '@note:'. The default CMD is also overridden
# to include the custom data directory.
#
FROM uselagoon/mariadb-10.11-drupal:26.11.4@sha256:7d136b704137dca8ca4e2134a819ae4bd16c0dd610df9a19fc8c53539872256b

ENV MARIADB_DATA_DIR=/home/db-data

COPY entrypoint.bash /lagoon/entrypoints/9999-mariadb-init.bash

USER root

RUN mkdir -p /home/db-data \
    && chown -R mysql:mysql /home/db-data \
    && /bin/fix-permissions /home/db-data

USER mysql

# @todo Try removing the CMD override.
CMD ["mysqld", "--datadir=/home/db-data"]
