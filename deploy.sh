#!/bin/bash

set -e 
set -u  
set -o pipefail   


LOG_FILE="deploy_$(date +%Y%m%d).log"
log() {
  echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

handle_error() {
  log "ERROR: $1"
  exit 1
}


read -p "GitHub Repository URL: " REPO_URL
read -s -p "Personal Access Token: " PAT; echo
read -p "Branch (default: main): " BRANCH
read -p "SSH Username: " SSH_USER
read -p "Server IP: " SERVER_IP
read -p "SSH Key Path (default: ~/.ssh/id_rsa): " SSH_KEY
read -p "App Internal Port (e.g. 5000): " APP_PORT

BRANCH=${BRANCH:-main}
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}


[[ -z "$REPO_URL" ]] && handle_error "Repository URL is required."
[[ -z "$PAT" ]] && handle_error "Personal Access Token is required."
[[ -z "$SSH_USER" ]] && handle_error "SSH username is required."
[[ -z "$SERVER_IP" ]] && handle_error "Server IP is required."
[[ -z "$APP_PORT" ]] && handle_error "App port is required."

# ===== Clone Repository =====
log "Cloning repo..."
if [ -d "repo" ]; then
  cd repo && git pull || handle_error "Failed to pull repo."
else
  AUTH_URL="${REPO_URL/https:\/\//https:\/\/${PAT}@}"
  git clone "$AUTH_URL" repo || handle_error "Failed to clone repo."
  cd repo
fi
git checkout "$BRANCH" || handle_error "Branch not found."

# ===== Detect Docker Setup =====
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
  DEPLOY_TYPE="compose"
elif [ -f "Dockerfile" ]; then
  DEPLOY_TYPE="dockerfile"
else
  handle_error "No Docker configuration found."
fi

# ===== Test SSH Connection =====
log "Testing SSH connection..."
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo Connected" \
  || handle_error "SSH connection failed."

# ===== Prepare Remote Server =====
log "Preparing remote environment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
set -e
sudo apt update -y
sudo apt install -y docker.io
sudo apt install  -y 
sudo apt install -y docker-compose
sudo apt install -y nginx
sudo systemctl enable --now docker
sudo usermod -aG docker \$USER
EOF

# ===== Transfer Files =====
log "Copying files..."
rsync -avz --exclude '.git' ./ "$SSH_USER@$SERVER_IP:/home/$SSH_USER/app" || handle_error "File transfer failed."

# ===== Deploy Application =====
log "Deploying app..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
set -e
cd ~/app
if [ "$DEPLOY_TYPE" = "compose" ]; then
  sudo docker-compose down || true
  sudo docker-compose up -d --build
else
  sudo docker build -t myapp .
  sudo docker run -d -p $APP_PORT:$APP_PORT myapp
fi
EOF

# ===== Configure Nginx =====
log "Setting up Nginx as a proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash <<EOF
sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<NGINXCONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINXCONF'
sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp
sudo nginx -t && sudo systemctl reload nginx
EOF

# ===== Validate Deployment =====
log "Checking services..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "
sudo systemctl status docker --no-pager;
sudo systemctl status nginx --no-pager;
sudo curl -I http://localhost:80 || exit 1
"

log "Deployment complete. Visit: http://$SERVER_IP"
exit 0
