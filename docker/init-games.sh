#!/usr/bin/env bash
# Runs once, on the container's first start, from /docker-entrypoint-initdb.d (the repo is mounted at /games).
# The entrypoint sources this file, so run install.sh in a child process to keep its `set -e` to itself.
bash /games/install.sh all
