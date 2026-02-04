# goose-foundry
Build and deploy `goosed` to Cloud Foundry.

**Prereqs**
- Docker (for the CF-compatible build image)
- Cloud Foundry CLI (`cf`)
- `vendir` installed
- `jq` (used by `test.sh`)

**1) Vendor the Goose source**
This repo uses `vendir` to pull `vendor/goose`. Run this first (and re-run after updates).

```bash
vendir sync
```

**2) Build the CF Linux build image**
The `Dockerfile` in this repo builds a Linux/amd64 image aligned with CF (cflinuxfs4 / Ubuntu 22.04). This is used to compile a compatible `goosed` binary.

```bash
docker build --platform linux/amd64 -t goose-build:cf .
```

**3) Build `goosed` for CF**
This uses the image above and outputs the binary to `target/linux-release/release/goosed`.

```bash
./build-goosed-cf.sh
```

**4) Push to Cloud Foundry**
The repo includes:
- `manifest.yml` with app config
- `Procfile` with the CF runtime command
- `push.sh` to stage and push

Set your API key, then push:

```bash
export OPENAI_API_KEY="..."
./push.sh
```

**5) Test the deployment**
`test.sh` will discover the route from `manifest.yml` and the live CF app, then exercise the API.

```bash
./test.sh "Hello, what can you do?"
```

**6) Use Goose Desktop with a remote agent**
Install the Goose Desktop app for your OS, then connect it to the Cloud Foundry deployment:

1. Open Goose Desktop → Settings.
2. In **Goose Server**, toggle **Use external server** on.
3. Set **Server URL** to your app URL (for example, `https://<route>`).
4. Set **Secret Key** to the same value as `GOOSE_SERVER__SECRET_KEY`.
5. Restart Goose Desktop.
6. Open a new chat window — it will connect to the remote `goosed` instance.

Screenshots:

![Goose Desktop using remote agent](./docs/goose-desktop-session-remote-agent.png)

![Goose Desktop external server settings](./docs/goose-desktop-external-server-settings.png)

**Notes**
- The app reads host/port from `GOOSE_HOST` / `GOOSE_PORT` (not double-underscore).
- `GOOSE_SERVER__SECRET_KEY` is required for auth (double-underscore is correct here).
- The staging directory is `cf-app/` and is gitignored for demo visibility.
