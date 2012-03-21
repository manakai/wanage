PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PROVE = prove

all:

test: test-data safetest

test-data:
	cd t/data && make all

update-test-data:
	cd t/data && make update

safetest: local-submodules carton-install config/perl/libs.txt
	PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt) \
	    $(PROVE) t/wanage/*.t t/warabe/*.t

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120318

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

remotedev-test remotedev-reset remotedev-reset-setupenv \
config/perl/libs.txt local-perl generatepm \
perl-exec perl-version \
carton-install carton-update local-submodules: %: Makefile-setupenv
	make --makefile Makefile.setupenv $@

dataautoupdate:
	cd lib/Wanage/HTTP && $(MAKE) dataautoupdate

GENERATEPM = local/generatepm/bin/generate-pm-package
GENERATEPM_ = $(GENERATEPM) --generate-json

dist: generatepm
	$(GENERATEPM_) config/dist/wanage.pi dist/
	$(GENERATEPM_) config/dist/warabe-app.pi dist/
	$(GENERATEPM_) config/dist/warabe-app-role-json.pi dist/
	$(GENERATEPM_) config/dist/warabe-app-role-datetime.pi dist/

dist-wakaba-packages: local/wakaba-packages dist
	cp dist/*.json local/wakaba-packages/data/perl/
	cp dist/*.tar.gz local/wakaba-packages/perl/
	cd local/wakaba-packages && $(MAKE) all

local/wakaba-packages: always
	git clone "git@github.com:wakaba/packages.git" $@ || (cd $@ && git pull)
	cd $@ && git submodule update --init

always:

## License: Public Domain.
