# ADR-0118 : L'audio d'une annonce dure 10 secondes au plus, mesuré dans ses octets, 
<!-- index
titre: Annonces : un audio de 10 secondes au plus, mesuré sans bibliothèque
statut: Accepté
problematique: L'audio d'une annonce n'avait qu'une borne de poids (10 Mo) ; il doit durer 10 s au plus, vérifié au serveur sans dépendance.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | [`docs/chantiers/annonces-logo-audio`](../../chantiers/annonces-logo-audio/prd.md) |
| **Amende** | [ADR-0078](0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) §4.4 (poids de l'audio) · [ADR-0081](0081-annonces-trois-en-ligne-themes-et-illustrations-de-l-equipe.md) §4.4 (formats inchangés) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Une annonce est une carte de 60 + 140 caractères. Son audio (ADR-0045, ADR-0078 §4.4) n'était borné que par son poids, 10 Mo : plusieurs minutes de son. Le porteur demande le 2026-10-30 un audio de 10 secondes au plus.

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

> **Nous mesurons la durée d'un audio d'annonce en Ruby pur, dans le domaine, sur ses octets (1 Mo au plus) ; nous refusons au-delà de 10 secondes (+ 0,3 s de marge d'encodeur) et toute durée illisible ; le navigateur prévient avant l'envoi.**

### 4.1 Bornes

- Durée : 10 s (`AUDIO_MAX_SECONDS`), avec une marge de 0,3 s (`AUDIO_SLACK_SECONDS`) : un encodeur MP3 ajoute un délai de début et complète la dernière trame (≈ 0,05 à 0,1 s).
- Poids : **1 Mo** au lieu de 10 Mo (10 s à 320 kbit/s = 400 Ko). Le poids est vérifié avant toute lecture, comme avant.
- La borne s'applique au téléversement. Un audio déjà joint n'est pas relu.

### 4.2 Mesure

- **MP3** : on saute les étiquettes ID3v2 (taille *syncsafe*) et le remplissage nul, puis on parcourt **toutes** les trames ; chaque trame donne ses échantillons et sa fréquence. L'en-tête Xing/Info/VBRI n'est jamais cru. La fin admise, et elle seule : la fin du fichier ; des octets nuls jusqu'au bout ; un ID3v1 (exactement 128 octets, commençant par `TAG`, finissant le fichier) ; une étiquette APEv2 dont l'étendue va jusqu'à la fin du fichier (pied `APETAGEX` de 32 octets dont la taille, petit-boutiste aux octets 12..15, inclut le pied mais pas l'en-tête optionnel de 32 octets ; ou en-tête `APETAGEX` + taille), éventuellement suivie d'un ID3v1. Un `TAG` ou un `APETAGEX` suivi d'autre chose (des trames qu'un lecteur rejouerait), tout autre octet entre deux trames, ou aucune trame : illisible.
- **M4A** : on parcourt les boîtes de premier niveau jusqu'à `moov` ; la durée est le **maximum** de `mvhd`, de chaque `mdhd` et de la somme de chaque table `stts` (échantillons × durée, sur l'échelle de sa piste). La table `stts` doit couvrir la piste : la somme de ses `sample_count` égale celui de `stsz` (ou `stz2`) de la même piste, et le nombre d'entrées annoncé correspond exactement aux octets de la boîte ; sinon, ou sans `stsz`/`stz2`, illisible. Chaque `trak` doit avoir son `mdhd` et sa table `mdia/minf/stbl/stts` : une piste qui n'a qu'une durée déclarée est illisible (M9). Un fichier fragmenté (`moof` ou `mvex`), sans `moov`, avec une échelle de temps nulle ou une boîte de taille incohérente : illisible.

### 4.3 Téléchargement (retiré)

> **Retiré le 2026-10-30, à la demande du porteur** : « quand j'ai dit rends-le téléchargeable, c'était pour l'avoir en local et non via l'app. » La route `announcement_file_path` sert l'audio comme avant le chantier (lecture inline, plage 206, `private, no-store`) ; il n'y a plus de paramètre `download`, ni de nom `annonce-<public_id>.<ext>`, ni de lien sur la carte. Les menaces M9 et M10 qui le couvraient sont retirées avec lui.

### 4.4 Menace (écrite avant le code)

| # | Menace | Parade | Test |
|---|---|---|---|
| M1 | Un MP3 annonce une durée courte dans son en-tête Xing et contient 60 s de trames | Le Xing n'est pas lu : on additionne les trames | `audio_duration_test` : Xing menteur |
| M2 | Une trame valide, des octets inconnus, puis des trames que le lecteur resynchronise | Tout octet inconnu entre deux trames rend la durée illisible ; `TAG`/`APETAGEX` n'est admis qu'en fin de fichier exacte (ID3v1 de 128 octets, APEv2 jusqu'au bout) | `audio_duration_test` : octets entre trames |
| M3 | Un M4A dont `mvhd` dit 1 s et dont la piste dure 60 s | Maximum de `mvhd`, `mdhd` et `stts`, `stts` vérifiée contre `stsz`/`stz2` (un `stts` d'un échantillon sur 500 est illisible) | `audio_duration_test` : `mvhd` menteur |
| M4 | Fragmenté : la durée réelle est dans des `moof` que l'en-tête ignore | Fragmenté = illisible | `audio_duration_test` : `mvex` |
| M5 | Boucle infinie : boîte de taille 0 ou < 8, trame de longueur nulle | Toute boîte avance de 8 octets au moins ou rend illisible ; le débit « libre » est refusé (`AudioHeader`) ; une trame mesure au moins 24 octets | `audio_duration_test` : taille 3 |
| M6 | Table `stts` qui annonce 2³² entrées | Le nombre d'entrées annoncé doit correspondre exactement aux octets de la boîte, sinon illisible | `audio_duration_test` : `stts` gonflée |
| M7 | Mémoire, processeur | Poids vérifié avant toute lecture (1 Mo) ; parcours linéaire, ≤ 1 Mo / 24 o ≈ 44 000 trames | `message_input_test` : 1 Mo + 1 non lu |
| M8 | Contournement du contrôle du navigateur | Le serveur mesure toujours | `authored_messages_controller_test` |
| M9 | Un M4A dont une piste n'a pas de `mdhd`, ou dont `stbl`/`stts` n'est pas exactement sous `mdia/minf/stbl` : seule la durée déclarée se lisait (5 s devant 60 s de `stts`) — constat de la revue du train, 2026-10-30 | Chaque `trak` exige `mdhd` et `mdia/minf/stbl/stts` avec `stsz` ou `stz2`, sinon illisible | `audio_duration_test` : M9 |
| M10 | `APETAGEX` suivi de 2 à 7 octets après des trames valides : lecture hors de la chaîne, erreur 500 au lieu d'un refus — même revue | Une étiquette APEv2 de moins de 32 octets n'est jamais lue : illisible | `audio_duration_test`, `message_input_test` : `APETAGEX` + 5 octets |

Hors menace : le contenu sonore lui-même (ce que dit l'audio) relève de la modération (retrait, ADR-0078 §4.2).

## 5. Conséquences

### 🟢 Positives

- Une borne que l'auteur comprend (« 10 secondes ») au lieu d'un poids.
- Aucune dépendance ; une durée qui ment est refusée.

### 🔴 Coûts consentis

- Un M4A fragmenté (marque `dash`, rare sur un téléphone) est refusé : il faut l'exporter autrement.
- Un MP3 dont les trames sont séparées par des octets non standard (étiquettes exotiques, `LYRICS3`) est refusé.
- Le plafond tombe de 10 Mo à 1 Mo : un MP3 qui porte une grosse pochette dans son étiquette ID3 est refusé pour son poids.
- Les audios déjà joints ne sont pas relus : certains durent plus de 10 s jusqu'à leur remplacement.

## 6. Notes d'implémentation

- `app/domain/entities/communication/audio_duration.rb` : `AudioDuration.seconds_of(bytes, format:)` → `Float | nil`.
- `app/domain/entities/communication/message.rb` : `AUDIO_MAX_SECONDS = 10`, `AUDIO_SLACK_SECONDS = 0.3`, `AUDIO_MAX_MEGABYTES = 1`.
- `app/domain/dtos/communication/message_input.rb` : validation `audio_is_short` (`:too_long`, `:unreadable`) après `files_are_accepted`.
- `app/javascript/controllers/communication/audio_duration_controller.js` : lit `duration` d'un `<audio>` sur une URL d'objet, `setCustomValidity`.

## 7. Comment vérifier que la décision est respectée

- `bin/rails test test/domain/entities/communication/audio_duration_test.rb test/domain/dtos/communication/message_input_test.rb` : fichiers réels de 1 s, 9 s et 11 s (MP3, M4A), et fichiers forgés des menaces M1 à M6, M9 et M10.
- `bin/rails test test/views/communication/card_test.rb` : aucune carte avec audio ne porte de lien « Télécharger » ni d'attribut `download`.
