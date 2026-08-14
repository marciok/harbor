FROM elixir:1.18.4-otp-27-slim

RUN apt-get update \
  && apt-get install --yes --no-install-recommends build-essential ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/

RUN mix deps.get --only prod && mix deps.compile

COPY assets assets
COPY dags dags
COPY lib lib
COPY priv priv

RUN mix compile && mix assets.deploy

COPY config/runtime.exs config/

EXPOSE 4000

CMD ["sh", "-c", "mix ecto.migrate && exec mix phx.server"]
