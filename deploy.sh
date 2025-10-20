#!/bin/bash
echo "Welcome to My Cool Keeds Automated Deployment Using bash Script Instead of Terraform and Ansible "

read -p "Enter your GitHub repository URL: " REPO_URL
read -p "Enter your Personal Access Token (PAT): " PAT
read -p "Enter the branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter remote server username: " SSH_USER
read -p "Enter remote server IP address: " SERVER_IP
read -p "Enter path to your SSH private key: " SSH_KEY
read -p "Enter your application internal port (e.g., 5000): " APP_PORT


if [[ -z "$REPO_URL" || -z "$PAT" || -z "$SSH_USER" || -z "$SERVER_IP" || -z "$SSH_KEY" || -z "$APP_PORT" ]]; then
    echo "❌ Error: Missing required input(s). Please provide all details."
    exit 1
fi



echo ""
echo "--------------------------------------"
echo "✅ Deployment Configuration Summary:"
echo "Repository URL: $REPO_URL"
echo "Branch: $BRANCH"
echo "Server: $SSH_USER@$SERVER_IP"
echo "SSH Key Path: $SSH_KEY"
echo "App Port: $APP_PORT"
echo "--------------------------------------"
echo ""

read -p "Do you want to continue with these settings? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "🚫 Deployment cancelled by user."
    exit 0
fi


