PROVE = ./prove
GIT = git

## Test:
##     $ make test
## Update dependency list:
##     $ make pmbp-update
## Install dependent modules into ./local/:
##     $ make deps
## Create tarballs for distribution:
##     $ make dist

all:

## ------ Environment ------

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120930

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

pmb-update: pmbp-update
pmb-install: pmbp-install
local-perl: pmbp-install
lperl: pmbp-install
lprove: pmbp-install

generatepm pmbp-update pmbp-install: %: Makefile-setupenv
	make --makefile Makefile.setupenv $@

pmbp-update: Makefile-setupenv git-submodules
	make --makefile Makefile.setupenv $@

git-submodules:
	$(GIT) submodule update --init

deps: git-submodules pmbp-install

## ------ Tests ------

test: test-deps test-data safetest

test-data:
	cd t/data && make all

update-test-data:
	cd t/data && make update

safetest: test-deps safetest-main

safetest-main:
	$(PROVE) t/wanage/*.t t/warabe/*.t

test-deps: deps

## ------ Data ------

dataautoupdate:
	cd lib/Wanage/HTTP && $(MAKE) dataautoupdate

## ------ Packaging ------

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
	$(GIT) clone "git@github.com:wakaba/packages.git" $@ || (cd $@ && git pull)
	cd $@ && git submodule update --init

always:

## License: Public Domain.
