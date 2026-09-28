#!/bin/bash

set -euo pipefail

# ==============================
# Configuration
# ==============================

USERS=("$@")
GROUP="devops"
LOGIN_SHELL="/bin/bash"
LOG_FILE="/var/log/user_provisioning.log"
PUBLIC_KEY_FILE="/home/s13ludivine/.ssh/id_ed25519.pub"

# ==============================
# Logs
# ==============================

exec > >(tee -a "$LOG_FILE") 2>&1

# ==============================
# Vérification root
# ==============================

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Run this script with sudo"
    exit 1
fi

# ==============================
# Vérification de la clé publique
# ==============================

if [ ! -f "$PUBLIC_KEY_FILE" ]; then
    echo "[ERROR] Public key not found: $PUBLIC_KEY_FILE"
    exit 1
fi

echo
echo "================================"
echo " User Provisioning Script"
echo "================================"
echo

# ==============================
# Création du groupe
# ==============================

if getent group "$GROUP" > /dev/null 2>&1; then
    echo "[OK] Group $GROUP already exists"
else
    groupadd "$GROUP"
    echo "[OK] Group $GROUP created"
fi

# ==============================
# Création des utilisateurs
# ==============================

for USERNAME in "${USERS[@]}"
do

    echo
    echo "--------------------------------"
    echo "Processing: $USERNAME"
    echo "--------------------------------"

    # ==============================
    # Vérifier / créer utilisateur
    # ==============================

    if id "$USERNAME" > /dev/null 2>&1; then
        echo "[OK] User $USERNAME already exists"
    else
        useradd -m -s "$LOGIN_SHELL" "$USERNAME"
        echo "[OK] User $USERNAME created"
    fi

    # ==============================
    # Ajouter au groupe devops
    # ==============================

    usermod -aG "$GROUP" "$USERNAME"
    echo "[OK] $USERNAME added to $GROUP"

    # ==============================
    # Configuration du home
    # ==============================

    if [ ! -d "/home/$USERNAME" ]; then
        mkdir -p "/home/$USERNAME"
        echo "[OK] Home created for $USERNAME"
    fi

    chown "$USERNAME:$USERNAME" "/home/$USERNAME"
    chmod 700 "/home/$USERNAME"

    echo "[OK] Home configured"

    # ==============================
    # Configuration SSH
    # ==============================

    mkdir -p "/home/$USERNAME/.ssh"

    touch "/home/$USERNAME/.ssh/authorized_keys"

    chmod 700 "/home/$USERNAME/.ssh"
    chmod 600 "/home/$USERNAME/.ssh/authorized_keys"

    echo "[OK] SSH configured"
    echo "[OK] Public key installed"

    # ==============================
    # Validation complète
    # ==============================

    if ! id "$USERNAME" > /dev/null 2>&1; then
        echo "[ERROR] User $USERNAME does not exist"
        exit 1
    fi

    if ! id -nG "$USERNAME" | grep -qw "$GROUP"; then
        echo "[ERROR] $USERNAME is not in group $GROUP"
        exit 1
    fi

    if [ ! -d "/home/$USERNAME" ]; then
        echo "[ERROR] Home missing for $USERNAME"
        exit 1
    fi

    if [ ! -d "/home/$USERNAME/.ssh" ]; then
        echo "[ERROR] SSH directory missing for $USERNAME"
        exit 1
    fi

    if [ ! -f "/home/$USERNAME/.ssh/authorized_keys" ]; then
        echo "[ERROR] authorized_keys missing for $USERNAME"
        exit 1
    fi

    echo "[SUCCESS] $USERNAME passed all checks"

done

echo
echo "================================"
echo " Provisioning completed"
echo "================================"
echo    cat "$PUBLIC_KEY_FILE" > "/home/$USERNAME/.ssh/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"


