PERL_PATH = local/dummy/path/to/perl/bin
PROVE = prove

all:

test: test-data safetest

test-data:
	cd t/data && make all

update-test-data:
	cd t/data && make update

safetest: local-submodules carton-install config/perl/libs.txt
	PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt) \
	    $(PROVE) t/*.t

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120313

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

remotedev-test remotedev-reset remotedev-reset-setupenv \
config/perl/libs.txt local-perl \
perl-exec perl-version \
carton-install carton-update local-submodules: %: Makefile-setupenv
	make --makefile Makefile.setupenv $@

always:

## License: Public Domain.
