# netcup

netcup's server API (SCP REST), its firewall model and the endpoints the handbook drives.
Script: [scripts/netcup.sh](../scripts/netcup.sh). Policies: [web server](../templates/netcup-firewall-web.json), [SSH-only host](../templates/netcup-firewall-ssh.json).
Steps: [provision-server.md](../guides/provision-server.md#provision-over-ssh), [maintenance.md](../guides/maintenance.md#verify), [backup-restore.md](../guides/backup-restore.md#restore).

## API

| Item | Value |
| --- | --- |
| Base | `https://www.servercontrolpanel.de/scp-core` |
| Spec | `GET /scp-core/api/v1/openapi`, public OpenAPI 3; version 2026.0923.125530 on 2026-10-04 |
| Health | `GET /scp-core/api/ping`, no token |
| Status | Stable since 2025-11-01; netcup switched the SOAP webservice off on 2026-05-01 |
| IP filter | SCP, REST API settings: the IPs or CIDRs allowed to call; empty allows all |
| Rate limits | None documented |
| `serverId` | An integer from `GET /servers`; the `v22…` server name is not the id |
| `userId` | Every `/users/{userId}/` path needs the SCP userId, an internal id, not the customer number |

## Auth

| Item | Value |
| --- | --- |
| Protocol | OpenID Connect, Keycloak realm `scp`, issuer `https://www.servercontrolpanel.de/realms/scp` |
| Device endpoint | `/realms/scp/protocol/openid-connect/auth/device` |
| Token endpoint | `/realms/scp/protocol/openid-connect/token` |
| Client | Public `client_id=scp`, no secret; scopes `openid offline_access` |
| Headless use | One device-flow login; the refresh token then buys short-lived access tokens, sent as `Bearer` |
| 30-day rule | The refresh token stays valid while it is used at least once every 30 days |
| Revoke | `/realms/scp/account`, Applications, `scp`, Remove access; a password change revokes nothing |
| Reach | No scopes, no API keys: one token powers off, reinstalls, reverts and opens every server on the account |
| Token home | The laptop only: `~/.config/netcup/refresh-token`, mode 0600. Never on a server |
| 2FA | Unresolved: a forum report (June 2026) has the device login fail with CCP 2FA on. Test it first |
| `userId` lookup | `netcup.sh` reads the newest task's `executingUser.id`, else the token's `id` claim; `NETCUP_USER_ID` overrides |

## Firewall model

| Rule | Consequence |
| --- | --- |
| Policies are account-wide objects | One policy attaches to many server interfaces; an update reaches all of them |
| Rules run top to bottom, first match wins | netcup's default policies stay above the user policy |
| Saving applies at once | Established connections stay up |
| State is tracked for TCP only | UDP replies need their own rule, such as NTP replies from source port 123 |
| The implicit rule flips | `ACCEPT_ALL` per direction until a custom rule exists there, then `DROP_ALL` |
| netcup's fixed rules pass DNS | DNS to netcup's resolvers passes whatever the policies say |
| Default policies on a new server | `netcup Mail block` drops outbound TCP 25, 465 and 587; `netcup Ping allow` accepts inbound ICMP and ICMPv6 and outbound ICMP |
| Restore Default Policies brings them back | API: `POST …/firewall:restore-copied-policies` |
| 500 rules per server interface | Keep policies short; each server interface has its own budget |
| The undo is the per-server Firewall active switch | API: `PUT …/firewall` with `active: false` |
| A web server gets no egress rule | One egress rule flips egress to `DROP_ALL`: provider APIs, GitHub and image pulls fail |
| Keep `netcup Ping allow` attached | Inference: under ingress `DROP_ALL` it is what admits ICMPv6, which IPv6 needs |
| Docker-published ports bypass ufw | The provider firewall is the outer wall for the proxy's 80 and 443 |

## Policies

| Template | Host | Inbound accepted |
| --- | --- | --- |
| [netcup-firewall-web.json](../templates/netcup-firewall-web.json) | Web server | TCP 22, 80, 443; UDP 443 (HTTP/3); UDP from port 123 |
| [netcup-firewall-ssh.json](../templates/netcup-firewall-ssh.json) | SSH-only host, such as a backup puller | TCP 22; UDP from port 123 |

Both end in `INGRESS TCP DROP` and `INGRESS UDP DROP`, so nothing hangs on the implicit rule.

## Endpoints

Paths sit under `/scp-core/api/v1`. A mutation answers `202` with a TaskInfo; poll `GET /tasks/{uuid}` until `FINISHED`.

| Area | Method and path | Notes |
| --- | --- | --- |
| Policies | `GET`, `POST /users/{userId}/firewall-policies` | Body `FirewallPolicySave`: `name` (required), `description`, `rules` |
| Policies | `GET`, `PUT`, `DELETE /users/{userId}/firewall-policies/{id}` | `PUT` answers the policy plus a task for attached servers |
| Server firewall | `GET`, `PUT /servers/{serverId}/interfaces/{mac}/firewall` | Body `copiedPolicies` and `userPolicies` as `[{id}]`, `active`; `GET ?consistencyCheck=true` fills `consistent` |
| Server firewall | `POST …/firewall:reapply` | After an update timed out behind a long storage write |
| Server firewall | `POST …/firewall:restore-copied-policies` | Restores netcup's default policies |
| Servers | `GET /servers`, `GET /servers/{serverId}` | Detail: state, IPs, `snapshotCount`, `rescueSystemActive`, `serverLiveInfo.interfaces[].mac` |
| Servers | `PATCH /servers/{serverId}` | `application/merge-patch+json`, one attribute per call: power state, hostname, nickname |
| Snapshots | `GET`, `POST /servers/{serverId}/snapshots`; `POST …/snapshots:dryrun` | The dry run answers an empty list when a snapshot is possible |
| Snapshots | `GET`, `DELETE …/snapshots/{name}`; `POST …/{name}/revert`, `…/{name}/export` | Revert returns the server's disk to the snapshot |
| Rescue | `GET`, `POST`, `DELETE /servers/{serverId}/rescuesystem` | Boots the rescue system |
| Image install | `POST /servers/{serverId}/image` | Erases the disk; `imageFlavourId`, `sshKeyIds`, `hostname`, `customScript` |
| rDNS | `POST /rdns/ipv4`, `GET`, `DELETE /rdns/ipv4/{ip}`; the same under `ipv6` | Reverse DNS per address |
| Metrics | `GET /servers/{serverId}/metrics/cpu`, `…/disk`, `…/network` | `hours` up to 1440 |
| SSH keys | `GET`, `POST /users/{userId}/ssh-keys`, `DELETE …/{id}` | The keys an image install injects |
| Tasks | `GET /tasks`, `GET /tasks/{uuid}`, `PUT /tasks/{uuid}:cancel` | States `PENDING`, `RUNNING`, `FINISHED`, `ERROR`, `CANCELED`, `ROLLBACK` |

Whether `customScript` runs as root at first boot is unverified.

## Snapshots are not backups

| Fact | Consequence |
| --- | --- |
| A snapshot lives on netcup's storage beside the server | A loss on netcup's side takes server and snapshot together |
| A running database snapshots crash-consistent | The restored database replays its WAL like after a power cut |
| A snapshot fits the step back before risky host work | Backups are the dumps of [backup-restore.md](../guides/backup-restore.md) |

## DNS records

DNS records live in a separate API, netcup's domain (CCP) API, not in SCP REST.

| Item | Value |
| --- | --- |
| Endpoint | `https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON` |
| Auth | Customer number, API key and API password, all from the CCP |
| Hazard | `updateDnsRecords` replaces the whole record set: send every record, not only the changed one |

## Community tooling

None of it is official.

- [rixlhq/terraform-provider-netcup](https://github.com/rixlhq/terraform-provider-netcup): Terraform provider on SCP REST, firewall resources included.
- [pavelpikta/netcup-scp-cli](https://github.com/pavelpikta/netcup-scp-cli): Python CLI.
- [pr0ton11/netcup-scp-go](https://github.com/pr0ton11/netcup-scp-go): Go client.
- [mrueg/netcupscp-exporter](https://github.com/mrueg/netcupscp-exporter): Prometheus exporter; its `get-refresh-token.sh` shows the device flow.

Sources, retrieved 2026-10-04: [REST API](https://www.netcup.com/en/helpcenter/documentation/server/rest-api), [firewall](https://www.netcup.com/en/helpcenter/documentation/server/firewall), [OpenAPI spec](https://www.servercontrolpanel.de/scp-core/api/v1/openapi), [CCP API](https://netcup.com/en/helpcenter/documentation/domain/our-api), [netcup forum](https://forum.netcup.de/) (thread 22368, the 2FA report).
