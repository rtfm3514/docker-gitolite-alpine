# Minimal Docker container for running Gitolite using an Alpine Linux image

This Git repo contains the Dockerfile and support files to create a container image based on Alpine Linux running a minimal Git server using Gitolite.

The container tries to run with as few privileges as possible and intentionally does not provide shell access via the included SSH server.

For better version coherancy Gitolite is installed from the Alpine Linux repos rather than from upstream Git sources.

The authoritive version of this repository currently resides on Github:

[https://github.com/rtfm3514/docker-gitolite-alpine](https://github.com/rtfm3514/docker-gitolite-alpine)

## Quick Setup

- Build the Docker image from the repository root, passing the name of a docker network providing Internet connectivity while building. If unsure, the default network named "bridge" should work:

~~~
# docker build --no-cache --network [NAME_OF_INTERNET_CONNECTED_NETWORK] --tag alpine/gitolite:latest -f gitolite-alpine/Dockerfile .

[...]

Step 15/17 : RUN echo "Setup volume for git user home dir with this (mapped) ID:" && id
 ---> Running in [...]
Setup volume for git user home dir with this (mapped) ID:
uid=100(git) gid=101(git) groups=101(git)

[...]

Successfully built [...]
Successfully tagged alpine/gitolite:latest
~~~

- Setup a persistent volume for the home directory of container Git user:
  - The above build process outputs the UID and GID of the container Git user, e.g. UID=100, GID=101.
  - If you are applying Docker Best Practice, in particular "user remapping" of container IDs (like I am), you have to determine the offset used for the Docker remapping user and group:

~~~
# grep 'userns-remap' /etc/docker/daemon.json
"userns-remap": "dockremap"
# grep 'dockremap' /etc/subuid | cut -f 2 -d ':'
100000
# grep 'dockremap' /etc/subgid | cut -f 2 -d ':'
100000
~~~

  - Create a home directory on the Docker host (e.g. `/srv/gitolite`) with suitable UID and GID, replacing the IDs from Docker (i.e. 100000) and the build process (i.e. 100 for UID and 101 for GID):

~~~
# mkdir /srv/gitolite
# chown -c $((100000+100)):$((100000+101)) /srv/gitolite
changed ownership of '/srv/gitolite' from root:root to 100100:100101
~~~

- Finally, run the container and replace
- `--name gitolite` with your desired container name.
- `--hostname gitolite` with your desired hostname of the Gitolite server.
- `--network` with your desired docker network.
- `--publish XXXXX:` with your desired external facing high port (i.e. above 1023, refer to the "Security" section for an explanation).

~~~
# docker run -d --env 'GITOLITE_ALPINE_LOGLEVEL=DEBUG' --name gitolite --publish 22222:2222 --network [DOCKER_NETWORK_NAME] --hostname gitolite -v /srv/gitolite:/var/lib/git alpine/gitolite:latest
# docker container logs -f gitolite

INFO: Starting container initialization...

INFO: Container running under:
uid=100(git) gid=101(git) groups=101(git)
INFO: No run directory found. Creating...
INFO: No Git config found. Copying default Git config...
INFO: No Gitolite config found. Copying default Gitolite config...
INFO: No SSH daemon config found. Copying default SSH daemon config...
INFO: No repos found. Assuming fresh install...
INFO: No admin key found! Generating a new one...

WARNING: You should really move the private key "/var/lib/git/admin"
         (and possibly the public key "/var/lib/git/admin.pub" as well)
         somewhere safe and secure the key with a **strong**
         passphrase:
         ssh-keygen -p -f "/var/lib/git/admin"
         (Adjust path if executed from docker host system!)

         Consider yourself warned...

INFO: Setting up Gitolite...
Initialized empty Git repository in /var/lib/git/repositories/gitolite-admin.git/
Initialized empty Git repository in /var/lib/git/repositories/testing.git/
WARNING: /var/lib/git/.ssh missing; creating a new one
    (this is normal on a brand new install)
WARNING: /var/lib/git/.ssh/authorized_keys missing; creating a new one
    (this is normal on a brand new install)

INFO: No SSH host key found! Generating a new one...
INFO: Container initialization done.

INFO: Starting /usr/sbin/sshd ...
debug1: sshd version OpenSSH_9.3, OpenSSL 3.1.1 30 May 2023
debug1: private host key #0: ssh-ed25519 SHA256:[...]
debug1: setgroups() failed: Operation not permitted
debug1: rexec_argv[0]='/usr/sbin/sshd'
debug1: rexec_argv[1]='-4Def'
debug1: rexec_argv[2]='/var/lib/git/sshd_config'
debug1: rexec_argv[3]='-o'
debug1: rexec_argv[4]='Port=2222'
debug1: rexec_argv[5]='-o'
debug1: rexec_argv[6]='PidFile=/var/lib/git/run/sshd.pid'
debug1: rexec_argv[7]='-h'
debug1: rexec_argv[8]='/var/lib/git/ssh_host_key_ed25519_gitolite'
debug1: rexec_argv[9]='-o'
debug1: rexec_argv[10]='LogLevel=DEBUG'
debug1: Set /proc/self/oom_score_adj from 0 to -1000
debug1: Bind to port 2222 on 0.0.0.0.
Server listening on 0.0.0.0 port 2222.
~~~

- Test connectivity to the Gitolite server, but do not remember the host key. Using the example docker command above, the internal SSH port 2222/tcp is mapped to 22222/tcp, depending on where your Gitolite server is running you might need to replace `localhost` with your servers DNS name or IP address:

~~~
# ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /srv/gitolite/admin -p 22222 git@localhost
hello admin, this is git@gitolite running gitolite3 3.6.12 on git 2.40.1

 R W    gitolite-admin
 R W    testing
~~~

- To wrap it up, you should either:
  - Move the auto-generated Gitolite admin key (`/srv/gitolite/admin`) to a secure location, apply a **strong** passphrase and setup a proper Git config for access to the gitolite-admin repo.
  - Alternatively, refer to the "Detailed Setup" section to fine tune your initial setup, and in particular consider bootstrapping the container with a pre-generated admin key of your choice before you run the container for the first time.

- Afterwards continue from the Gitolite documentation.

## Detailed Setup

If the above container is run on top of a blank container volume for the first time, the setup is auto-generating a couple of files and deploys them to the persistent volume for future use:

- An SSH key pair for the Gitolite admin access: `admin` and `admin.pub`
- An SSH key pair as SSH host key: `ssh_host_key_ed25519_gitolite` and `ssh_host_key_ed25519_gitolite.pub`

If these files are provided via the volume before the container is started, no new files are generated. For the admin access, only the public key needs to be provided.

Likewise some configuration files are copied form the Git repo into the container at build time under `ci/`. During the initial container run these files are used as default versions and deployed to the persistent volume as needed. Subsequent runs will not redeploy these files if they already exist and therefore the files may be modified after the first run. Similarily, if these files are provided via the volume before the first run, the default versions from `ci/` are not used at all.

**Take special note of the following defaults, in case they don't work for you and you need to change them:**

- A rather dirty hack makes sure that during Gitolite initialization the two default repos `gitolite-admin` and `testing` are created with the default branch set to `master` (refer to `ci/gitconfig.init`), without it Gitolite does not work properly. However, the default branch of any other new repositories will be called `main` not `master`, in accordance with recent Git changes to the upstream defaults. (Refer to `ci/gitconfig`)
- Repository auto-creation is disabled both on pull/fetch or push. Repositories need to be specifically created using admin access. (Refer to `ci/gitolite.rc`)
- Gitolite is logging to its own files, logging to stdout (and Docker by extension) requires a change in `ci/gitolite.rc`. Refer to the comments in that file if you want that. Note: On "high volume servers" (silence!) you might need to take additional precautions so these logs don't fill up your disk space. Afaik, Gitolite doesn't provide log rotation or similar mechanisms on its own.

This is the layout of an initially empty container volume after the first run:

~~~
# ls -la /srv/gitolite
total 56
drwxr-xr-x 6 100100 100101 [...] .
drwxr-xr-x 6 root   root   [...] ..
-rw------- 1 100100 100101 [...] admin
-rw-r--r-- 1 100100 100101 [...] admin.pub
-r--r--r-- 1 100100 100101 [...] .gitconfig
drwx------ 6 100100 100101 [...] .gitolite
-r--r--r-- 1 100100 100101 [...] .gitolite.rc
drwx------ 4 100100 100101 [...] repositories
drwxr-xr-x 2 100100 100101 [...] run
drwx------ 2 100100 100101 [...] .ssh
-r--r--r-- 1 100100 100101 [...] sshd_config
-rw------- 1 100100 100101 [...] ssh_host_key_ed25519_gitolite
-rw-r--r-- 1 100100 100101 [...] ssh_host_key_ed25519_gitolite.pub
~~~

## Customized Setup

Several of the internal defaults can be overridden using Docker build args (at container build time) and/or environmental variables (at container run time):

Available build args (environment variables equivalents are using upper case):

- gitolite_alpine_homedir/GITOLITE_ALPINE_HOMEDIR: Home directory of the `git` task user inside the container. This directory path is used as base path for various other file paths (defaults to `/var/lib/git`)
- gitolite_alpine_port/GITOLITE_ALPINE_PORT: Internal SSH server port used by the container (defaults to `2222`)
- gitolite_alpine_loglevel/GITOLITE_ALPINE_LOGLEVEL: LogLevel setting used by the SSH server (defaults to `INFO`)

Additional environment variables (without build arg equivalents):

- GITOLITE_ALPINE_RUNFILE: Full file path to the sshd PID file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/run/sshd.pid`)
- GITOLITE_ALPINE_GITCONFIG: Full file path to the Git config file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/.gitconfig`)
- GITOLITE_ALPINE_GITOLITERC: Full file path to the Gitolite config file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/.gitolite.rc`)
- GITOLITE_ALPINE_SSHDCONFIG: Full file path to the SSH daemon config file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/sshd_config`)
- GITOLITE_ALPINE_ADMINKEY: Full file path to the Gitolite admin file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/admin`)
- GITOLITE_ALPINE_HOSTKEY: Full file path to the SSH host key file (defaults to `${GITOLITE_ALPINE_HOMEDIR}/ssh_host_key_ed25519_gitolite`)
- GITOLITE_ALPINE_LOGFILE: Full file path to the single Gitolite log file, only used with additional changes to .gitolite.rc (defaults to `${GITOLITE_ALPINE_HOMEDIR}/.gitolite/logs/gitolite.log`)

# Security Considerations

The container entrypoint and setup is running as the task user `git`. The sshd daemon is likewise run by the user `git`. This is also the reason the internal default SSH port is 2222/tcp, rather than the standard 22/tcp, because opening 22/tcp would require root privileges. Should the **internal** port 2222/tcp be unavailable, and port mapping at container run time doesn't work for you for some reason, you may change the internal port **at container image build time** e.g. to 2022 using `--build-arg gitolite_alpine_port=2022` or at **container run time** using `--env GITOLITE_ALPINE_PORT=2022`. For a different external facing **runtime port**, adjust the port mapping using `--publish` in the docker-run command.

# License

Copyright (C) 2023 Björn Wiedenmann

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

# Credits

This project took some inspiration from existing Gitolite docker images, however, since I started this more than a year ago (and with poor initial documentation on my part) I cannot remember exactly which examples I looked at. As far as I can remember, some of them were

- https://github.com/jgiannuzzi/docker-gitolite (for the use of Alpine Linux)
- https://github.com/miracle2k/docker-gitolite (for the use of a non-root container)

If you feel your work was not properly credited, please forgive me and get in touch with me. I will rectify that oversight asap.

# Contact Information

The author may be contacted via Github : [https://github.com/rtfm3514/docker-gitolite-alpine](https://github.com/rtfm3514/docker-gitolite-alpine)
