# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit versionator

MAJ_PV="$(get_major_version)"
MED_PV="$(get_version_component_range 2)"
MIN_PV="$(get_version_component_range 3)"

LEVELDB_PV="1.3.0"
LEVELDB_URI="https://github.com/basho/leveldb/archive/${LEVELDB_PV}.zip"
LEVELDB_P="leveldb-${LEVELDB_PV}.zip"
LEVELDB_WD="${WORKDIR}/leveldb-${LEVELDB_PV}"
LEVELDB_TARGET_LOCATION="${WORKDIR}/${PN}-${PV}/deps/eleveldb/c_src/leveldb"

DESCRIPTION="An open source, highly scalable, schema-free document-oriented database"
HOMEPAGE="http://www.basho.com/"
SRC_URI="http://s3.amazonaws.com/downloads.basho.com/${PN}/${MAJ_PV}.${MED_PV}/${PV}/${PN}-${PV}.tar.gz
${LEVELDB_URI} -> ${LEVELDB_P}
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="kpoll doc"

# TODO test non smp install
RDEPEND="
<dev-lang/erlang-16
>=dev-lang/erlang-15.2.3.1[smp]
kpoll? ( >=dev-lang/erlang-15.2.3.1[kpoll] )
"
# git is used during build to manage parts internally
# nothing gets actually fetched
DEPEND="${RDEPEND}
app-arch/unzip
dev-vcs/git
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
	sed -i -e '/XLDFLAGS="$(LDFLAGS)"/d' -e 's/ $(CFLAGS)//g' deps/erlang_js/c_src/Makefile || die
	ln -s ${LEVELDB_WD} ${LEVELDB_TARGET_LOCATION}
}

src_compile() {
	# build fails with MAKEOPTS > -j1
	emake -j1 rel
}

src_install() {
	# install /usr/lib
	insinto /usr/lib/riak
	cp -R rel/riak/lib "${D}"/usr/lib/riak
	cp -R rel/riak/releases "${D}"/usr/lib/riak
	cp -R rel/riak/erts* "${D}"/usr/lib/riak
	chmod 0755 "${D}"/usr/lib/riak/erts*/bin/*

	# install /usr/bin
	dobin rel/riak/bin/*

	# install /etc/riak
	# adjust config to used flags
	if ! use kpoll; then
		sed -i -e '/+K true/d' rel/riak/etc/vm.args || die
	fi

	insinto /etc/riak
	doins rel/riak/etc/*

	# restrict access to cert and key
	fperms 0600 /etc/riak/cert.pem
	fperms 0600 /etc/riak/key.pem

	# create neccessary directories
	keepdir /var/lib/riak/{bitcask,ring}
	keepdir /var/log/riak/sasl
	keepdir /run/riak

	# change owner to riak
	fowners -R riak:riak /var/lib/riak
	fowners -R riak:riak /var/log/riak
	fowners riak:riak /run/riak

	# create docs
	doman doc/man/man1/*
	use doc && dodoc doc/*.txt

	# init.d file
	newinitd "${FILESDIR}/riak-${MAJ_PV}.${MED_PV}.${MIN_PV}.initd" riak
	newconfd "${FILESDIR}/riak-${MAJ_PV}.${MED_PV}.${MIN_PV}.confd" riak

	# TODO logrotate
}
