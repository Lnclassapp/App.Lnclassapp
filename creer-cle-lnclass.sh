#!/usr/bin/env bash
# Crée la clé de production Lnclass et la déclare au projet Android, sans jamais afficher le mot de passe.
# Usage, depuis la racine du dépôt App.Lnclassapp :  bash creer-cle-lnclass.sh
set -euo pipefail

KEY_DIR="$HOME/lnclass-cles"
KEYSTORE="$KEY_DIR/lnclass-prod.jks"
ALIAS="lnclass"
PROPS="android/local.properties"

[ -d android ] || { echo "Lance ce script depuis la racine du dépôt App.Lnclassapp."; exit 1; }
command -v keytool >/dev/null || { echo "keytool introuvable : installe un JDK 17+ ou utilise celui d'Android Studio (jbr/bin)."; exit 1; }
[ -e "$KEYSTORE" ] && { echo "La clé existe déjà : $KEYSTORE. Rien n'est écrasé."; exit 1; }

mkdir -p "$KEY_DIR" && chmod 700 "$KEY_DIR"
PASS="$(openssl rand -base64 24 | tr -d '/+=')"

keytool -genkeypair -keystore "$KEYSTORE" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" -dname "CN=Lnclass, O=Lnclass, C=CI" >/dev/null 2>&1
chmod 600 "$KEYSTORE"

# Retire d'anciennes lignes de signature, puis ajoute les nouvelles (le chemin du SDK est conservé).
touch "$PROPS"
grep -v '^lnclass\.\(keystore\|key\)\.' "$PROPS" > "$PROPS.tmp" || true
mv "$PROPS.tmp" "$PROPS"
{
  echo "lnclass.keystore.path=$KEYSTORE"
  echo "lnclass.keystore.password=$PASS"
  echo "lnclass.key.alias=$ALIAS"
  echo "lnclass.key.password=$PASS"
} >> "$PROPS"
chmod 600 "$PROPS"

# Copie de secours du mot de passe, à côté de la clé (à sauvegarder avec elle, hors du dépôt).
echo "$PASS" > "$KEY_DIR/mot-de-passe.txt" && chmod 600 "$KEY_DIR/mot-de-passe.txt"

echo "Clé créée : $KEYSTORE"
echo "Mot de passe : dans $KEY_DIR/mot-de-passe.txt (jamais dans le chat)."
echo "Sauvegarde le dossier $KEY_DIR sur une clé USB ou un coffre de mots de passe."
echo
echo "Empreinte à mettre dans ANDROID_CERT_FINGERPRINTS (Railway, production) :"
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$PASS" | grep 'SHA256:' | sed 's/.*SHA256: //'
