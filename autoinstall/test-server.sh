#!/bin/bash

# Script to test Ubuntu autoinstall server
# Checks if the container is serving files at the correct locations

set -e

BASE_URL="http://localhost:8080"
TIMEOUT=10

# Function to get LAN IP address
get_lan_ip() {
    # Try multiple methods to get the LAN IP
    local lan_ip=""
    
    # Method 1: ip route (most reliable)
    if command -v ip >/dev/null 2>&1; then
        lan_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi
    
    # Method 2: hostname -I (fallback)
    if [[ -z "$lan_ip" ]] && command -v hostname >/dev/null 2>&1; then
        lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    # Method 3: ifconfig (fallback)
    if [[ -z "$lan_ip" ]] && command -v ifconfig >/dev/null 2>&1; then
        lan_ip=$(ifconfig 2>/dev/null | grep -E 'inet.*broadcast' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
    fi
    
    # Return the IP or fallback message
    if [[ -n "$lan_ip" && "$lan_ip" != "127.0.0.1" ]]; then
        echo "$lan_ip"
    else
        echo "Unable to detect LAN IP"
    fi
}

# Get LAN IP for later use
LAN_IP=$(get_lan_ip)
LAN_BASE_URL="http://${LAN_IP}:8080"

# Detect container runtime
CONTAINER_CMD=""
if command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found!"
    echo "Please install one of the following:"
    echo "  - Podman: sudo apt install podman"
    echo "  - Docker: sudo apt install docker.io"
    exit 1
fi

echo "=== Ubuntu Autoinstall Server Health Check ==="
echo "Using container runtime: $CONTAINER_CMD"
echo "Testing server at: $BASE_URL"
echo

# Function to test URL with curl
test_url() {
    local url="$1"
    local description="$2"
    local expected_content="$3"
    
    echo -n "Testing $description... "
    
    if response=$(curl -s --connect-timeout $TIMEOUT --max-time $TIMEOUT "$url" 2>/dev/null); then
        if [[ -n "$expected_content" && "$response" == *"$expected_content"* ]]; then
            echo "✓ PASS (content verified)"
        elif [[ -n "$expected_content" ]]; then
            echo "✗ FAIL (content mismatch)"
            echo "  Expected to contain: $expected_content"
            echo "  Got: ${response:0:100}..."
            return 1
        else
            echo "✓ PASS (accessible)"
        fi
        return 0
    else
        echo "✗ FAIL (not accessible)"
        return 1
    fi
}

# Test if container is running
echo "Checking if container is running..."
if $CONTAINER_CMD ps --format "table {{.Names}}\t{{.Status}}" | grep -q "ubuntu-autoinstall-server"; then
    echo "✓ Container 'ubuntu-autoinstall-server' is running"
else
    echo "✗ Container 'ubuntu-autoinstall-server' is not running"
    if [[ "$CONTAINER_CMD" == "podman" ]]; then
        echo "  Run: podman-compose up -d"
        echo "  Or:  podman compose up -d (if using podman 4.x+)"
        echo "  From: $(dirname "$0")/.."
    else
        echo "  Run: docker compose up -d"
        echo "  From: $(dirname "$0")/.."
    fi
    exit 1
fi
echo

# Test server root
test_url "$BASE_URL/" "server root"

# Test meta-data file
test_url "$BASE_URL/meta-data" "meta-data file"

# Test user-data file (check for autoinstall signature)
echo -n "Testing user-data file... "
if response=$(curl -s --connect-timeout $TIMEOUT --max-time $TIMEOUT "$BASE_URL/user-data" 2>/dev/null); then
    if [[ "$response" == *"#cloud-config"* ]]; then
        echo "✓ PASS (content verified)"
    elif [[ "$response" == *"404 Not Found"* ]]; then
        echo "✗ FAIL (file not found)"
        echo "  The user-data file hasn't been generated yet."
        echo "  Run: ./generate-user-data.sh"
        echo "  This will create the user-data file from the template."
        USER_DATA_MISSING=true
    else
        echo "✗ FAIL (content mismatch)"
        echo "  Expected to contain: #cloud-config"
        echo "  Got: ${response:0:100}..."
    fi
else
    echo "✗ FAIL (not accessible)"
fi

echo
echo "=== Detailed File Content Check ==="

# Show user-data content (first few lines) only if file exists
if [[ "$USER_DATA_MISSING" != "true" ]]; then
    echo "user-data content preview:"
    curl -s "$BASE_URL/user-data" 2>/dev/null | head -10 | sed 's/^/  /'
else
    echo "user-data: File not generated yet"
    echo "  Run ./generate-user-data.sh to create it"
fi

echo
echo "meta-data content:"
curl -s "$BASE_URL/meta-data" 2>/dev/null | sed 's/^/  /'

echo
echo "=== Server Information ==="
echo "Local Access URLs:"
echo "  - Server root: $BASE_URL/"
echo "  - user-data:   $BASE_URL/user-data"
echo "  - meta-data:   $BASE_URL/meta-data"
echo
echo "LAN Access URLs (for other machines):"
if [[ "$LAN_IP" != "Unable to detect LAN IP" ]]; then
    echo "  - Server root: $LAN_BASE_URL/"
    echo "  - user-data:   $LAN_BASE_URL/user-data"
    echo "  - meta-data:   $LAN_BASE_URL/meta-data"
else
    echo "  - Could not detect LAN IP address"
    echo "  - Manually replace YOUR_IP: http://YOUR_IP:8080/"
fi

if [[ "$USER_DATA_MISSING" == "true" ]]; then
    echo
    echo "⚠️  SETUP REQUIRED:"
    echo "  1. Generate user-data file: ./generate-user-data.sh"
    echo "  2. Re-run this test: ./test-server.sh"
else
    echo
    echo "For Ubuntu autoinstall, use:"
    echo "  Local:  autoinstall ds=nocloud-net;s=$BASE_URL/"
    if [[ "$LAN_IP" != "Unable to detect LAN IP" ]]; then
        echo "  Remote: autoinstall ds=nocloud-net;s=$LAN_BASE_URL/"
    else
        echo "  Remote: autoinstall ds=nocloud-net;s=http://YOUR_IP:8080/"
    fi
fi

echo
echo "=== Health Check Complete ==="
