#!/usr/bin/env bash
# Rebuilds the warranty_engine database. Usage: ./build_all.sh
set -e
cd "$(dirname "$0")"
mysql -u "${MYSQL_USER:-root}" -p -t < build_all.sql
