# Navidrome

Served on the tailnet as a Tailscale Service (`svc:navidrome`), not as a separate machine.

## Prerequisites

- Tailscale installed and logged in on the Docker host (macOS, Linux, or Windows).
  On Windows with WSL, use the Windows install, not one inside WSL.
- Navidrome publishes its port to localhost only (in `compose.yaml`):
  ```yaml
  ports:
    - "127.0.0.1:4533:4533"
  ```
- Verify first, on the host: `curl http://127.0.0.1:4533` responds.

## Setup

1. **Tag the host.** In the admin console, Access controls, add to `tagOwners`:
   ```json
   "tag:docker-host": ["autogroup:admin"],
   "tag:homelab-service": ["autogroup:admin"]
   ```
   Then Machines, `⋯`, Edit ACL tags, and apply `tag:docker-host` to the host.
   (On Linux you can instead run `sudo tailscale up --advertise-tags=tag:docker-host`.)

2. **Define the Service.** Admin console, Services, Advertise, Define a Service.
   Name: `navidrome`, port: 443, Service tag: `tag:homelab-service`.

3. **Advertise it from the host.** Run in a terminal on the host
   (use `sudo` on Linux/macOS, or an Administrator shell on Windows, if permissions are an issue):
   ```
   tailscale serve --service=svc:navidrome --https=443 127.0.0.1:4533
   tailscale serve status --json
   ```

4. **Approve the host.** Services, `navidrome`, approve the pending host.
   Or skip this in future with an auto-approver in the ACL:
   ```json
   "autoApprovers": {
     "services": {
       "tag:homelab-service": ["tag:docker-host"]
     }
   }
   ```

Access it at `https://navidrome.<tailnet>.ts.net`.

## Remove

```
tailscale serve drain svc:navidrome
tailscale serve --service=svc:navidrome --https=443 127.0.0.1:4533 off
```
Then delete the Service definition in the admin console.

## Notes

- Service names must be unique across hosts, or Tailscale treats them as redundant hosts.
- A 502 means nothing is answering on `127.0.0.1:4533`: check the published port.
