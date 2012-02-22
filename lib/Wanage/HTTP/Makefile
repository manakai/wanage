all: _update

update: update-delete update-submodules _update

update-delete:
	rm -f Info.pm

update-submodules:
	cd ../../../modules/manakai && git pull origin master

_update: Info.pm

Info.pm: mkinfo.pl \
  ../../../modules/manakai/lib/Whatpm/HTTP/_Methods.pm \
  ../../../modules/manakai/lib/Whatpm/HTTP/_StatusCodes.pm
	perl mkinfo.pl > $@
	perl -c $@

## License: Public Domain.