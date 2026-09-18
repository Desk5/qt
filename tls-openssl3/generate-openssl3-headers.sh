#!/bin/bash
#
# Generate a set of OpenSSL 3.x headers to compile the TLS plugin in this directory
# against.
#
# Only headers are needed: Qt dlopens libssl/libcrypto at runtime and never links
# them, so nothing here has to match the build host's OpenSSL, its libc or its
# compiler. 'make build_generated' produces just the headers generated from the
# *.h.in templates (configuration.h, opensslv.h, ...) and compiles no objects, which
# is why this works inside an old container whose gcc could not build OpenSSL 3.x.
#
# Usage: generate-openssl3-headers.sh [dest-prefix]        (default: /opt/openssl3)
#        OPENSSL_VER=3.0.15 generate-openssl3-headers.sh   (to pin another version)
#
# Headers end up in <dest-prefix>/include/openssl, i.e. pass <dest-prefix>/include as
# QT_OPENSSL3_INCLUDE_DIR.

set -eux

OPENSSL_VER="${OPENSSL_VER:-3.0.15}"
DEST="${1:-/opt/openssl3}"

case "${OPENSSL_VER}" in
    3.*) ;;
    *) echo "OPENSSL_VER must be a 3.x version, got ${OPENSSL_VER}" >&2; exit 1 ;;
esac

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

cd "${WORK_DIR}"
curl -fsSLO "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VER}/openssl-${OPENSSL_VER}.tar.gz"
tar xf "openssl-${OPENSSL_VER}.tar.gz"
cd "openssl-${OPENSSL_VER}"

./Configure linux-x86_64 no-shared no-tests
make -j"$(nproc)" build_generated

mkdir -p "${DEST}/include"
# Picks up both the shipped headers and the ones just generated next to them.
cp -a include/openssl "${DEST}/include/"

# Fail here, rather than silently producing a second copy of the 1.1 plugin, if the
# tarball layout ever changes.
test -f "${DEST}/include/openssl/ssl.h"
test -f "${DEST}/include/openssl/configuration.h"
grep -q 'OPENSSL_VERSION_MAJOR[[:space:]]*3' "${DEST}/include/openssl/opensslv.h"

echo "OpenSSL ${OPENSSL_VER} headers written to ${DEST}/include"
