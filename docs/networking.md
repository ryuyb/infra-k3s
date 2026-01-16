# Networking

## Tailscale Mesh

All cluster communication uses Tailscale's encrypted mesh network. Each node gets a stable 100.x.x.x IP that persists across reboots and provider changes.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Hetzner    │     │    Vultr     │     │     AWS      │
│  Public IP   │     │  Public IP   │     │  Public IP   │
│  5.x.x.x     │     │  45.x.x.x    │     │  3.x.x.x     │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    Tailscale Mesh (WireGuard)
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
┌──────┴───────┐     ┌──────┴───────┐     ┌──────┴───────┐
│  100.64.0.1  │◄───►│  100.64.0.2  │◄───►│  100.64.0.3  │
│   (master)   │     │   (worker)   │     │   (worker)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

## IP Resolution

Ansible dynamically resolves connection IPs:

```yaml
# inventory/group_vars/all.yml
ansible_host: "{{ tailscale_ip | default(public_ip) }}"
```

- **Bootstrap**: Uses `public_ip` (Tailscale not yet installed)
- **Post-bootstrap**: Uses `tailscale_ip` (secure mesh)

## Firewall Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Any | SSH (initial access) |
| 41641 | UDP | Any | Tailscale WireGuard |
| 6443 | TCP | Tailscale only | K3s API server |
| 10250 | TCP | Tailscale only | Kubelet |
| 80 | TCP | Any | HTTP ingress |
| 443 | TCP | Any | HTTPS ingress |

## K3s Network Configuration

K3s API server binds to Tailscale IP:

```yaml
# k3s-config.yaml
node-ip: "{{ tailscale_ip }}"
advertise-address: "{{ tailscale_ip }}"
tls-san:
  - "{{ tailscale_ip }}"
  - "{{ inventory_hostname }}"
```

Workers join via master's Tailscale IP:

```yaml
# k3s-agent-config.yaml
server: "https://{{ hostvars[groups['k3s_masters'][0]]['tailscale_ip'] }}:6443"
```

## Tailscale Features Used

- **MagicDNS**: Hostname resolution within mesh
- **Tailscale SSH**: Secure SSH without exposing port 22
- **ACLs**: Optional access control between nodes

## Troubleshooting

Check Tailscale status:
```bash
tailscale status
tailscale ping <hostname>
```

Verify K3s connectivity:
```bash
kubectl get nodes -o wide  # Should show Tailscale IPs
```

Test cross-node communication:
```bash
# From master
curl https://100.64.0.2:10250/healthz -k
```
