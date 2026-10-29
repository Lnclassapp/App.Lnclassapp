# Memo — Une classe s'inscrit ensemble depuis le wifi de l'école

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/inscription-classe-meme-wifi` |
| **Programme** | — |

---

## Symptôme

L'enseignant partage le lien de la classe et demande aux élèves de s'inscrire en classe. Au-delà du 10e lien ouvert (ou de la 5e inscription) dans la minute depuis la même connexion, les élèves suivants lisent « Trop de tentatives » et doivent attendre.

Attendu : ADR-0085 promet qu'« un élève s'inscrit sans que personne ne lui ait rien transmis » et que le lien de classe fait entrer tout de suite. Dans une école ivoirienne, une classe partage une seule adresse (wifi, partage de connexion de l'enseignant, NAT de l'opérateur mobile) : le débit par adresse, pensé contre un attaquant, frappe la classe entière.

## Reproduction

- Develop, 2026-10-29 : 45 élèves inscrits par le lien `/c/<jeton>` de la 3ème 1, l'un après l'autre depuis une même adresse ; les élèves 42 et 43 ont reçu « Trop de tentatives » (429), passés après une minute d'attente.
- Code : `Classroom::JoinsController::LINK_RATE_LIMIT` (10/min/adresse, partagé avec la vérification de code) sur `GET /c/:token` et sur `POST /student-signup` ; plus 5/min/adresse sur `POST /student-signup`.

## Portée

- Toute classe dont les élèves s'inscrivent ensemble derrière une même adresse : le cas normal d'un lancement en classe.
- Pas de données corrompues : un refus 429 n'écrit rien.

## Cause (cadrage)

Le débit est compté **par adresse seule**, sans distinguer l'entrée par le lien d'une classe (le lien prouve l'invitation, son jeton de 48 bits ne se devine pas) de la devinette de codes. Décision écrite : amendement du 2026-10-29 de l'ADR-0085 (§4.7).

## Hors périmètre

- Le comptage par /64 en IPv6 (dette de l'ADR-0085).
- Les débits de la cascade (30/min), de la vérification de code d'établissement, de l'inscription enseignant : inchangés.
- Badge de la liste enseignant : pas un bug (UDR-0134 §3.2, badge de classe sur la moyenne ; la fiche montre les badges par exercice), voir journal.

## Portes de sortie (lot unique)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
