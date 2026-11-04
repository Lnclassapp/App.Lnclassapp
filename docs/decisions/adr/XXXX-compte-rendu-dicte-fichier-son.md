# ADR-XXXX : Le compte rendu dicté accepte un fichier son MP3 ou M4A de 3 minutes au plus, mesuré dans le domaine et jamais conservé
<!-- index
titre: Compte rendu dicté (fichier son)
statut: Proposé
problematique: comment recevoir un fichier son envoyé par un membre de l'équipe et le faire transcrire sans ouvrir de faille ni garder la voix
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Après un appel ou une visite, le membre de l'équipe dicte son compte rendu ; un modèle audio le transforme en échange structuré, qu'il relit (memo, réponse 8). C'est du code qui lit un fichier envoyé par un utilisateur : la menace s'écrit avant le code (règle du projet, après 6 corrections JPEG successives).

Le projet sait déjà reconnaître et mesurer un MP3 ou un M4A en Ruby pur (`Entities::Communication::AudioHeader`, `AudioDuration`, ADR-0081 et ADR-0118), avec dix menaces déjà parées.

## 2. Moteurs de décision

1. Ne lire que des formats dont on sait mesurer la durée sans bibliothèque externe.
2. Ne jamais envoyer au fournisseur un fichier non vérifié.
3. Ne pas garder la voix d'un tiers au-delà du traitement.
4. Les téléphones de l'équipe : enregistreur natif Android (M4A) et iPhone (M4A).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Enregistrer dans le navigateur (`MediaRecorder`, WebM/Opus) | Un seul geste | WebM n'est pas mesuré par le domaine : il faudrait un nouveau lecteur de format, avec ses menaces |
| B — Fichier son du téléphone, MP3 ou M4A, mesuré par les lecteurs existants (retenue) | Réutilise un code éprouvé et ses tests | Deux gestes (enregistrer, puis choisir) ; l'AMR de vieux Android est refusé |
| C — Conversion serveur par `ffmpeg` | Tout format | Binaire externe qui lit un fichier hostile : surface d'attaque majeure |

## 4. Décision

> **Nous acceptons un fichier MP3 ou M4A de 5 Mo et 3 minutes au plus, reconnu et mesuré par `AudioHeader` et `AudioDuration` avant tout appel. Il est gardé dans le stockage privé le temps d'une tâche, puis purgé, que l'appel réussisse ou non.**

### 4.1 Bornes

- Poids : 5 Mo (`DICTATION_MAX_BYTES`), vérifié avant toute lecture.
- Durée : 180 s, plus 0,3 s de marge (`DICTATION_MAX_SECONDS`, marge reprise de `Entities::Communication::Message::AUDIO_SLACK_SECONDS`).
- Format : celui que lisent les octets (`AudioHeader.format_of`), jamais l'extension ni le type MIME envoyé.
- 10 dictées par acteur et par jour (elles comptent dans le quota IA de 40).

### 4.2 Menace (écrite avant le code)

| # | Menace | Parade | Test |
|---|---|---|---|
| D1 | Fichier renommé `.m4a` qui est un exécutable, un HTML ou un SVG | Le format est lu dans les octets ; tout autre format = 422 | `dictation_input_test` : HTML renommé |
| D2 | En-tête menteur (durée courte annoncée, 30 min réelles) qui fait exploser le coût | Les menaces M1 à M10 de l'ADR-0118 s'appliquent : durée additionnée, jamais crue | `dictation_input_test` : Xing menteur |
| D3 | Fichier énorme : mémoire, disque | Taille refusée avant lecture (`Content-Length`, puis `byte_size` du blob) | `dictation_input_test` : 5 Mo + 1 |
| D4 | Rejeu en boucle pour vider le budget | Quota de 10 par jour et budget mensuel, vérifiés avant la mise en file | `transcribe_dictation_test` |
| D5 | Voix conservée sans raison | Blob purgé dans `ensure` de la tâche, puis par `PurgeUnattachedBlobsJob` (filet) ; jamais servi par une URL | `ai_request_job_test` : blob absent après échec |
| D6 | Le modèle renvoie du texte qui prétend être des instructions, ou des valeurs hors liste | La sortie est un JSON validé par le domaine (types, résultats, motifs permis, longueurs) ; tout écart = « non lu » ; la note est échappée à l'affichage | `dictation_result_test` |
| D7 | Le fichier d'un autre membre lu par l'identifiant de la demande | La demande n'est lisible que par son auteur (ADR-XXXX-acces-aux-modeles-ia-par-openrouter §4.2) | `ai_requests_controller_test` |
| D8 | Envoi par un `content` ou un non-équipe | Policy `:read_and_note` avant la lecture du fichier | `dictations_controller_test` |

Hors menace : ce que dit la voix (contenu) ; le JSON relu par l'humain avant l'enregistrement.

## 5. Conséquences

### 🟢 Positives

- Aucun nouveau lecteur de format ; les tests de durée existants couvrent déjà les fichiers piégés.
- Aucune voix n'est gardée.

### 🔴 Coûts consentis

- Deux gestes pour dicter (enregistrer avec l'enregistreur du téléphone, puis choisir le fichier). Le champ `capture` ouvre l'enregistreur sur Android, mais pas partout.
- L'AMR et l'OGG sont refusés : un vieux téléphone peut ne pas pouvoir dicter.
- Le format audio accepté par le modèle choisi reste à vérifier (ADR-XXXX-acces-aux-modeles-ia-par-openrouter §1). Si le M4A n'est pas accepté, ce lot s'arrête et le Lot 0 rouvre : pas de conversion improvisée.

## 6. Notes d'implémentation

```ruby
# app/domain/dtos/school/dictation_input.rb (lot dictée) — calque de Dtos::Communication::MessageInput
# format = Entities::Communication::AudioHeader.format_of(head_bytes)
# duration = Entities::Communication::AudioDuration.seconds_of(bytes, format:)
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/dtos/school/dictation_input_test.rb` : D1, D2, D3.
- `test/jobs/school/ai_request_job_test.rb` : D5.
- `test/domain/entities/school/dictation_result_test.rb` : D6.
- Revue `security-reviewer` obligatoire sur le lot (téléversement).
