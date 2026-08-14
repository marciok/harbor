# Harbor

Harbor is a Phoenix application that uses [Gust](https://github.com/marciok/gust) to run a prompt across multiple AI models and synthesize one final answer.

## Run locally with Docker

You only need Docker with Docker Compose installed.

```sh
docker compose up --build
```

Open [http://localhost:4000](http://localhost:4000).

Stop Harbor with `docker compose down`. PostgreSQL data is kept in a Docker volume between runs.

> The Compose configuration and its default secrets are for local development only.

## Run locally as a Phoenix application

Install Elixir, Erlang, and PostgreSQL, then create your local environment file:

```sh
cp .envrc.example .envrc
```

Replace the two `replace-me` values in `.envrc` using the generation commands documented in that file. Update the PostgreSQL values if your local database uses different credentials, then run:

```sh
source .envrc
mix setup
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

## Configure the model provider

With Harbor running through either method, open [http://localhost:4000/gust/secrets/new](http://localhost:4000/gust/secrets/new) and create this Gust secret:

- Name: `VERCEL_API`
- Value type: `json`
- Value:

```json
{"host":"https://ai-gateway.vercel.sh/v1","token":"your-vercel-ai-gateway-key"}
```

Then visit [Skipper](http://localhost:4000/skipper) and load the available models.
