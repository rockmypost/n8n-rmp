# 🚀 N8N RockMyPost - Production Setup

Production-ready N8N deployment with Docker Compose, automatic SSL, and intelligent updates.

## ✨ Features

- 🔒 **Automatic SSL** with Let's Encrypt
- 🔄 **Smart updates** for both repository and N8N
- 💾 **Persistent data** - workflows never lost
- 🛡️ **Security hardened** with firewall
- 📊 **Health monitoring** built-in
- 🐳 **Multi-OS support** (Ubuntu, CentOS, Amazon Linux)
- 🌐 **Professional URLs** without ports

## 🚀 Quick Start

### Prerequisites
1. **Server**: Ubuntu/Debian/CentOS with 2GB+ RAM
2. **Domain**: DNS record `n8n.rockmypost.com` → `YOUR_SERVER_IP`
3. **Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS) open

### Option 1: Automated Setup (Recommended)
```bash
# Single command setup on clean server
curl -fsSL https://raw.githubusercontent.com/rockmypost/n8n-rmp/main/server-setup.sh -o server-setup.sh
sudo bash server-setup.sh

# After setup completes:
cd n8n-rmp
nano .env  # Configure your settings
./start.sh
```

### Option 2: Manual Setup
```bash
# Clone repository
git clone https://github.com/rockmypost/n8n-rmp.git
cd n8n-rmp

# Configure environment
cp .env.example .env
nano .env

# Start services
chmod +x start.sh
./start.sh
```

## 🔧 Configuration

### DNS Setup (Required)
```bash
# Create DNS A record:
n8n.rockmypost.com → YOUR_SERVER_IP

# Verify DNS:
nslookup n8n.rockmypost.com
```

### Environment Variables
Key variables in `.env`:
```bash
N8N_HOST=n8n.rockmypost.com          # Your domain
WEBHOOK_URL=https://n8n.rockmypost.com/    # Webhook endpoint
VUE_APP_URL=https://n8n.rockmypost.com/    # Frontend URL
N8N_OWNER_EMAIL=rockmypost@gmail.com       # Admin email
N8N_OWNER_PASSWORD=YourSecurePassword      # Admin password
LETSENCRYPT_EMAIL=rockmypost@gmail.com     # SSL notifications
```

## 🌐 Access

- **URL**: https://n8n.rockmypost.com
- **Admin**: rockmypost@gmail.com
- **Password**: (set in .env file)

## 📊 Management Commands

```bash
# Start/Update everything
./start.sh

# View logs
docker-compose logs -f                # All services
docker logs n8n_rockmypost -f       # N8N only
docker logs letsencrypt_rmp -f       # SSL only

# Stop services
docker-compose down

# Restart specific service
docker-compose restart n8n
```

## 🔒 SSL Information

- **Provider**: Let's Encrypt (free)
- **Auto-renewal**: Every 60 days
- **First setup**: Takes 2-5 minutes
- **Certificate location**: Docker volume `nginx_certs`

## 🗂️ File Structure

```
n8n-rmp/
├── docker-compose.yml    # Main configuration
├── .env                  # Environment (create from .env.example)
├── .env.example         # Environment template
├── server-setup.sh      # Initial server setup
├── start.sh            # Start/update script
└── README.md           # This file
```

## 🔄 Updates

The `start.sh` script automatically:
- ✅ Checks for repository updates
- ✅ Pulls latest N8N version
- ✅ Preserves all data and settings
- ✅ Handles SSL renewal
- ✅ Verifies service health

## 💾 Data Persistence

All data persists in Docker volumes:
- **N8N data**: `rockmypost_n8n_data` (workflows, credentials)
- **SSL certificates**: `nginx_certs`
- **Proxy config**: `nginx_vhost`, `nginx_html`

### Backup
```bash
# Backup N8N data
docker run --rm -v rockmypost_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data

# Restore backup
docker run --rm -v rockmypost_n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-backup-YYYYMMDD.tar.gz -C /
```

## 🔧 Google APIs Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project and enable APIs (Gmail, Drive, Sheets)
3. Create OAuth 2.0 credentials
4. Set redirect URI: `https://n8n.rockmypost.com/rest/oauth2-credential/callback`
5. Add credentials to `.env`:
   ```bash
   GOOGLE_OAUTH_CLIENT_ID=your-client-id
   GOOGLE_OAUTH_CLIENT_SECRET=your-client-secret
   ```
6. Restart: `./start.sh`

## 🚨 Troubleshooting

### SSL Issues
```bash
# Check SSL logs
docker logs letsencrypt_rmp

# Verify DNS
nslookup n8n.rockmypost.com

# Test connectivity
curl -I https://n8n.rockmypost.com
```

### Service Issues
```bash
# Check all services
docker-compose ps

# Restart everything
./start.sh

# View detailed logs
docker-compose logs
```

### Common Issues

**"Certificate request failed"**
- Verify DNS points to server IP
- Ensure ports 80/443 are open
- Wait 5-10 minutes for DNS propagation

**"N8N not accessible"**
- Check if services are running: `docker ps`
- Verify firewall allows ports 80/443
- Check logs: `docker logs n8n_rockmypost`

## 🏗️ Architecture

```
Internet → Nginx Proxy (SSL) → N8N Container
              ↓
          Let's Encrypt (SSL Certs)
              ↓
          Persistent Volumes (Data)
```

## 📝 Requirements

### Server Requirements
- **OS**: Ubuntu 18.04+, Debian 10+, CentOS 7+, Amazon Linux 2
- **RAM**: 2GB minimum, 4GB recommended
- **CPU**: 1 vCore minimum, 2+ recommended
- **Storage**: 20GB minimum, 50GB+ recommended
- **Network**: Public IP + domain name

### Software (Auto-installed)
- Docker CE 20.10+
- Docker Compose 2.0+
- Git, curl, wget
- UFW/Firewalld

## 📞 Support

- **Repository**: https://github.com/rockmypost/n8n-rmp
- **N8N Docs**: https://docs.n8n.io/
- **Issues**: Create issue in GitHub repository

## 📄 License

This project is open source. N8N has its own licensing terms.