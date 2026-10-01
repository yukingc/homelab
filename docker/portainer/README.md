# Portainer (bootstrap stack)

Portainer Server for the homelab. It runs on the Mac mini and manages every
other stack, including those on the Beelink (via the Portainer Agent).

> **Rule: this stack is never deployed from Portainer itself.**
> It is the tool that manages the other stacks, so it is started and updated
> from the command line. Redeploying it from its own UI would cut off the
> session mid-deploy and could lock you out.

## How access works

```
browser --(tailnet)--> Mac mini Tailscale --(tailscale serve)--> 127.0.0.1:9443 --> Portainer
```

- Portainer publishes its HTTPS port on **loopback only** (`127.0.0.1:9443`),
  so nothing on the LAN can reach it directly.
- The host's Tailscale fronts it with `tailscale serve`, giving a valid
  certificate at `https://<mac-mini>.<tailnet>.ts.net`.
- This path does **not** depend on tsdproxy, so a broken tsdproxy deploy
  cannot lock you out.
- Last-resort access: sit at the Mac mini and open `https://localhost:9443`
  (expect a self-signed certificate warning).

The compose file in this folder is expected to contain:

- `name: portainer` at the top (keeps volume names stable)
- a pinned image version, not `latest`
- `restart: unless-stopped`
- `ports: ["127.0.0.1:9443:9443"]`
- the Docker socket mount and a `portainer-data` volume mounted at `/data`

## First-time setup

1. Start the stack (from this folder):
   ```bash
   docker compose up -d
   ```
2. Check it is listening locally: open `https://localhost:9443` and create the
   admin user. Do this promptly, since an unconfigured Portainer times out its
   initial setup and needs a restart.
3. Expose it on the tailnet (once; `--bg` makes it persistent):
   ```bash
   tailscale serve --bg https+insecure://127.0.0.1:9443
   tailscale serve status
   ```
   Flags can differ between Tailscale versions. If the command is rejected,
   check `tailscale serve --help`.
4. Open `https://<mac-mini>.<tailnet>.ts.net`.

To remove the serve mapping later: `tailscale serve reset`.

## Day-to-day

```bash
docker compose ps
docker compose logs -f portainer

# Upgrade: bump the pinned image tag in compose.yaml, then
docker compose pull
docker compose up -d
```

## Adding another host (Portainer Agent)

On the new machine (Linux, or Docker inside WSL2 on the Beelink):

```yaml
services:
  agent:
    image: portainer/agent:<same version as the server>
    restart: unless-stopped
    ports:
      - "<tailscale-ip-of-this-host>:9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
```

Then in Portainer: **Environments > Add environment > Docker Standalone >
Agent**, and enter `<tailscale-ip-or-name>:9001`.

- The agent has full control of that host's Docker. Allow only the Mac mini to
  reach port 9001 with a Tailscale ACL.
- If binding to the Tailscale IP fails (for example Docker starts before
  Tailscale does), publish `9001:9001` and rely on the ACL instead.
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

The Mac mini needs these to come back on their own:

1. Tailscale is running (the macOS app starts at login, so check that
   auto-login or an equivalent is set up).
2. Docker (Docker Desktop, OrbStack, or Colima) is set to start at login or
   boot. Portainer then returns via `restart: unless-stopped`.
3. `tailscale serve status` still shows the mapping.

## Troubleshooting

- **Portainer UI says setup timed out:** `docker compose restart portainer`,
  then create the admin user.
- **Tailnet URL fails but `https://localhost:9443` works:** check
  `tailscale status` and `tailscale serve status`.
- **Both fail:** check `docker compose ps` and the logs.
- **Beelink environment shows as down:** check Tailscale and Docker on the
  Beelink, the agent container, and that the ACL allows the Mac mini to reach
  port 9001.
