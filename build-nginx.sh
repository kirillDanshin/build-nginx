#!/bin/sh
set -e
#FORCE_IMAGICK_INSTALL=y
SRC_DIR=/tmp/nginx-sources
NGINX_VERSION="1.11.3"
PAGESPEED_VERSION="1.11.33.2"
OPENSSL_VERSION="1.0.2h"
SMALL_LIGHT_VERSION="0.8.0"
# Use MTUNE="generic" if you don't know what to choose
MTUNE="i686"

echo Install requirements \[1/3\]
yum install -y freetype-devel freetype libraqm-devel \
	harfbuzz-devel harfbuzz-icu harfbuzz fribidi-devel \
	ghostscript autoconf

echo Install requirements \[2/3\]

yum install ImageMagick ImageMagick-devel

echo Install requirements \[3/3\]
yum install -y gcc-c++ pcre-devel zlib-devel make unzip pcre2-devel imlib2-devel libxml2 libxml2-devel libxslt-devel gd gd-devel perl-ExtUtils-Embed GeoIP-devel GeoIP

# Pagespeed module
if [ ! -d $SRC_DIR/ngx_pagespeed ]; then
	echo Downloading ngx_pagespeed release v$PAGESPEED_VERSION
	wget https://github.com/pagespeed/ngx_pagespeed/archive/v$PAGESPEED_VERSION-beta.tar.gz -O pagespeed.tar.gz >/dev/null
	echo Extracting ngx_pagespeed release
	tar -xzf pagespeed.tar.gz
	echo Clean ngx_pagespeed release
	rm -rf pagespeed.tar.gz

	echo Move to expected include directory
	mv ngx_pagespeed-1.11.33.2-beta ngx_pagespeed
	cd ngx_pagespeed
	echo Download ngx_pagespeed requirement: psol
	wget https://dl.google.com/dl/page-speed/psol/$PAGESPEED_VERSION.tar.gz -O psol.tar.gz >/dev/null
	echo Extract psol
	tar -xzf psol.tar.gz
	echo Clean psol
	rm -rf psol.tar.gz
fi
cd $SRC_DIR

# OpenSSL module
if [ ! -d $SRC_DIR/openssl ]; then
	echo Download openssl-$OPENSSL_VERSION
	wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz -O openssl.tar.gz
	echo Extract openssl
	tar -xzf openssl.tar.gz
	echo Clean openssl
	rm -rf openssl.tar.gz
	echo Move to expected include directory
	mv openssl-$OPENSSL_VERSION openssl
fi

cd $SRC_DIR

# Small Light module
if [ -d $SRC_DIR/ngx_small_light ]; then
	echo Clean previous installation of ngx_small_light module
	rm -rf $SRC_DIR/ngx_small_light
fi
echo Download ngx_small_light module v$SMALL_LIGHT_VERSION
wget https://github.com/cubicdaiya/ngx_small_light/archive/v$SMALL_LIGHT_VERSION.tar.gz -O smallLight.tar.gz
echo Extract ngx_small_light module
tar -xzf smallLight.tar.gz
echo Clean ngx_small_light
rm -rf smallLight.tar.gz

echo Move to expected include directory
mv ngx_small_light-$SMALL_LIGHT_VERSION ngx_small_light

cd $SRC_DIR/ngx_small_light
./setup --with-imlib2 --with-gd || ./setup --with-imlib2 || ./setup --with-gd || ./setup

cd $SRC_DIR

# NJS
if [ ! -d $SRC_DIR/njs ]; then
	echo Download NJS module
	wget https://github.com/nginx/njs/archive/master.zip -O njs.zip
	echo Extract NJS module
	unzip njs.zip >/dev/null
	echo Clean NJS module
	rm -rf njs.zip
	echo Move to expected include directory
	mv njs-master njs
fi

cd $SRC_DIR

# echo-nginx-module
if [ ! -d $SRC_DIR/echo ]; then
	echo Download echo module
	wget https://github.com/openresty/echo-nginx-module/archive/master.zip -O echo.zip
	echo Extract echo module
	unzip echo.zip >/dev/null
	echo Clean echo module
	rm -rf echo.zip
	echo Move to expected include directory
	mv echo-nginx-module-master echo
fi

# OK, let's build nginx itself
cd $SRC_DIR
if [ ! -d $SRC_DIR/nginx-$NGINX_VERSION ]; then
	echo Download nginx $NGINX_VERSION source
	wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -O nginx.tar.gz
	echo Extract nginx
	tar -xzf nginx.tar.gz
	#mv nginx-$NGINX_VERSION nginx
fi

echo Setting $(pwd) owner to $USER:$GROUP recursive
chown $USER:$GROUP ./ -R

cd nginx-$NGINX_VERSION

GCC_OPTS='-static -static-libgcc -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2'
GCC_OPTS=$GCC_OPTS' -fexceptions -fstack-protector-strong'
GCC_OPTS=$GCC_OPTS' --param=ssp-buffer-size=4 -grecord-gcc-switches'
GCC_OPTS=$GCC_OPTS' -m64 -mtune='$MTUNE

echo Using GCC OPTS=\[$GCC_OPTS\]

echo Configuring

./configure \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib64/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_xslt_module=dynamic \
	--with-http_image_filter_module=dynamic \
	--with-http_geoip_module=dynamic \
	--with-http_perl_module=dynamic \
	\
	--with-openssl=$SRC_DIR/openssl \
	--add-module=$SRC_DIR/njs/nginx \
	--add-module=$SRC_DIR/ngx_pagespeed \
	--add-module=$SRC_DIR/ngx_small_light \
	--add-module=$SRC_DIR/echo \
	\
	--with-debug \
	--with-threads \
	--with-stream \
	--with-stream_ssl_module \
	--with-http_slice_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-file-aio \
	--with-ipv6 \
	--with-http_v2_module \
	--with-cc-opt='${GCC_OPTS}' \
	--with-ld-opt='-Bstatic,-z'
make -j1
