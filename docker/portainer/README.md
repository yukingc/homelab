# Portainer (bootstrap stack)

Portainer Server for the homelab. It runs on a primary dedicated host machine (e.g., Beelink or Mac Mini) and manages every other stack, including those on external hosts (via the Portainer Agent).

> **Rule: this stack is never deployed from Portainer itself.**
> It is the tool that manages the other stacks, so it is started and updated
> from the command line on the primary host. Redeploying it from its own UI would cut off the
> session mid-deploy and could lock you out.

## How access works

```
browser --(tailnet)--> tailscale-portainer sidecar (node "portainer") --> 127.0.0.1:9443 --> Portainer
```

- A **Tailscale sidecar container** (`tailscale-portainer`) joins the tailnet as
  its own node, `portainer`. Portainer shares the sidecar's network namespace
  (`network_mode: service:tailscale-portainer`), so the sidecar reaches it on
  `127.0.0.1:9443`.
- The sidecar terminates HTTPS with a Tailscale-issued certificate and proxies
  to Portainer, using `serve.json` loaded through `TS_SERVE_CONFIG`. No
  `tailscale serve` command is run on the host, and the host's Tailscale is not
  involved in this path.
- Portainer publishes **no ports** of its own. Nothing on the LAN can reach it
  directly.
- This path does **not** depend on tsdproxy, so a broken tsdproxy deploy cannot
  lock you out.
- URL: `https://portainer.<tailnet>.ts.net` (no port).
- Last-resort access if the tailnet path is down: because Portainer has no
  published ports, use `docker exec tailscale-portainer wget -qO-
  --no-check-certificate https://127.0.0.1:9443 | head` to confirm Portainer
  itself is up. For a browser fallback, publish `127.0.0.1:9443:9443` on the
  **sidecar** service (not on Portainer) and open `https://localhost:9443`
  (expect a self-signed certificate warning).

The compose file in this folder is expected to contain:

- `name: portainer` at the top (keeps volume names stable)
- a pinned Portainer image version, not `latest`
- `restart: unless-stopped` on both services
- a `tailscale-portainer` service (`tailscale/tailscale`) with `hostname:
  portainer`, and the environment variables `TS_AUTHKEY`, `TS_STATE_DIR`,
  `TS_SERVE_CONFIG=/config/serve.json` and `TS_USERSPACE`
- a persistent state volume for the sidecar (`./ts-state:/var/lib/tailscale`),
  so the node identity and certificate survive recreates
- `./serve.json:/config/serve.json:ro` mounted into the sidecar
- the Portainer service with `network_mode: service:tailscale-portainer` and
  **no** `ports:` entry
- the Docker socket mount and a `portainer-data` volume mounted at `/data`

`serve.json`:

```json
{
  "TCP": { "443": { "HTTPS": true } },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": { "/": { "Proxy": "https+insecure://127.0.0.1:9443" } }
    }
  }
}
```

`https+insecure://` is needed because Portainer's own certificate is
self-signed. If the sidecar logs `could not connect to local backend server at
127.0.0.1:443`, the serve config was not loaded.

## Prerequisites

- **HTTPS Certificates** enabled in the Tailscale admin console (DNS tab)
- A Tailscale auth key (reusable, or an OAuth client), passed as `TS_AUTHKEY`
- `serve.json` next to the compose file

## First-time setup

1. Start the stack (from this folder), supplying the auth key:
   ```bash
   TS_AUTHKEY=xxx docker compose up -d
   ```
2. Check the sidecar joined the tailnet and is serving:
   ```bash
   docker exec tailscale-portainer tailscale status --self
   docker exec tailscale-portainer tailscale serve status
   ```
   `serve status` should show `https://portainer.<tailnet>.ts.net` proxying to
   `https+insecure://127.0.0.1:9443`.
3. Open `https://portainer.<tailnet>.ts.net` and create the admin user. Do this
   promptly, since an unconfigured Portainer times out its initial setup and
   needs a restart. The very first load can take about 30 seconds (and may show
   a certificate warning) while the certificate is issued; wait, fully reload,
   and it clears.

The auth key is only needed on first start. Node state is persisted in
`./ts-state`, so later runs can use plain `docker compose up -d`.

To remove it later: `docker compose down`, then delete the `portainer` node in
the Tailscale admin console.

