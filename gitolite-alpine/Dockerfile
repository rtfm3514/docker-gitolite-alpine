# Minimal Docker container for running Gitolite using an Alpine Linux image
#
# https://github.com/rtfm3514/docker-gitolite-alpine
#
# Copyright (C) 2023 Björn Wiedenmann
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

FROM alpine:latest
ARG gitolite_alpine_homedir='/var/lib/git'
ENV GITOLITE_ALPINE_HOMEDIR="${gitolite_alpine_homedir}"
ARG gitolite_alpine_port='2222'
ENV GITOLITE_ALPINE_PORT="${gitolite_alpine_port}"
ARG gitolite_alpine_loglevel='INFO'
ENV GITOLITE_ALPINE_LOGLEVEL="${gitolite_alpine_loglevel}"
RUN apk update && apk add openssh-server openssh-keygen git gitolite
RUN mkdir /ci
COPY ci/sshd_config ci/gitconfig ci/gitconfig.init ci/gitolite.rc /ci/
COPY ci/docker-entrypoint.sh /
RUN chmod 0444 /ci/* && chmod 0755 /docker-entrypoint.sh
EXPOSE "${gitolite_alpine_port}"
USER git
RUN echo "Setup volume for git user home dir with this (mapped) ID:" && id
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["sshd", "-4Def"]
