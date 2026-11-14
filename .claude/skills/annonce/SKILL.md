---
name: annonce
description: Prépare une annonce Lnclass prête à publier — texte court en français et audio MP3 de 10 secondes au plus par synthèse vocale Google — que l'équipe joint dans l'écran Annonces. Utilise-la quand l'utilisateur tape /annonce, ou demande d'écrire une annonce, un message audio ou une annonce vocale pour les élèves, enseignants ou établissements.
---

# Préparer une annonce

Tu prépares ; un membre de l'équipe publie dans **Annonces**. Contraintes de l'application (chantier `annonces-logo-audio`) : audio **MP3 ou M4A, 10 secondes au plus (tolérance 0,3 s), 1 Mo au plus**.

Argument : le message à faire passer et son public (élèves, enseignants, direction, tous). S'il manque, déduis-le de la demande.

## 1. Le texte

- Français simple, vouvoiement pour les adultes, tutoiement pour les élèves ; aucun nom de personne réelle hors équipe Lnclass.
- Un titre court, puis le texte de l'annonce (ce que voit la carte).
- Un **texte parlé** à part, de **25 mots au plus** (≈ 9 s à débit normal) : c'est lui qui devient l'audio.

## 2. L'audio

La clé est la variable d'environnement `GOOGLE_TTS_API_KEY` (Google Cloud Text-to-Speech).

- **Absente** : dis en une ligne « `GOOGLE_TTS_API_KEY` absente : audio non produit », sans la demander ni la chercher ailleurs, et livre le texte seul. Ce n'est pas un blocage du chantier.
- **Présente** :

```bash
curl -sS -X POST "https://texttospeech.googleapis.com/v1/text:synthesize" \
  -H "X-Goog-Api-Key: $GOOGLE_TTS_API_KEY" -H "Content-Type: application/json" \
  -d @requete.json | ruby -rjson -rbase64 -e 'r = JSON.parse($stdin.read); abort(r.to_s) unless r["audioContent"]; File.binwrite(ARGV[0], Base64.decode64(r["audioContent"]))' annonce.mp3
```

`requete.json` : `{"input":{"text":"<texte parlé>"},"voice":{"languageCode":"fr-FR","name":"fr-FR-Neural2-A"},"audioConfig":{"audioEncoding":"MP3","speakingRate":1.0}}`. Jamais la clé dans un fichier, un commit, une PR ni le chat.

## 3. Vérifier avant de livrer

```bash
ffprobe -v error -show_entries format=duration -of csv=p=0 annonce.mp3   # ≤ 10.3
stat -c %s annonce.mp3                                                    # ≤ 1048576
```

Trop long : raccourcis le texte parlé (ou `speakingRate` jusqu'à 1.15), on régénère. Ne livre jamais un fichier hors bornes : l'écran le refuserait.

## Fin

Fichiers dans le scratchpad, envoyés au porteur (SendUserFile), jamais commités : `annonce.md` (titre, texte, texte parlé, public) et `annonce.mp3` s'il a été produit. Une ligne : durée, taille, public.
