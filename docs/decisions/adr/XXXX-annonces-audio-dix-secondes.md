# ADR-XXXX : L'audio d'une annonce dure 10 secondes au plus, mesuré dans ses octets, et se télécharge
<!-- index
titre: Annonces : un audio de 10 secondes au plus, mesuré sans bibliothèque, téléchargeable
statut: Accepté
problematique: L'audio d'une annonce n'avait qu'une borne de poids (10 Mo) ; il doit durer 10 s au plus, vérifié au serveur sans dépendance, et pouvoir être téléchargé pour être réutilisé.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | [`docs/chantiers/annonces-logo-audio`](../../chantiers/annonces-logo-audio/prd.md) |
| **Amende** | [ADR-0078](0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) §4.4 (poids de l'audio, fichier servi) · [ADR-0081](0081-annonces-trois-en-ligne-themes-et-illustrations-de-l-equipe.md) §4.4 (formats inchangés) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Une annonce est une carte de 60 + 140 caractères. Son audio (ADR-0045, ADR-0078 §4.4) n'était borné que par son poids, 10 Mo : plusieurs minutes de son. Le porteur demande le 2026-10-30 un audio de 10 secondes au plus, et téléchargeable pour être réutilisé (WhatsApp, réunion).

La durée d'un fichier se lit dans ses octets, et un fichier téléversé est une entrée hostile : ses en-têtes peuvent mentir, sa structure peut boucler, sa taille peut viser la mémoire ou le processeur. Le format est déjà lu sans bibliothèque (`AudioHeader`, 4096 premiers octets).

## 2. Moteurs de décision

1. Le serveur fait foi : le contrôle du navigateur n'est qu'un confort.
2. Une durée qu'on ne peut pas croire vaut un refus, pas une acceptation.
3. Aucune dépendance de plus (ni gem, ni `ffprobe` dans l'image de production).
4. Lecture bornée en mémoire et en temps.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — `ffprobe` (ffmpeg) au serveur | Lit tout format, exact | Binaire de plus dans l'image, processus lancé sur une entrée hostile, dépendance système à surveiller |
| B — Une gem de métadonnées audio | Code tiers éprouvé | Lit la durée déclarée (Xing, `mvhd`) : un fichier qui ment passe ; dépendance de plus |
| C — **Mesure en Ruby pur dans le domaine** | Les deux formats sont simples ; trame par trame pour le MP3, boîtes pour le M4A ; testable sur des fichiers réels | Un code de format à maintenir (≈ 150 lignes) |
| D — Contrôle dans le navigateur seul | Aucun code serveur | Contournable |

## 4. Décision

> **Nous mesurons la durée d'un audio d'annonce en Ruby pur, dans le domaine, sur ses octets (1 Mo au plus) ; nous refusons au-delà de 10 secondes (+ 0,3 s de marge d'encodeur) et toute durée illisible ; le navigateur prévient avant l'envoi ; le fichier se télécharge avec la règle de lecture de l'écoute.**

### 4.1 Bornes

- Durée : 10 s (`AUDIO_MAX_SECONDS`), avec une marge de 0,3 s (`AUDIO_SLACK_SECONDS`) : un encodeur MP3 ajoute un délai de début et complète la dernière trame (≈ 0,05 à 0,1 s).
- Poids : **1 Mo** au lieu de 10 Mo (10 s à 320 kbit/s = 400 Ko). Le poids est vérifié avant toute lecture, comme avant.
- La borne s'applique au téléversement. Un audio déjà joint n'est pas relu.

### 4.2 Mesure

- **MP3** : on saute les étiquettes ID3v2 (taille *syncsafe*) et le remplissage nul, puis on parcourt **toutes** les trames ; chaque trame donne ses échantillons et sa fréquence. L'en-tête Xing/Info/VBRI n'est jamais cru. La fin admise : la fin du fichier, des octets nuls, une étiquette `TAG` (ID3v1) ou `APETAGEX`. Tout autre octet entre deux trames, ou aucune trame : illisible.
- **M4A** : on parcourt les boîtes de premier niveau jusqu'à `moov` ; la durée est le **maximum** de `mvhd`, de chaque `mdhd` et de la somme de chaque table `stts` (échantillons × durée, sur l'échelle de sa piste). Un fichier fragmenté (`moof` ou `mvex`), sans `moov`, avec une échelle de temps nulle ou une boîte de taille incohérente : illisible.

### 4.3 Téléchargement

`GET /announcements/:public_id/audio?download=1` (`announcement_file_path(public_id, kind: "audio", download: 1)`) : même use case, même policy (404 hors droit), en-tête `Content-Disposition: attachment; filename="annonce-<public_id>.mp3"` (ou `.m4a`, d'après le type enregistré). Le nom envoyé par l'auteur n'est jamais gardé (ADR-0045 §4) : rien de l'auteur n'entre dans l'en-tête.

### 4.4 Menace (écrite avant le code)

| # | Menace | Parade | Test |
|---|---|---|---|
| M1 | Un MP3 annonce une durée courte dans son en-tête Xing et contient 60 s de trames | Le Xing n'est pas lu : on additionne les trames | `audio_duration_test` : Xing menteur |
| M2 | Une trame valide, des octets inconnus, puis des trames que le lecteur resynchronise | Tout octet inconnu entre deux trames rend la durée illisible | `audio_duration_test` : octets entre trames |
| M3 | Un M4A dont `mvhd` dit 1 s et dont la piste dure 60 s | Maximum de `mvhd`, `mdhd` et `stts` | `audio_duration_test` : `mvhd` menteur |
| M4 | Fragmenté : la durée réelle est dans des `moof` que l'en-tête ignore | Fragmenté = illisible | `audio_duration_test` : `mvex` |
| M5 | Boucle infinie : boîte de taille 0 ou < 8, trame de longueur nulle | Toute boîte avance de 8 octets au moins ou rend illisible ; le débit « libre » est refusé (`AudioHeader`) ; une trame mesure au moins 24 octets | `audio_duration_test` : taille 3 |
| M6 | Table `stts` qui annonce 2³² entrées | Le nombre d'entrées est borné par les octets de la boîte | `audio_duration_test` : `stts` gonflée |
| M7 | Mémoire, processeur | Poids vérifié avant toute lecture (1 Mo) ; parcours linéaire, ≤ 1 Mo / 24 o ≈ 44 000 trames | `message_input_test` : 1 Mo + 1 non lu |
| M8 | Contournement du contrôle du navigateur | Le serveur mesure toujours | `authored_messages_controller_test` |
| M9 | Téléchargement hors droit, ou mis en cache | Même use case et policy ; `private, no-store` gardé | `message_files_controller_test` |
| M10 | Injection d'en-tête par le nom de fichier | Nom fixé par l'application | `message_files_controller_test` |

Hors menace : le contenu sonore lui-même (ce que dit l'audio) relève de la modération (retrait, ADR-0078 §4.2).

## 5. Conséquences

### 🟢 Positives

- Une borne que l'auteur comprend (« 10 secondes ») au lieu d'un poids.
- Aucune dépendance ; une durée qui ment est refusée.
- L'audio se garde et se partage hors de l'application.

### 🔴 Coûts consentis

- Un M4A fragmenté (marque `dash`, rare sur un téléphone) est refusé : il faut l'exporter autrement.
- Un MP3 dont les trames sont séparées par des octets non standard (étiquettes exotiques, `LYRICS3`) est refusé.
- Le plafond tombe de 10 Mo à 1 Mo : un MP3 qui porte une grosse pochette dans son étiquette ID3 est refusé pour son poids.
- Les audios déjà joints ne sont pas relus : certains durent plus de 10 s jusqu'à leur remplacement.
- Une fois téléchargé, l'audio échappe à la règle de lecture et au retrait de l'annonce.

## 6. Notes d'implémentation

- `app/domain/entities/communication/audio_duration.rb` : `AudioDuration.seconds_of(bytes, format:)` → `Float | nil`.
- `app/domain/entities/communication/message.rb` : `AUDIO_MAX_SECONDS = 10`, `AUDIO_SLACK_SECONDS = 0.3`, `AUDIO_MAX_MEGABYTES = 1`.
- `app/domain/dtos/communication/message_input.rb` : validation `audio_is_short` (`:too_long`, `:unreadable`) après `files_are_accepted`.
- `app/controllers/communication/message_files_controller.rb` : `disposition: :attachment` et nom `annonce-<public_id>.<ext>` quand `params[:download]`.
- `app/javascript/controllers/communication/audio_duration_controller.js` : lit `duration` d'un `<audio>` sur une URL d'objet, `setCustomValidity`.

## 7. Comment vérifier que la décision est respectée

- `bin/rails test test/domain/entities/communication/audio_duration_test.rb test/domain/dtos/communication/message_input_test.rb` : fichiers réels de 1 s, 9 s et 11 s (MP3, M4A), et fichiers forgés des menaces M1 à M6.
- `bin/rails test test/controllers/communication/message_files_controller_test.rb` : téléchargement, nom, 404 hors droit.
