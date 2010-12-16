#!/bin/bash

set -e

function abort() {
    local status=$?
    if test $# = 0; then
	echo Failed
    else
	echo "$*"
    fi
    if test $status = 0; then
	status=1
    fi
    exit $status
}

function download() {
    for url do
	test -f "${SOURCE}/${url##*/}" || missing=("${missing[@]}" "$url")
    done
}

function inst() {
    local base="${1##*/}"
    download "$1"
    shift
    installs=("${installs[@]}" "$SEPARATOR" "$base" "$@")
}

function do_install1() {
    local base patched

    echo "Install: [$(date +%Y/%m/%d-%H:%M:%S)] $1" 1>&$log

    build_dir="$PREFIX/build"

    case "$1" in
      (*.tar.bz2)
	echo -n "Extracting $1..."
	mkdir -p "$build_dir"
	tar xpjf "${SOURCE}/$1" -C "$build_dir" 1>&$log 2>&1 || abort
	echo done
	base=${1%.tar.bz2}
	;;
      (*.tar.gz)
	echo -n "Extracting $1..."
	mkdir -p "$build_dir"
	tar xpzf "${SOURCE}/$1" -C "$build_dir" 1>&$log 2>&1 || abort
	echo done
	base=${1%.tar.gz}
	;;
      (*.gem)
	echo -n "Installing $1..."
	ruby -C "${SOURCE}" -S gem install --no-ri --no-rdoc --local "$1" 1>&$log 2>&1 || abort
	echo done
	return
	;;
    esac

    while shift; do
	case "$1" in
	  (--patch=*)
	    echo -n "Applying patch ${1#*=} to $base..."
	    patch -d "$build_dir/$base" -p1 < "${SOURCE}/${1#*=}" 1>&$log 2>&1 || abort
	    patched=yes
	    echo done
	    ;;
	  (*)
	    break
	    ;;
	esac
    done

    (cd "$build_dir/$base"
    if test \( -f configure.in -a ! configure -nt configure.in \) \
	 -o \( -f configure.ac -a ! configure -nt configure.ac \); then
	exec autoconf
    fi) 1>&$log 2>&1

    if test -f "$build_dir/$base/configure"; then
	echo -n "Configuring $base..."
	(
	    cd "$build_dir/$base"
	    exec ./configure --enable-shared --prefix="$PREFIX" "$@"
	) 1>&$log 2>&1 || abort
	echo done
    fi

    echo -n "Building $base..."
    if test -f "$build_dir/$base/Makefile"; then
	test "$patched" = yes && make -C "build/$base" prereq 1>&$log 2>&1 || true
	make -C "$build_dir/$base" 1>&$log 2>&1 || abort
    elif test -f "$build_dir/$base/Rakefile"; then
	ruby -C "$build_dir/$base" -S rake 1>&$log 2>&1 || abort
    fi
    echo done

    echo -n "Installing $base..."
    if test -f "$build_dir/$base/GNUmakefile" -o -f "$build_dir/$base/Makefile"; then
	make -C "$build_dir/$base" prefix="$PREFIX" install 1>&$log 2>&1 || abort
    elif test -f "$build_dir/$base/Rakefile"; then
	ruby -C "$build_dir/$base" -S rake install 1>&$log 2>&1 || abort
    fi
    echo done

    rm -fr "$build_dir/$base" > /dev/null 2>&1 || :
    rmdir "$build_dir" >/dev/null 2>&1 || :
}

