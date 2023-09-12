#!/bin/bash

# Fonction pour afficher une question en jaune
function ask_question() {
  echo -e "\033[33m$1\033[0m"
}

# Fonction pour créer un répertoire s'il n'existe pas
function create_directory() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

# Chemin par défaut pour le fichier .env
env_file_path="/home/$(logname)"
env_file="$env_file_path/.env"

# Si le fichier .env existe, afficher le contenu des variables et permettre la modification
if [ -f "$env_file" ]; then
  echo "Le fichier .env existe déjà. Voici son contenu :"
  cat "$env_file"
  ask_question "Souhaitez-vous modifier les variables ? (O/N) "
  read modify_choice

  if [ "$modify_choice" == "O" ] || [ "$modify_choice" == "o" ]; then
    echo "Veuillez fournir les informations suivantes :"
  else
    echo "La configuration existante sera conservée. Sortie du script."
    exit 0
  fi
else
  echo "Fichier .env sera enregistré à : $env_file"
  echo "Veuillez fournir les informations suivantes :"
fi

# Demander à l'utilisateur le chemin d'installation des volumes des containers (par défaut /home/$(logname)/seedbox/app_settings)
ask_question "Veuillez entrer le chemin d'installation des volumes des containers : par défaut /home/$(logname)/seedbox/app_settings  "
read folder_app_settings

# Utiliser le chemin par défaut si l'utilisateur n'a rien saisi
if [ -z "$folder_app_settings" ]; then
  folder_app_settings="/home/$(logname)/seedbox/app_settings"
fi

# Créer le répertoire si nécessaire
create_directory "$folder_app_settings"

# Demander à l'utilisateur le Chemin du dossier rclone (par défaut /home/$(logname)/rclone)
ask_question "Veuillez entrer le Chemin du dossier rclone : par défaut /home/$(logname)/rclone : "
read folder_rclone

# Utiliser le chemin par défaut si l'utilisateur n'a rien saisi
if [ -z "$folder_rclone" ]; then
  folder_rclone="/home/$(logname)/rclone"
fi

# Créer le répertoire si nécessaire
create_directory "$folder_rclone"

# Demander à l'utilisateur la clé API de RealDebrid
ask_question "Veuillez entrer votre clé API RealDebrid : "
read rd_api_key

# Demander à l'utilisateur le chemin de rclone.config
ask_question "Veuillez entrer le chemin de rclone.config ou laisser par default : par défault /home/$(logname)/.config/rclone "
read rclone_config

# Utiliser le chemin du fichier rclone.conf personnalisé s'il est défini, sinon utiliser le chemin par défaut
rclone_config_file="/home/$(logname)/.config/rclone/rclone.conf"
if [ ! -z "$rclone_config" ]; then
  echo "$rclone_config" > "$rclone_config_file"
else
  # Créer le répertoire .config/rclone s'il n'existe pas
  create_directory "/home/$(logname)/.config/rclone"
  
  # Écrire la configuration rclone dans le fichier rclone.conf en remplaçant {{RD_API_KEY}}
  cat <<EOL > "$rclone_config_file"
[realdebrid]
type = realdebrid
api_key = $rd_api_key
EOL
fi

# Recuperation token Plex token pour Plex_debrid

if [ -z "$plex_user" ] || [ -z "$plex_passwd" ]; then
    plex_user=$1
    plex_passwd=$2
fi

while [ -z "$plex_user" ]; do
    ask_question "Veuillez entrer votre nom d'utilisateur plex : "
    read plex_user
done
while [ -z "$plex_passwd" ]; do
    ask_question "Veuillez entrer votre mot de passe plex : "
    read plex_passwd
done
    ask_question "Récupération du token Plex... "

curl -qu "${plex_user}":"${plex_passwd}" 'https://plex.tv/users/sign_in.xml' \
    -X POST -H 'X-Plex-Device-Name: PlexMediaServer' \
    -H 'X-Plex-Provides: server' \
    -H 'X-Plex-Version: 0.9' \
    -H 'X-Plex-Platform-Version: 0.9' \
    -H 'X-Plex-Platform: xcid' \
    -H 'X-Plex-Product: Plex Media Server'\
    -H 'X-Plex-Device: Linux'\
    -H 'X-Plex-Client-Identifier: XXXX' --compressed >/tmp/plex_sign_in
rd_token_plex=$(sed -n 's/.*<authentication-token>\(.*\)<\/authentication-token>.*/\1/p' /tmp/plex_sign_in)
if [ -z "$rd_token_plex" ]; then
    #cat /tmp/plex_sign_in
    rd_token_plex=$(cat /tmp/plex_sign_in)
    rm -f /tmp/plex_sign_in
    >&2 echo 'Failed to retrieve the X-Plex-Token.'
    exit 0
fi
rm -f /tmp/plex_sign_in

# URL Plex par défaut avec IP publique
default_plex_address="http://$ip_public:32400"

# Demander à l'utilisateur le nom de domaine ou l'adresse IP du serveur Plex
ask_question "Veuillez entrer le nom de domaine ou l'adresse IP du serveur Plex (laissez vide pour utiliser l'URL par défaut : $default_plex_address) : "
read public_plex_address

# Utilisation de l'URL par défaut si l'utilisateur n'en spécifie pas
if [ -z "$public_plex_address" ]; then
  plex_address="$default_plex_address"
else
  plex_address="$public_plex_address"
fi

# Demander à l'utilisateur le claim Plex (https://www.plex.tv/claim/)
ask_question "Veuillez entrer votre claim Plex (https://www.plex.tv/claim/) : "
read plex_claim

# Écrit les réponses dans le fichier .env
echo "FOLDER_APP_SETTINGS=$folder_app_settings" > "$env_file"
echo "FOLDER_RCLONE=$folder_rclone" >> "$env_file"
echo "RD_API_KEY=$rd_api_key" >> "$env_file"
echo "RD_TOKEN_PLEX=$rd_token_plex" >> "$env_file"
echo "PLEX_ADDRESS=$plex_address" >> "$env_file"
echo "PLEX_USER=$plex_user" >> "$env_file"
echo "PLEX_PASSWD=$plex_passwd" >> "$env_file"
echo "PLEX_CLAIM=$plex_claim" >> "$env_file"

echo -e "\e[32mConfiguration terminée. Les informations ont été écrites dans le fichier $env_file.\e[0m"

# Copier le contenu du fichier includes/templates/docker-compose.yml vers $folder_app_settings
cp includes/templates/docker-compose.yml "$folder_app_settings"

# Remplacer les variables dans docker-compose.yml en utilisant les valeurs du .env
env_vars=$(grep -oE '\{\{[A-Za-z_][A-Za-z_0-9]*\}\}' "$folder_app_settings/docker-compose.yml")

for var in $env_vars; do
  var_name=$(echo "$var" | sed 's/[{}]//g')
  var_value=$(grep "^$var_name=" "$env_file" | cut -d'=' -f2)
  sed -i "s|{{${var_name}}}|${var_value}|g" "$folder_app_settings/docker-compose.yml"
done

# Afficher un message
echo -e "\033[32mLes informations ont été ajoutées au fichier docker-compose.yml.\033[0m"
