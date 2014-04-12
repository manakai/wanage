# -*- Makefile -*-

all: all-data
clean: clean-data

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl all-data
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add modules bin/modules t_deps/modules
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
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Data ------

all-data:
	cd lib/Wanage/HTTP && $(MAKE) update

clean-data:

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
