all: all-data
clean: clean-data

WGET = wget
CURL = curl
GIT = git
PERL = ./perl

updatenightly: local/bin/pmbp.pl all-data
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config lib

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update \
	    --write-makefile-pl Makefile.PL
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install

## ------ Data ------

all-data: lib/Wanage/HTTP/Info.pm
clean-data:
	rm -fr local/*.json

lib/Wanage/HTTP/Info.pm: bin/mkinfo.pl local/http-methods.json \
    local/http-status-codes.json
	$(PERL) bin/mkinfo.pl > $@

local/http-methods.json:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/http-methods.json
local/http-status-codes.json:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/http-status-codes.json

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps test-data

test-data:
	cd t/data && make all
update-test-data:
	cd t/data && make update

test-main:
	$(PROVE) t/wanage/*.t t/warabe/*.t

## License: Public Domain.