function download_all() {
    if test ${#missing[@]} -gt 0; then
	if test ! -z "${missing}"; then
	    wget -N -P "${SOURCE}" "${missing[@]}" || abort
	fi
    fi
}

function install_passenger() {
    echo -n "Installing Phusion Passenger..."
    if test -n "$APXS2_PATH" -a -n "$APR_CONFIG_PATH"; then
	ruby -S passenger-install-apache2-module -a \
	    --apxs2-path "$APXS2_PATH" \
	    --apr-config-path "$APR_CONFIG_PATH" 1>&$log 2>&1 || abort
    elif test -n "$APXS2_PATH" -a -z "$APR_CONFIG_PATH"; then
	ruby -S passenger-install-apache2-module -a \
	    --apxs2-path "$APXS2_PATH" 1>&$log 2>&1 || abort
    elif test -z "$APXS2_PATH" -a -n "$APR_CONFIG_PATH"; then
	ruby -S passenger-install-apache2-module -a \
	    --apr-config-path "$APR_CONFIG_PATH" 1>&$log 2>&1 || abort
    else
	if test -d "$HTTPD_PREFIX"; then
	    export PATH="$HTTPD_PREFIX/bin:$PATH"
	fi
	ruby -S passenger-install-apache2-module -a 1>&$log 2>&1 || abort
    fi
    echo done
}

function install_ranguba() {
    install_passenger
    echo -n "set up $APPLICATION_NAME..."
    mkdir -p "$PREFIX/"
    test ! -f "$PREFIX/$APPLICATION_NAME/Gemfile" && tar xfz "$SOURCE/$APPLICATION_NAME.tar.gz" -C "$PREFIX/"
    mkdir -p "$PREFIX/$APPLICATION_NAME/vendor/cache"
    cp -a ${SOURCE}/*.gem "$PREFIX/$APPLICATION_NAME/vendor/cache"
    cd "$PREFIX/$APPLICATION_NAME"
    cp config/groonga.yml.example config/groonga.yml
    RAILS_ENV="production" ruby -S bundle --no-color install \
	--local --without development test 1>&$log 2>&1 || abort "Failed in install_ranguba"
    RAILS_ENV="production" ruby -S rake groonga:migrate 1>&$log 2>&1 || abort "Failed in install_ranguba"
    generate_ranguba_conf
    if test ! -L "$PREFIX/etc/$APPLICATION_NAME"; then
	ln -s "$PREFIX/$APPLICATION_NAME/config/customize" "$PREFIX/etc/$APPLICATION_NAME"
    fi
    if test -f "$DATA_DIR/categories.csv"; then
	cp -f "$DATA_DIR/categories.csv" "$PREFIX/$APPLICATION_NAME/config/customize/categories.csv"
    fi
    echo done
}

function generate_ranguba_conf() {
    if test ! -f ranguba.conf; then
        ruby -S passenger-install-apache2-module --snippet > ranguba.conf
	cat >> ranguba.conf <<EOF
RailsBaseURI ${RAILS_BASE_URI}
<Directory ${PREFIX}/${APPLICATION_NAME}>
  Options -MultiViews
</Directory>
EOF
    fi
    if test ! -f "$PREFIX/$APPLICATION_NAME/$APPLICATION_NAME.conf";then
	cp -f ranguba.conf "$PREFIX/$APPLICATION_NAME/$APPLICATION_NAME.conf"
    fi
}

function install_all() {
    local args arg
    if test "$install_ranguba_only" = "no"; then
	until test ${#installs[@]} = 0; do
	    args=()
	    until test ${#installs[@]} = 0 || {
		arg="${installs}" installs=("${installs[@]:1}")
		test "$arg" = "$SEPARATOR"
	    } do
	    args=("${args[@]}" "${arg}")
	    done
	    test ${#args[@]} -gt 0 && do_install1 "${args[@]}"
	done
    fi
    install_ranguba
    install_crontab
}

function install_crontab() {
    echo -n "Install crontab ..."
    if test -x "$DATA_DIR/make_index"; then
	cp -f "$DATA_DIR/make_index" "$PREFIX/bin/make_index"
    fi
    local COMMAND="${PREFIX}/bin/make_index"
    echo "0 1 * * * $COMMAND" | crontab -
    echo "done"
}

test -f ./sourcelist && source ./sourcelist

export PATH="$PREFIX/bin:$PATH"
export LD_RUN_PATH="$PREFIX/lib:${LD_RUN_PATH-/usr/$lib}"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH-/usr/$lib}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH-/usr/$lib/pkgconfig}"

if test "$noinst" = no; then
    exec 3> install.log
    log=3
else
    log=
fi
# exec install
if test "$showlist" = yes; then
    echo "Packages to be installed:"
    show=yes
    for inst in "${installs[@]}"; do
	if test "$inst" = "$SEPARATOR"; then
	    show=yes
	else
	    test "$show" = yes && echo "* $inst"
	    show=no
	fi
    done
    echo "Packages to be downloaded:"
    for url in "${missing[@]}"; do
	echo "* $url"
    done
else
    download_all
    test "$noinst" = yes || install_all
fi

# Local Variables:
# tab-width: 8
# indent-tabs-mode: t
# End:

