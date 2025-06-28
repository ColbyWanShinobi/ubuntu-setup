# Ubuntu Setup with Autoinstall

This repository contains configuration files for automated Ubuntu installation with BTRFS filesystem using disk serial number identification.

## Configuration

The installation can be customized using environment variables:

- `TEMPLATE_HOSTNAME`: The hostname for the installed system (default: `ubuntu-btrfs`)
- `TEMPLATE_USERNAME`: The username for the main user account (default: `picard`) 
- `TEMPLATE_PASSWORD_HASH`: SHA-512 hashed password (generated automatically)
- `TEMPLATE_DISK_SERIAL`: Serial number of the target installation disk (required)

### Disk Serial Number

The autoinstall configuration identifies the target disk by its serial number for safety and precision. The script will help you find available disk serial numbers.

### Generating a Password Hash

The main script now handles password hashing automatically. However, if you need to generate a hash manually, you can still use:

```bash
cd autoinstall
./generate-password-hash.sh
```

## Usage

### Interactive Mode (Recommended)

Run the script and it will prompt you for all required values:

```bash
cd autoinstall
./generate-user-data.sh
```

The script will ask for:
- Hostname (default: `ubuntu-btrfs`)
- Username (default: `picard`)
- Disk serial number (shows available disks)
- Password (will be automatically hashed)

### Using Environment Variables

You can also set environment variables to skip prompts:

```bash
cd autoinstall
export TEMPLATE_HOSTNAME="my-server"
export TEMPLATE_USERNAME="john"
export TEMPLATE_DISK_SERIAL="WD-WX12A2345678"
export TEMPLATE_PASSWORD_HASH='$6$your_generated_hash_here'
./generate-user-data.sh
```

### One-line with Environment Variables

```bash
cd autoinstall
TEMPLATE_HOSTNAME="my-server" TEMPLATE_USERNAME="john" TEMPLATE_DISK_SERIAL="WD-WX12A2345678" TEMPLATE_PASSWORD_HASH='$6$...' ./generate-user-data.sh
```

## Files

- `autoinstall/generate-user-data.sh`: Main script to generate user-data from template
- `autoinstall/www/user-data.template`: Template file with variables  
- `autoinstall/www/user-data`: Generated configuration file (created by script)
- `autoinstall/www/meta-data`: Metadata file for cloud-init
- `autoinstall/nginx.conf`: Nginx configuration for serving files
- `autoinstall/Containerfile`: Container configuration for nginx server
- `autoinstall/compose.yml`: Docker/Podman compose configuration
- `autoinstall/test-server.sh`: Script to test the autoinstall server
- `autoinstall/generate-password-hash.sh`: Helper script to generate password hashes

## Container Usage

### Using Docker Compose / Podman Compose

The recommended way to serve autoinstall files:

```bash
cd autoinstall

# 1. Generate user-data configuration
./generate-user-data.sh

# 2. Start the server (using podman or docker)
podman compose up -d
# or: docker compose up -d

# 3. Test the server
./test-server.sh

# 4. Access files at:
# - http://localhost:8080/user-data
# - http://localhost:8080/meta-data
```

### Manual Container Commands

If you prefer manual container management:

```bash
cd autoinstall

# Generate user-data first
./generate-user-data.sh

# Build container
podman build -t ubuntu-autoinstall .

# Run with volume mounts for live updates
podman run -d -p 8080:80 \
  -v ./www:/usr/share/nginx/html:ro \
  -v ./nginx.conf:/etc/nginx/nginx.conf:ro \
  --name ubuntu-autoinstall-server \
  ubuntu-autoinstall
```

## Testing

Test that the server is working correctly:

```bash
cd autoinstall
./test-server.sh
```

This will verify:
- Container is running
- Files are accessible via HTTP
- user-data contains valid autoinstall configuration
- meta-data is served correctly

## Ubuntu Installation

Use the server during Ubuntu installation by adding this to the boot parameters:

```
autoinstall ds=nocloud-net;s=http://YOUR_SERVER_IP:8080/
```

Replace `YOUR_SERVER_IP` with the IP address of the machine running the container.
