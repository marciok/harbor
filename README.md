# Harbor

Harbor showcases prompt orchestration workflows built with [Gust](https://github.com/marciok/gust).

Skipper is the first workflow: it sends a prompt to multiple AI models, gathers their perspectives, and synthesizes them into a final answer.


---

## Example

### Prompt

*“Create a portfolio of high-risk/high-reward tech stocks to hold for the next 3 years.”*

### Choose the panel of models
<img width="1077" height="863" alt="Screenshot 2026-08-14 at 16 13 44" src="https://github.com/user-attachments/assets/79143543-9beb-4104-ae73-874051cd3c9b" />

### 1. Each model receives the prompt
<img width="1139" height="651" alt="Screenshot 2026-08-14 at 16 14 08" src="https://github.com/user-attachments/assets/c762e0fd-eb2e-4f36-9628-71f4e4936d99" />

### 2. The responses are analyzed
<img width="1135" height="538" alt="Screenshot 2026-08-14 at 16 52 14" src="https://github.com/user-attachments/assets/bc290dc8-a671-4802-a598-dda4fdf88f5a" />

### 3. Another model synthesizes the responses into a final answer
<img width="1143" height="862" alt="Screenshot 2026-08-14 at 16 56 59" src="https://github.com/user-attachments/assets/59a5a40f-8d4e-408a-8394-9882e5ec8488" />

---

## Run locally

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
