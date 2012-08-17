PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PROVE = prove

## $ git pull
## $ git submodule update --init
## 
## ... then:
## 
## Test:
##     $ make test
## Update dependency list:
##     $ make local-submodules pmb-update
## Install dependent modules into ./local/:
##     $ make pmb-install
## Create tarballs for distribution:
##     $ make dist

all:

test: test-deps test-data safetest

test-data:
	cd t/data && make all

update-test-data:
	cd t/data && make update

safetest: test-deps safetest-main

safetest-main:
	PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt) \
	    $(PROVE) t/wanage/*.t t/warabe/*.t

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120318

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

local-perl generatepm \
lperl perl-exec perl-version local-submodules \
pmb-update pmb-install \
: %: Makefile-setupenv
	make --makefile Makefile.setupenv $@

test-deps: pmb-install

dataautoupdate:
	cd lib/Wanage/HTTP && $(MAKE) dataautoupdate

GENERATEPM = local/generatepm/bin/generate-pm-package
GENERATEPM_ = $(GENERATEPM) --generate-json

dist: generatepm
	$(GENERATEPM_) config/dist/wanage.pi dist/
	$(GENERATEPM_) config/dist/warabe-app.pi dist/
	$(GENERATEPM_) config/dist/warabe-app-role-json.pi dist/
	$(GENERATEPM_) config/dist/warabe-app-role-messagepack.pi dist/
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
