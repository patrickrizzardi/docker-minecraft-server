# Docker Minecraft Server & Proxy

A complete Docker setup for running Minecraft servers with optional Velocity proxy support. Features enhanced logging, health checks, and easy configuration management.

## 🚀 Quick Start

### Option 1: Standalone Server

```bash
# Start just the Minecraft server
docker compose -f docker-compose-standalone-server-setup.yml up -d

# View logs
docker compose -f docker-compose-standalone-server-setup.yml logs -f server
```

### Option 2: Proxy + Server Setup

```bash
# Start both proxy and server
docker compose -f docker-compose-proxy-setup.yml up -d

# View logs
docker compose -f docker-compose-proxy-setup.yml logs -f
```

## 📁 Project Structure

```
docker-minecraft/
├── server/                    # Paper Minecraft Server
│   ├── Dockerfile            # Server container build
│   ├── entrypoint.sh         # Enhanced logging entrypoint
│   ├── scripts/              # Server management scripts
│   └── log4j2.xml           # Log rotation configuration
├── proxy/                     # Velocity Proxy
│   ├── Dockerfile            # Proxy container build
│   ├── entrypoint.sh         # Enhanced logging entrypoint
│   ├── scripts/              # Proxy management scripts
│   └── log4j2.xml           # Log rotation configuration
├── docker-compose-proxy-setup.yml      # Full setup (proxy + server)
├── docker-compose-standalone-server-setup.yml  # Server only
└── README.md                 # This file
```

## 🛠️ Setup Instructions

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for containers
- Port 25565 available on your host

### 1. Clone and Build

```bash
git clone <your-repo>
cd docker-minecraft

# Build both images
docker compose -f docker-compose-proxy-setup.yml build
```

### 2. Choose Your Setup

#### Standalone Server Setup

Perfect for single-server setups or testing.

```bash
# Start the server
docker compose -f docker-compose-standalone-server-setup.yml up -d

# Check status
docker compose -f docker-compose-standalone-server-setup.yml ps

# View logs
docker compose -f docker-compose-standalone-server-setup.yml logs -f server
```

**Access**: Connect to `localhost:25565`

#### Proxy + Server Setup

Perfect for multi-server networks or production setups.

```bash
# Start both services
docker compose -f docker-compose-proxy-setup.yml up -d

# Check status
docker compose -f docker-compose-proxy-setup.yml ps

# View logs
docker compose -f docker-compose-proxy-setup.yml logs -f
```

**Access**: Connect to `localhost:25565` (proxy handles routing to backend servers)

## ⚙️ Configuration

### Environment Variables

#### Server Configuration

```yaml
environment:
  EULA: "true" # Required: Accept Minecraft EULA
  VERSION: "" # Optional: Specific MC version (e.g., '1.21')
  BUILD: "" # Optional: Specific Paper build (e.g., '130')
```

#### Proxy Configuration

```yaml
environment:
  VERSION: "" # Optional: Specific Velocity version (e.g., '3.4.0')
  BUILD: "" # Optional: Specific build number (e.g., '522')
```

### Volume Mounts

#### Server Volumes

```yaml
volumes:
  - minecraft-server:/minecraft # Server data (worlds, configs)
  - ./minecraft-config:/config # Persistent configs
  - ./minecraft-plugins:/minecraft/plugins # Server plugins
  # Optional: Custom worlds
  # - ./minecraft-world:/minecraft/world
  # - ./minecraft-world-nether:/minecraft/world_nether
  # - ./minecraft-world-the-end:/minecraft/world_the_end
```

#### Proxy Volumes

```yaml
volumes:
  - velocity-proxy:/velocity # Proxy data
  - ./velocity-config:/config # Persistent configs
  - ./velocity-plugins:/velocity/plugins # Proxy plugins
```

### Configuration Files

#### Server Configuration

- `server.properties` - Basic server settings
- `spigot.yml` - Spigot-specific settings
- `paper-global.yml` - Paper server settings
- `bukkit.yml` - Bukkit settings

#### Proxy Configuration

