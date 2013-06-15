# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit versionator

MAJ_PV="$(get_major_version)"
MED_PV="$(get_version_component_range 2)"
MIN_PV="$(get_version_component_range 3)"

DESCRIPTION="An open source, highly scalable, schema-free document-oriented database"
HOMEPAGE="http://www.basho.com/"
SRC_URI="http://s3.amazonaws.com/downloads.basho.com/${PN}/${MAJ_PV}.${MED_PV}/${MAJ_PV}.${MED_PV}.${MIN_PV}/${PN}-${MAJ_PV}.${MED_PV}.${MIN_PV}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="kpoll hipe doc"

# TODO test non smp install
RDEPEND="
<dev-lang/erlang-16
>=dev-lang/erlang-15.2.3.1[smp]
kpoll? ( >=dev-lang/erlang-15.2.3.1[kpoll] )
hipe? ( >=dev-lang/erlang-15.2.3.1[hipe] )
!hipe? ( >=dev-lang/erlang-15.2.3.1[-hipe] )
"
DEPEND="${RDEPEND}
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
	# configure gentoo/linux specific directories
	epatch "${FILESDIR}/${MAJ_PV}.${MED_PV}.${MIN_PV}-fix-directories.patch"
	sed -i -e '/XLDFLAGS="$(LDFLAGS)"/d' -e 's/ $(CFLAGS)//g' deps/erlang_js/c_src/Makefile || die
}

src_compile() {
	# build fails with MAKEOPTS > -j1
	MAKEOPTS="-j1" emake rel
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
	fowners riak.riak /var/lib/riak
	fowners riak.riak /var/lib/riak/ring
	fowners riak.riak /var/lib/riak/bitcask
	fowners riak.riak /var/log/riak
	fowners riak.riak /var/log/riak/sasl
	fowners riak.riak /run/riak

	# create docs
	doman doc/man/man1/*
	use doc && dodoc doc/*.txt

	# init.d file
	newinitd "${FILESDIR}/riak-${MAJ_PV}.${MED_PV}.${MIN_PV}.initd" riak
	newconfd "${FILESDIR}/riak-${MAJ_PV}.${MED_PV}.${MIN_PV}.confd" riak

	# TODO logrotate

}

pkg_postinst() {
	local ulimit=$(ulimit -n)
	if [[ $ulimit < 4096 ]]; then
		ewarn "Current ulimit -n is $ulimit. 4096 is the recommended minimum."
	fi
}
