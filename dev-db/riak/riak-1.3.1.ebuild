# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

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
IUSE="smp kpoll hipe"

RDEPEND="
>=dev-lang/erlang-15.2.3.1[smp]
kpoll? ( >=dev-lang/erlang-15.2.3.1[kpoll] )
hipe? ( >=dev-lang/erlang-15.2.3.1[hipe] )
!kpoll? ( >=dev-lang/erlang-15.2.3.1[-kpoll] )
!hipe? ( >=dev-lang/erlang-15.2.3.1[-hipe] )
dev-vcs/git
"
DEPEND="${RDEPEND}"

pkg_setup() {
    enewgroup riak
    enewuser riak -1 /bin/bash /var/lib/${PN} riak
}

src_prepare() {
    epatch "${FILESDIR}/${MAJ_PV}.${MED_PV}.${MIN_PV}-fix-directories.patch"
    sed -i -e 's/XLDFLAGS="$(LDFLAGS)"//g' -e 's/ $(CFLAGS)//g' deps/erlang_js/c_src/Makefile || die
}

src_compile() {
    # emake failed silently.. so
    make rel
}

src_install() {
    # install /usr/lib stuff
    insinto /usr/lib/${PN}
    cp -R rel/riak/lib "${D}"/usr/lib/riak
    cp -R rel/riak/releases "${D}"/usr/lib/riak
    cp -R rel/riak/erts* "${D}"/usr/lib/riak
    chmod 0755 "${D}"/usr/lib/riak/erts*/bin/*

    # install /usr/bin stuff
    dobin rel/riak/bin/*

    # install /etc/riak stuff
    insinto /etc/${PN}
    doins rel/riak/etc/*

    # create neccessary directories
    keepdir /var/lib/${PN}/{bitcask,ring}
    keepdir /var/log/${PN}/sasl
    keepdir /var/run/${PN}

    # change owner to riak
    fowners riak.riak /var/lib/${PN}
    fowners riak.riak /var/lib/${PN}/ring
    fowners riak.riak /var/lib/${PN}/bitcask
    fowners riak.riak /var/log/${PN}
    fowners riak.riak /var/log/${PN}/sasl
    fowners riak.riak /var/run/${PN}

    # create docs
    doman doc/man/man1/*
    dodoc doc/*.txt

    # init.d file
    newinitd "${FILESDIR}/${PN}-${MAJ_PV}.${MED_PV}.${MIN_PV}.initd" ${PN}
    newconfd "${FILESDIR}/${PN}-${MAJ_PV}.${MED_PV}.${MIN_PV}.confd" ${PN}

}

pkg_postinst() {
    ewarn "The default user to run riak is 'riak'"
}

