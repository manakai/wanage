all: _update

update: update-delete update-submodules _update

update-delete:
	rm -f Info.pm

update-submodules:
	-git clone git://github.com/wakaba/manakai
	cd manakai && git pull origin master

manakai/lib/Whatpm/HTTP/_Methods.pm: update-submodules
manakai/lib/Whatpm/HTTP/_StatusCodes.pm: update-submodules

_update: Info.pm

Info.pm: mkinfo.pl \
  manakai/lib/Whatpm/HTTP/_Methods.pm \
  manakai/lib/Whatpm/HTTP/_StatusCodes.pm
	perl mkinfo.pl > $@
	perl -c $@

dataautoupdate: update dataautoupdate-git

dataautoupdate-git:
	git add Info.pm

## License: Public Domain.