- `velocity.toml` - Main proxy configuration
- `forwarding.secret` - Security key for backend servers

## 🔧 Management Commands

### Container Management

```bash
# Start services
docker compose -f docker-compose-proxy-setup.yml up -d

# Stop services
docker compose -f docker-compose-proxy-setup.yml down

# Restart services
docker compose -f docker-compose-proxy-setup.yml restart

# View logs
docker compose -f docker-compose-proxy-setup.yml logs -f

# View specific service logs
docker compose -f docker-compose-proxy-setup.yml logs -f server
docker compose -f docker-compose-proxy-setup.yml logs -f proxy
```

### Server Management (Inside Container)

```bash
# Access server container
docker exec -it <container-name> bash

# Available commands inside container:
start        # Start the server
stop         # Stop the server gracefully
restart      # Restart the server
status       # Check server status
debug        # Attach to server console (Ctrl+B then D to detach)
```

## 📊 Monitoring & Health Checks

### Health Checks

Both services include enhanced health checks that verify:

- Process is running (tmux session exists)
- Service is accepting connections on port 25565
- Automatic restart if health checks fail

### Logging

#### Enhanced Logging Features

- **Automatic log rotation detection** - Handles when logs rotate seamlessly
- **Old log file handling** - Shows recent content from rotated logs
- **Docker logs integration** - All logs flow to `docker logs`
- **Multi-file monitoring** - Monitors all log files including compressed ones

#### Log Locations

- **Application logs**: Inside containers at `/minecraft/logs/` and `/velocity/logs/`
- **Docker logs**: Accessible via `docker logs <container-name>`

#### Log Rotation

- **Application level**: Rotates at 100MB, keeps 14 days (log4j2.xml)
- **Docker level**: Rotates at 100MB, keeps 5 files (docker-compose.yml)

## 🔌 Plugin Management

### Server Plugins

1. Place `.jar` files in `./minecraft-plugins/`
2. Restart the server: `docker compose restart server`
3. Plugin configs will be generated automatically

### Proxy Plugins

1. Place `.jar` files in `./velocity-plugins/`
2. Restart the proxy: `docker compose restart proxy`
3. Plugin configs will be generated automatically

**Note**: Use Velocity plugins for the proxy, not Bukkit/Spigot plugins.

## 🌐 Network Configuration

### Standalone Setup

- **Port**: 25565 (exposed to host)
- **Access**: `localhost:25565`

### Proxy + Server Setup

- **Proxy Port**: 25565 (exposed to host)
- **Server Port**: Internal only (not exposed)
- **Access**: `localhost:25565` (proxy handles routing)

### Backend Server Configuration

When using the proxy setup, configure your backend servers:

#### server.properties

```properties
online-mode=false
```

#### spigot.yml

```yaml
settings:
  bungeecord: false
```

#### paper-global.yml

```yaml
proxies:
  velocity:
    enabled: true
    secret: "your-forwarding-secret-here"
```

## 🚨 Troubleshooting

### Common Issues

#### Server Won't Start

```bash
# Check logs
docker compose logs server

# Check if EULA is accepted
docker exec <container> cat /minecraft/eula.txt
```

#### Can't Connect

```bash
# Check if port is open
netstat -tlnp | grep 25565

# Check container status
docker compose ps

# Check health status
docker inspect <container> | grep -A 10 Health
```

#### Logs Not Showing

```bash
# Check if log aggregator is running
docker exec <container> ps aux | grep log

# Check log directory
docker exec <container> ls -la /minecraft/logs/
```

### Performance Tuning

#### Memory Allocation

The server is configured with 12GB RAM by default. Adjust in `server/scripts/start.sh`:

```bash
# Change these values in start.sh
-Xms12G -Xmx12G
```

#### JVM Flags

The server uses Aikar's optimized JVM flags. These are already configured for optimal performance.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📚 Additional Resources

- [PaperMC Documentation](https://docs.papermc.io/)
- [Velocity Documentation](https://docs.papermc.io/velocity/)
- [Minecraft Server Properties](https://minecraft.wiki/w/Server.properties)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

**Happy Mining! ⛏️**
