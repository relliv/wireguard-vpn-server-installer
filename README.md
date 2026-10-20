# WireGuard VPN Server

A simple [WireGuard](https://www.wireguard.com/) VPN server using [wg-easy](https://github.com/wg-easy/wg-easy) v15.

> [!NOTE]  
> If you are looking for Amnezia version, check [Amnezia WireGuard VPN Server](https://github.com/relliv/amnezia-wireguard-vpn-server-installer) repository.

## 🌐 Access Web UI

```txt
http://SERVER_IP:51821
```

### Login

Use the admin username and password you set during installation.

### Add Client

Add client with '+ New Client' button then scan QR code or download configuration file.

### Client Apps

Install official client apps from [WireGuard](https://www.wireguard.com/install/?locale=en) website. Then use your client QR or configuration file to connect to the VPN.

> [!WARNING]  
> The web UI is served over plain HTTP (`INSECURE=true`), so the admin login can be intercepted by third parties. Use only for **development purposes**, or put the web UI behind an HTTPS reverse proxy and set `INSECURE=false`.

## 📋 Requirements

- Docker & Docker Compose
- curl
- Server with public IP
- Ports 51820/UDP and 51821/TCP open
- amd64 or arm64 host (wg-easy v15 does not support armv6/armv7)

## 🚀 Installation

### Quick Installation

```bash
chmod +x install.sh
./install.sh
```

The installer asks for the server IP, admin username and password, starts the container with an unattended setup, then removes the plain text password from `.env` and the container environment.

### Manual Installation

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd wireguard-server-installer
   ```

2. Configure environment:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set:
   - `SERVER_IP`: Your server's public IP address or domain
   - `ADMIN_USERNAME`: Admin panel username
   - `ADMIN_PASSWORD`: Strong password for admin panel (wrap it in single quotes)

3. Start the server:

   ```bash
   docker compose up -d
   ```

4. After the web UI is reachable, edit `.env` again: set `INIT_ENABLED=false` and clear `ADMIN_PASSWORD`. Then recreate the container so the password is gone from its environment:

   ```bash
   docker compose up -d
   ```

Now you can access the admin panel.

> [!TIP]  
> If you skip `ADMIN_USERNAME`/`ADMIN_PASSWORD` and leave `INIT_ENABLED=false`, the web UI opens a setup wizard on the first visit instead.

## 📖 Usage

1. Access admin panel: `http://<SERVER_IP>:51821`
2. Login with your configured username and password
3. Create a new client and download/scan the QR code
4. Import configuration into WireGuard client app

DNS, address ranges, MTU and other settings are managed in the web UI under **Admin Panel**.

## 🔌 Ports

| Port  | Protocol | Purpose         |
|-------|----------|-----------------|
| 51820 | UDP      | WireGuard VPN   |
| 51821 | TCP      | Web Admin UI    |

## ⌨️ Commands

```bash
# Start
docker compose up -d

# Stop
docker compose stop

# View logs
docker compose logs -f

# Restart
docker compose restart

# Update to the latest v15 release
docker compose pull && docker compose up -d

# Reset admin password
docker exec -it my_wireguard cli db:admin:reset
```

> [!IMPORTANT]  
> `docker compose down` keeps your data, since the volume `my_wireguard_data` survives. `docker compose down -v` deletes the volume and you will lose all clients and settings.

## ⬆️ Upgrading from v14

Older versions of this repo used wg-easy v14 (`WG_HOST`, `PASSWORD_HASH`, `wgpw`). v15 is a full rewrite and none of those variables are used anymore.

1. Download a backup from the old web UI, or copy `wg0.json` out of the volume:

   ```bash
   docker cp my_wireguard:/etc/wireguard/wg0.json ./wg0.json
   ```

2. Stop the old stack and remove the old volume:

   ```bash
   docker compose down -v
   ```

3. Pull this repo, recreate `.env` from `.env.example` with `INIT_ENABLED=false`, and start:

   ```bash
   docker compose up -d
   ```

4. Open the web UI, pick "I already have a configuration file" in the setup wizard and upload `wg0.json`.
