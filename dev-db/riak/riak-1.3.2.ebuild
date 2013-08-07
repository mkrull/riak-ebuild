# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit versionator eutils user multilib toolchain-funcs

# build time dependency
# fork of the google project with riak specific changes
# is used to build the eleveldb lib and gets removed before install
LEVELDB_PV="${PV}"
LEVELDB_URI="https://github.com/basho/leveldb/archive/${LEVELDB_PV}.tar.gz"
LEVELDB_P="leveldb-${LEVELDB_PV}.tar.gz"
LEVELDB_WD="${WORKDIR}/leveldb-${LEVELDB_PV}"
LEVELDB_TARGET_LOCATION="${S}/deps/eleveldb/c_src/leveldb"

DESCRIPTION="An open source, distributed database"
HOMEPAGE="http://www.basho.com/"
SRC_URI="http://s3.amazonaws.com/downloads.basho.com/${PN}/$(get_version_component_range 1-2)/${PV}/${P}.tar.gz
	${LEVELDB_URI} -> ${LEVELDB_P}
"

get_lib_version() {
	echo -n $(find /usr/$(get_libdir)/erlang/lib/ -maxdepth 1 -type d -name ${1}-* | cut -d'-' -f2)
}

get_prestripped() {
	local lib_dir=$(get_libdir)
	# get version information for path of prestripped files
	local erts_version=$(get_lib_version "erts")
	local rt_version=$(get_lib_version "runtime_tools")
	local osmon_version=$(get_lib_version "os_mon")
	local crypto_version=$(get_lib_version "crypto")
	local asn1_version=$(get_lib_version "asn1")

	# prestripped files
	# copied over from the live system as installed with dev-lang/erlang
	echo -n "
		/usr/${lib_dir}/riak/lib/asn1-${asn1_version}/priv/lib/asn1_erl_nif.so
		/usr/${lib_dir}/riak/lib/crypto-${crypto_version}/priv/lib/crypto.so
		/usr/${lib_dir}/riak/lib/os_mon-${osmon_version}/priv/bin/memsup
		/usr/${lib_dir}/riak/lib/os_mon-${osmon_version}/priv/bin/cpu_sup
		/usr/${lib_dir}/riak/lib/runtime_tools-${rt_version}/priv/lib/dyntrace.so
		/usr/${lib_dir}/riak/lib/runtime_tools-${rt_version}/priv/lib/trace_ip_drv.so
		/usr/${lib_dir}/riak/lib/runtime_tools-${rt_version}/priv/lib/trace_file_drv.so
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/beam
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/beam.smp
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/child_setup
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/inet_gethost
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/heart
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/erlexec
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/erlc
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/escript
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/ct_run
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/run_erl
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/to_erl
		/usr/${lib_dir}/riak/erts-${erts_version}/bin/epmd
	"
}

lib_dir=$(get_libdir)
QA_PRESTRIPPED= "
	/usr/${lib_dir}/riak/lib/asn1-.*/priv/lib/asn1_erl_nif.so
	/usr/${lib_dir}/riak/lib/crypto-.*/priv/lib/crypto.so
	/usr/${lib_dir}/riak/lib/os_mon-.*/priv/bin/memsup
	/usr/${lib_dir}/riak/lib/os_mon-.*/priv/bin/cpu_sup
	/usr/${lib_dir}/riak/lib/runtime_tools-.*/priv/lib/dyntrace.so
	/usr/${lib_dir}/riak/lib/runtime_tools-.*/priv/lib/trace_ip_drv.so
	/usr/${lib_dir}/riak/lib/runtime_tools-.*/priv/lib/trace_file_drv.so
	/usr/${lib_dir}/riak/erts-.*/bin/beam
	/usr/${lib_dir}/riak/erts-.*/bin/beam.smp
	/usr/${lib_dir}/riak/erts-.*/bin/child_setup
	/usr/${lib_dir}/riak/erts-.*/bin/inet_gethost
	/usr/${lib_dir}/riak/erts-.*/bin/heart
	/usr/${lib_dir}/riak/erts-.*/bin/erlexec
	/usr/${lib_dir}/riak/erts-.*/bin/erlc
	/usr/${lib_dir}/riak/erts-.*/bin/escript
	/usr/${lib_dir}/riak/erts-.*/bin/ct_run
	/usr/${lib_dir}/riak/erts-.*/bin/run_erl
	/usr/${lib_dir}/riak/erts-.*/bin/to_erl
	/usr/${lib_dir}/riak/erts-.*/bin/epmd
	"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
# TODO luwak useflag and patches
IUSE="doc"

# TODO test non smp install
DEPEND="
	<dev-lang/erlang-16
	>=dev-lang/erlang-15.2.3.1[smp]
"

pkg_setup() {
	ebegin "Creating riak user and group"
	local riak_home="/var/lib/riak"
	enewgroup riak
	enewuser riak -1 -1 $riak_home riak
	eend $?
}

src_prepare() {
	epatch "${FILESDIR}/${PV}-fix-directories.patch"
	epatch "${FILESDIR}/${PV}-honor-cflags.patch"
	sed -i \
		-e '/XLDFLAGS="$(LDFLAGS)"/d' deps/erlang_js/c_src/Makefile || die

	# avoid fetching deps via git that are already available
	ln -s ${LEVELDB_WD} ${LEVELDB_TARGET_LOCATION} || die
	mkdir -p "${S}"/deps/riaknostic/deps || die
	ln -s "${S}"/deps/lager "${S}"/deps/riaknostic/deps || die
	ln -s "${S}"/deps/meck "${S}"/deps/riaknostic/deps || die
	ln -s "${S}"/deps/getopt "${S}"/deps/riaknostic/deps || die
}

src_compile() {
	# build fails with MAKEOPTS > -j1
	emake -j1 \
		CC=$(tc-getCC) \
		CXX=$(tc-getCXX) \
		AR=$(tc-getAR) \
		LD=$(tc-getLD) \
		STRIP="" rel
}

src_install() {
	local lib_dir=$(get_libdir)
	local erts_version=$(get_lib_version "erts")

	# install /usr/lib
	# TODO test on x86
	insinto /usr/${lib_dir}/riak
	doins -r rel/riak/lib
	doins -r rel/riak/releases
	doins -r rel/riak/erts-${erts_version}
	fperms -R 0755 /usr/${lib_dir}/riak/erts-${erts_version}/bin

	# install /usr/bin
	dobin rel/riak/bin/*

	# install /etc/riak
	insinto /etc/riak
	doins rel/riak/etc/*

	# restrict access to cert and key
	fperms 0600 /etc/riak/cert.pem
	fperms 0600 /etc/riak/key.pem

	# create neccessary directories
	keepdir /var/lib/riak/{bitcask,ring}
	keepdir /var/log/riak/sasl

	# change owner to riak
	fowners -R riak:riak /var/lib/riak
	fowners -R riak:riak /var/log/riak

	# create docs
	doman doc/man/man1/*
	use doc && dodoc doc/*.txt

	# init.d file
	newinitd "${FILESDIR}/${P}.initd" riak
	newconfd "${FILESDIR}/${P}.confd" riak

	# TODO logrotate
}

pkg_postinst() {
	ewarn "To use kernel polling build erlang with the 'kpoll' useflag"
}