## Day-to-day

```bash
docker compose ps
docker compose logs -f portainer
docker compose logs -f tailscale-portainer

# Upgrade: bump the pinned image tag in compose.yaml, then
docker compose pull
docker compose up -d   # no auth key needed once ./ts-state exists
```

## Adding another host (Portainer Agent)

On the external or secondary machine (Linux, or Docker Desktop inside WSL2 on a Windows host), run the agent container standalone using `docker run`:

```bash
docker run -d \
  -p 9001:9001   --name portainer_agent \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:<same version as the server>
```

*Note for Mac Mini hosts:* If running Docker Desktop on macOS, the agent may need to connect to the internal virtual machine network. If standard routing fails, append `-e AGENT_CLUSTER_ADDR=host.docker.internal` to the command above and ensure "Allow default Docker socket" is checked in your Docker Desktop advanced settings.

Then in Portainer: Go to **Environments > Add environment > Docker Standalone > Agent**, and enter `<tailscale-ip-or-name-of-this-host>:9001`.

- The agent has full control of that host's Docker. Allow only the `portainer`
  node (the sidecar, not the host machine itself) to reach port 9001 with a Tailscale ACL.
- The sidecar's network namespace is what Portainer dials out from. In
  **userspace** mode (`TS_USERSPACE=true`) Portainer cannot open connections to
  tailnet addresses directly. If agents on other hosts show as down, switch the
  sidecar to tun mode (`TS_USERSPACE=false`, `devices: ["/dev/net/tun"]`,
  `cap_add: [NET_ADMIN]`).
- Keep the agent version in step with the server version.

## Per-host values and secrets

- Host-specific, non-secret values (`MEDIA_ROOT`, `TZ`, and so on) live in
  `hosts/<host>.env` in the repo as templates. In Portainer, load the matching
  file via **Load variables from .env file** when creating a stack.
- Secrets are entered in the stack's environment variables in Portainer, or
  supplied with `sops exec-env` for CLI-deployed stacks. Never commit them.
- Portainer stores these variables in its own database, so changing one means
  editing the stack's variables and redeploying. A git push alone does not
  change them.
- Avoid **Detach from Git** on a stack. It cannot be undone.

## Backup and restore

State lives in the `portainer-data` volume (users, environments, stack
settings, stored variables). Confirm the real volume name first:

```bash
docker volume ls | grep portainer
```

Back up (stop the stack first for a consistent copy):

```bash
docker compose down
docker run --rm -v portainer_portainer-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/portainer-data-$(date +%F).tgz -C /data .
docker compose up -d
```

Restore into an empty volume with the reverse `tar xzf`. Test a restore at
least once, and store backups off this machine.

## After a reboot

The primary host needs this to come back on its own:

1. The Docker daemon is set to start automatically at login or boot. The sidecar and Portainer then return via `restart: unless-stopped`.
2. `docker exec tailscale-portainer tailscale serve status` still shows the
   mapping.

The host's native Tailscale app is not required for this stack, since the sidecar acts as its own autonomous node.

## Troubleshooting

- **Portainer UI says setup timed out:** `docker compose restart portainer`,
  then create the admin user.
- **Page does not load, sidecar logs `connection refused` to
  `127.0.0.1:443`:** the serve config is not loaded. Check that `serve.json` is
  mounted at the path `TS_SERVE_CONFIG` names, then `docker compose up -d
  --force-recreate`.
- **"Connection is not private" on first visit:** the certificate is still
  being issued. Wait about 30 seconds, quit and reopen the browser, and use the
  URL with no port. Make sure HTTPS Certificates is enabled in the admin
  console.
- **Node shows up as `portainer-1`:** an old node with the same name is still
  registered. Delete the stale one in the admin console and keep
  `TS_STATE_DIR` persisted.
- **Sidecar will not join the tailnet:** check `docker logs
  tailscale-portainer` for `invalid key` (expired or used auth key) or
  `/dev/net/tun` errors.
- **Tailnet URL fails:** check `docker compose ps`, the sidecar logs, and
  `docker exec tailscale-portainer tailscale serve status`.
- **Target environment shows as down:** check Tailscale and Docker on the remote machine, the agent container state, the sidecar's networking mode (see the agent section), and verify that the Tailscale ACL allows the `portainer` node to reach port 9001.
