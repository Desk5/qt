# A second copy of Qt's OpenSSL TLS backend plugin, compiled against OpenSSL 3.x
# headers.
#
# The Linux release is built in an old container whose only libssl-dev is 1.1.1, so
# the in-tree plugin hardcodes the OpenSSL 1.x code paths and refuses a 3.x runtime.
# Qt's dlopen-based binding only spans patch releases within one OpenSSL major
# version, so one binary cannot serve both. Building the very same sources a second
# time against 3.x headers gives us a plugin that handles modern systems, while the
# in-tree one keeps handling old ones. Whichever plugin cannot use the OpenSSL found
# at runtime reports itself as invalid, and QTlsBackend::defaultBackendName() picks
# the other one.
#
# Configure against an already-installed Qt from this same build, e.g.
#   cmake -S tls-openssl3 -B build-tls-openssl3 -G Ninja \
#         -DCMAKE_BUILD_TYPE=Release \
#         -DCMAKE_PREFIX_PATH=<qt-prefix> -DCMAKE_INSTALL_PREFIX=<qt-prefix> \
#         -DQT_OPENSSL3_INCLUDE_DIR=/opt/openssl3/include

cmake_minimum_required(VERSION 3.16)
project(qopenssl3backend LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Network)

set(QT_OPENSSL3_INCLUDE_DIR "" CACHE PATH
    "Directory holding the OpenSSL 3.x headers to compile against (the one containing openssl/).")

if(NOT QT_OPENSSL3_INCLUDE_DIR)
    message(FATAL_ERROR "QT_OPENSSL3_INCLUDE_DIR must be set.")
endif()
if(NOT EXISTS "${QT_OPENSSL3_INCLUDE_DIR}/openssl/ssl.h")
    message(FATAL_ERROR "No openssl/ssl.h under QT_OPENSSL3_INCLUDE_DIR "
                        "(${QT_OPENSSL3_INCLUDE_DIR}).")
endif()
if(NOT EXISTS "${QT_OPENSSL3_INCLUDE_DIR}/openssl/configuration.h")
    # openssl/configuration.h only exists from OpenSSL 3.0 onwards. Without this check
    # a stale path would silently produce a second copy of the 1.1 plugin.
    message(FATAL_ERROR "QT_OPENSSL3_INCLUDE_DIR (${QT_OPENSSL3_INCLUDE_DIR}) does not hold "
                        "OpenSSL 3.x headers.")
endif()

set(TLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../qtbase/src/plugins/tls")
if(NOT EXISTS "${TLS_DIR}/openssl/qtlsbackend_openssl.cpp")
    message(FATAL_ERROR "Cannot find the in-tree TLS plugin sources at ${TLS_DIR}. "
                        "Is the qtbase submodule checked out?")
endif()

qt_add_plugin(QTlsBackendOpenSSL3Plugin
    MANUAL_FINALIZATION
    CLASS_NAME QTlsBackendOpenSSL3
    PLUGIN_TYPE tls
)

# The in-tree source list (src/plugins/tls/openssl/CMakeLists.txt) minus the dtls,
# APPLE, ANDROID and WIN32 conditionals: this plugin is Linux-only by construction.
# Headers are listed so that AUTOMOC is guaranteed to see the Q_OBJECT in
# qtlsbackend_openssl_p.h.
target_sources(QTlsBackendOpenSSL3Plugin PRIVATE
    "${TLS_DIR}/shared/qx509_base.cpp" "${TLS_DIR}/shared/qx509_base_p.h"
    "${TLS_DIR}/shared/qtlskey_base.cpp" "${TLS_DIR}/shared/qtlskey_base_p.h"
    "${TLS_DIR}/shared/qasn1element.cpp" "${TLS_DIR}/shared/qasn1element_p.h"
    "${TLS_DIR}/openssl/qtlsbackend_openssl.cpp" "${TLS_DIR}/openssl/qtlsbackend_openssl_p.h"
    "${TLS_DIR}/openssl/qx509_openssl.cpp" "${TLS_DIR}/openssl/qx509_openssl_p.h"
    "${TLS_DIR}/openssl/qtlskey_openssl.cpp" "${TLS_DIR}/openssl/qtlskey_openssl_p.h"
    "${TLS_DIR}/openssl/qtls_openssl.cpp" "${TLS_DIR}/openssl/qtls_openssl_p.h"
    "${TLS_DIR}/openssl/qssldiffiehellmanparameters_openssl.cpp"
    "${TLS_DIR}/openssl/qsslcontext_openssl.cpp" "${TLS_DIR}/openssl/qsslcontext_openssl_p.h"
    "${TLS_DIR}/openssl/qsslsocket_openssl_symbols.cpp"
    "${TLS_DIR}/openssl/qsslsocket_openssl_symbols_p.h"
    "${TLS_DIR}/openssl/qopenssl_p.h"
)

set_target_properties(QTlsBackendOpenSSL3Plugin PROPERTIES
    OUTPUT_NAME qopenssl3backend
    AUTOMOC ON
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# BEFORE so the 3.x headers win over whatever openssl/ the build host has in a default
# search path. (-I dirs are searched before the compiler's implicit ones anyway, but
# being explicit here is what the whole plugin hinges on.)
target_include_directories(QTlsBackendOpenSSL3Plugin BEFORE PRIVATE
    "${QT_OPENSSL3_INCLUDE_DIR}"
    "${TLS_DIR}/openssl"
    "${TLS_DIR}/shared"
)

target_compile_definitions(QTlsBackendOpenSSL3Plugin PRIVATE
    # As the in-tree plugin does: the sources are written against the 1.1 API.
    OPENSSL_API_COMPAT=0x10100000L
    # Register under a name of our own, so this copy and the in-tree one can coexist.
    # Handled by the QT_TLS_OPENSSL_BACKEND_NAME #ifdef in qtlsbackend_openssl.cpp.
    QT_TLS_OPENSSL_BACKEND_NAME=openssl3
    # Rename the C++ class target-wide, so the two plugins share no symbol names and
    # moc's generated plugin entry point matches CLASS_NAME above. This is a -D rather
    # than an #ifdef in qtlsbackend_openssl_p.h because qtls_openssl.cpp names the
    # class without including that header directly.
    QTlsBackendOpenSSL=QTlsBackendOpenSSL3
)

target_link_libraries(QTlsBackendOpenSSL3Plugin PRIVATE
    Qt6::NetworkPrivate
    Qt6::CorePrivate
)

qt_finalize_target(QTlsBackendOpenSSL3Plugin)

install(TARGETS QTlsBackendOpenSSL3Plugin LIBRARY DESTINATION plugins/tls)
