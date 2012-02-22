PROVE = prove

all:

test: safetest

safetest:
	$(PROVE) t/*.t

## License: Public Domain.
