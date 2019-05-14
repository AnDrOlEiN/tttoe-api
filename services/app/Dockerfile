# Build
FROM elixir:1.7.3-alpine as buildstep

RUN apk update && apk add git

ENV MIX_ENV prod

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mkdir /app
WORKDIR /app

COPY . .
RUN mix deps.get

RUN mix release

# Release
FROM alpine:3.7

RUN mkdir /app
RUN apk update && apk add bash openssl

COPY --from=buildstep /app/_build/prod/rel/tictactoe/ /app

CMD ["/app/bin/tictactoe", "foreground"]
