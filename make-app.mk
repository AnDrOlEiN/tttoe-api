USER = nobody

app:
	docker-compose up

app-setup: ans-development-setup-env app-build
	docker-compose run --user=${USER} app make install

app-build:
	docker-compose build

app-clean:
	docker-compose down