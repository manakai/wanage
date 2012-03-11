all: cookie-date

cookie-date: http-state-dates

http-state-dates:
	mkdir -p http-state-dates
	wget -O http-state-dates/examples.json https://raw.github.com/abarth/http-state/master/tests/data/dates/examples.json
	wget -O http-state-dates/bsd-examples.json https://raw.github.com/abarth/http-state/master/tests/data/dates/bsd-examples.json

update: clean-cookie-date cookie-date

clean-cookie-date:
	rm -fr ./http-state-dates

## License: Public Domain.
