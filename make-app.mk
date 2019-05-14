
app:
	docker-compose up

app-setup: ans-development-setup-env app-build

app-build:
	docker-compose build

app-clean:
	docker-compose down