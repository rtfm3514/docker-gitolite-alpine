#!/bin/sh

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

set -e
#set -x

# Set missing environment defaults
if [ -z "${GITOLITE_ALPINE_RUNFILE}" ] ; then
    export GITOLITE_ALPINE_RUNFILE="${GITOLITE_ALPINE_HOMEDIR}/run/sshd.pid"
fi

if [ -z "${GITOLITE_ALPINE_GITCONFIG}" ] ; then
    export GITOLITE_ALPINE_GITCONFIG="${GITOLITE_ALPINE_HOMEDIR}/.gitconfig"
fi

if [ -z "${GITOLITE_ALPINE_GITOLITERC}" ] ; then
    export GITOLITE_ALPINE_GITOLITERC="${GITOLITE_ALPINE_HOMEDIR}/.gitolite.rc"
fi

if [ -z "${GITOLITE_ALPINE_SSHDCONFIG}" ] ; then
    export GITOLITE_ALPINE_SSHDCONFIG="${GITOLITE_ALPINE_HOMEDIR}/sshd_config"
fi

if [ -z "${GITOLITE_ALPINE_ADMINKEY}" ] ; then
    export GITOLITE_ALPINE_ADMINKEY="${GITOLITE_ALPINE_HOMEDIR}/admin"
fi

if [ -z "${GITOLITE_ALPINE_HOSTKEY}" ] ; then
    export GITOLITE_ALPINE_HOSTKEY="${GITOLITE_ALPINE_HOMEDIR}/ssh_host_key_ed25519_gitolite"
fi

if [ -z "${GITOLITE_ALPINE_LOGFILE}" ] ; then
    export GITOLITE_ALPINE_LOGFILE="${GITOLITE_ALPINE_HOMEDIR}/.gitolite/logs/gitolite.log"
fi

# Trap CTRL+c and call ctrl_c()
# TODO: Does not work here, sshd is PID 1 (because of exec) and does not honor CTRL+c
trap ctrl_c INT

ctrl_c() {
    kill -SIGTERM "$(cat "${GITOLITE_ALPINE_RUNFILE}")"
}

## Container Setup
if [ "$1" = 'sshd' ] ; then
    shift

    echo
    echo 'INFO: Starting container initialization...'

    echo
    echo 'INFO: Container running under:'
    id

    if ! [ -e "$(dirname "${GITOLITE_ALPINE_RUNFILE}")" ] ; then
        echo 'INFO: No run directory found. Creating...'
        mkdir "$(dirname "${GITOLITE_ALPINE_RUNFILE}")"
    fi

    if ! [ -f "${GITOLITE_ALPINE_GITCONFIG}" ] ; then
        echo 'INFO: No Git config found. Copying default Git config...'
        cp /ci/gitconfig "${GITOLITE_ALPINE_GITCONFIG}"
    else
        echo 'INFO: Existing Git config found.'
    fi

    if ! [ -f "${GITOLITE_ALPINE_GITOLITERC}" ] ; then
        echo 'INFO: No Gitolite config found. Copying default Gitolite config...'
        cp /ci/gitolite.rc "${GITOLITE_ALPINE_GITOLITERC}"
    else
       echo 'INFO: Existing Gitolite config found.'
    fi

    if ! [ -f "${GITOLITE_ALPINE_SSHDCONFIG}" ] ; then
        echo 'INFO: No SSH daemon config found. Copying default SSH daemon config...'
        cp /ci/sshd_config "${GITOLITE_ALPINE_SSHDCONFIG}"
    else
       echo 'INFO: No Git config found. Copying default Git config...'
    fi

    if ! [ -d "${GITOLITE_ALPINE_HOMEDIR}/repositories" ] ; then
    echo 'INFO: No repos found. Assuming fresh install...'

        if [ -f "${GITOLITE_ALPINE_ADMINKEY}.pub" ] ; then
            echo 'INFO: Existing Gitolite admin key found.'
        else
            echo 'INFO: No admin key found! Generating a new one...'
            ssh-keygen -q -t ed25519 -f "${GITOLITE_ALPINE_ADMINKEY}" -C 'gitolite-admin' -N ''
            echo
            echo "WARNING: You should really move the private key \"${GITOLITE_ALPINE_ADMINKEY}\""
            echo "         (and possibly the public key \"${GITOLITE_ALPINE_ADMINKEY}.pub\" as well)"
            echo '         somewhere safe and secure the key with a **strong**'
            echo '         passphrase:'
            echo "         ssh-keygen -p -f \"${GITOLITE_ALPINE_ADMINKEY}\""
            echo '         (Adjust path if executed from docker host system!)'
            echo
            echo '         Consider yourself warned...'
            echo
        fi

        echo 'INFO: Setting up Gitolite...'
        if [ -e "${GITOLITE_ALPINE_GITCONFIG}" ] ; then
            mv "${GITOLITE_ALPINE_GITCONFIG}" "${GITOLITE_ALPINE_GITCONFIG}.bak"
            cp ci/gitconfig.init "${GITOLITE_ALPINE_GITCONFIG}"
        fi

        if ! gitolite setup -pk "${GITOLITE_ALPINE_ADMINKEY}.pub" -m 'Initial Commit' ; then
            echo 'ERROR: Failed to initialize Gitolite installation!'
            exit 1
        fi

        if [ -e "${GITOLITE_ALPINE_GITCONFIG}.bak" ] ; then
            mv "${GITOLITE_ALPINE_GITCONFIG}.bak" "${GITOLITE_ALPINE_GITCONFIG}"
        fi

        ## Link the Gitolite log file to stdout of PID 1 (sshd daemon)
        ln -sf /proc/1/fd/1 "${GITOLITE_ALPINE_LOGFILE}"

    else
        echo 'INFO: Repos found. Assuming already initialized installation.'
    fi

    echo

    if ! [ -f "${GITOLITE_ALPINE_HOSTKEY}" ] ; then
        echo 'INFO: No SSH host key found! Generating a new one...'
        ssh-keygen -q -t ed25519 -f "${GITOLITE_ALPINE_HOSTKEY}" -N ''
    else
        echo 'INFO: Existing host keys found.'
    fi
    echo 'INFO: Container initialization done.'

    echo

    echo 'INFO: Starting /usr/sbin/sshd ...'
    exec /usr/sbin/sshd "$@" "${GITOLITE_ALPINE_SSHDCONFIG}" "-o" "Port=${GITOLITE_ALPINE_PORT}" "-o" "PidFile=${GITOLITE_ALPINE_RUNFILE}" "-h" "${GITOLITE_ALPINE_HOSTKEY}" "-o" "LogLevel=${GITOLITE_ALPINE_LOGLEVEL}"
fi

exec "$@"
