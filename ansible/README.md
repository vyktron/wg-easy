# wg-easy Ansible Playbooks

This directory contains automation to deploy [wg-easy](https://github.com/vyktron/wg-easy) on remote hosts using Docker Compose.

## Prerequisites

- Ansible 2.12 or later.
- Access to the target hosts via SSH with privilege escalation (`become`).
- Docker Engine and the Compose v2 plugin installed on the target hosts.
- The [`community.docker`](https://galaxy.ansible.com/community/docker) collection available locally:

```bash
ansible-galaxy collection install community.docker
```

## Deploy `wg-easy`

1. Adjust your inventory to identify the hosts that should run wg-easy. You can start from `inventory.example.ini` and copy it to `inventory.ini`. For example:

   ```ini
   [wg_easy]
   vpn.example.com ansible_connection=ssh ansible_user=root

   [wg_easy:vars]
   wg_easy_init_password=ChangeThisPassword
   ```

2. Run the playbook directly or use the helper script:

   ```bash
   ./ansible/run-playbook.sh --ask-become-pass
   ```

   The script assumes your inventory lives at `ansible/inventory.ini`. Override it with `--inventory` or target specific hosts with `--limit`.

   To call Ansible directly:

   ```bash
   ansible-playbook ansible/playbooks/deploy-wg-easy.yml -i inventory.ini
   ```

The playbook uploads `docker-compose.vyk.yml` to `/opt/wg-easy/` (override with `wg_easy_project_path`) and uses the Compose plugin to ensure the stack is running. To customize the deployment, override any of the role variables:

- `wg_easy_project_path`: directory where the Compose project lives (`/opt/wg-easy` by default).
- `wg_easy_compose_filename`: Compose file name (`docker-compose.vyk.yml` by default).
- `wg_easy_compose_template`: path to the Compose template that will be rendered before deployment.
- `wg_easy_init_username`: admin username created during bootstrap (`admin` by default).
- `wg_easy_init_password`: admin password created during bootstrap (`change_me` by default—override this in your inventory or via `-e`).
- `wg_easy_init_host`: hostname or IP that the wg-easy UI should bind to (`0.0.0.0` by default).
- `wg_easy_init_port`: port that the wg-easy UI should listen on (`51821` by default).
- `wg_easy_init_dns`: DNS server to push to clients via WireGuard (`1.1.1.1` by default).
- `wg_easy_insecure`: whether to skip HTTPS enforcement for the web UI (`false` by default).
Example override:

```bash
ansible-playbook ansible/playbooks/deploy-wg-easy.yml -i inventory.ini \
   -e wg_easy_project_path=/srv/wg-easy \
   -e wg_easy_init_password=$(openssl rand -base64 24) \
   -e wg_easy_init_host=127.0.0.1 \
   -e wg_easy_init_port=8080
```

## Troubleshooting

If clients can connect to the WireGuard server but cannot access the internet, ensure that IP forwarding and NAT are correctly set up on the host running wg-easy.
---

### **1. Check IP forwarding**

```bash
sysctl net.ipv4.ip_forward
```

* If `0`, enable temporarily:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

---

### **2. Add NAT & forwarding rules**

```bash
sudo iptables -t nat -A POSTROUTING -o wlp0s20f3 -j MASQUERADE
sudo iptables -A FORWARD -i wg0 -o wlp0s20f3 -j ACCEPT
sudo iptables -A FORWARD -i wlp0s20f3 -o wg0 -m state --state ESTABLISHED,RELATED -j ACCEPT
```

---

### **3. Install persistence**

```bash
sudo apt update
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

### **4. Make forwarding permanent**

```bash
sudo nano /etc/sysctl.conf
```

* Ensure:

```text
net.ipv4.ip_forward = 1
```

* Apply:

```bash
sudo sysctl -p
```

---

### **5. Verify after reboot**

```bash
sudo reboot
sudo iptables -t nat -L -n -v
sudo iptables -L -n -v
sysctl net.ipv4.ip_forward
```

* MASQUERADE and FORWARD rules present ✔
* `net.ipv4.ip_forward = 1` ✔

