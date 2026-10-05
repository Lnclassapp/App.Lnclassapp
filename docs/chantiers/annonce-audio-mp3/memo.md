# Memo — Un MP3 enregistré au téléphone est refusé à la création d'une annonce

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `fix/annonce-audio-mp3` |
| **Programme** | `refonte-application` (suite de la V6a, chantier [`annonces`](../annonces/memo.md)) |

---

## Symptôme

Le porteur crée une annonce et joint, dans « Audio (facultatif) », un fichier `.mp3` enregistré avec son téléphone. À l'envoi, le formulaire revient en erreur avec **« Ce fichier n'est pas accepté. »** sous le champ Audio. L'annonce n'est pas créée.

**Comportement attendu** : un MP3 de 10 Mo au plus est accepté. Sources : ADR-0045 §4, [ADR-0078](../../decisions/adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) §4.4, [UDR-0071](../../decisions/udr/0071-annonces.md) §3.8 (« MP3 ou M4A, 10 Mo au plus »).

## Reproduction

| | |
|---|---|
| **Acteur** | le porteur, sur la page « Nouvelle annonce » ; rôle exact à préciser |
| **Environnement** | `Develop` |
| **Données** | un fichier `.mp3` produit par l'enregistreur d'un téléphone (appareil et application à préciser) |
| **Étapes** | 1. « Annonces » → « Mes annonces » → « Nouvelle annonce ». 2. Titre, texte, illustration, destinataires. 3. « Audio (facultatif) » : le fichier `.mp3`. 4. « Publier ». → 422, « Ce fichier n'est pas accepté. » sous Audio |
| **État** | ⏳ **Non reproduit** : il faut le fichier, ou au moins ses 16 premiers octets. Un MP3 encodé classiquement (étiquette `ID3`) passe : le challenger de la phase 5 d'`annonces` l'a publié sans erreur. |

## Portée

- **Depuis** : la livraison d'`annonces` (PR #162, fusionnée le 2026-10-04). Le refus vient du contrôle du format, en place depuis le Lot A.
- **Acteurs** : tout auteur (équipe, direction, enseignant) qui joint un audio du même type.
- **Données corrompues** : aucune. Le refus n'écrit rien : ni annonce, ni pièce jointe.

## Hypothèses à vérifier sur le fichier

`Entities::Communication::AudioHeader.format_of` lit les 12 premiers octets et ne reconnaît que trois cas :

- un MP3 qui commence par `ID3` ;
- un MP3 qui commence par une synchronisation de trame (`FF Ex`) ;
- un MP4 de marque `M4A `, `mp42` ou `isom`.

Un enregistrement de téléphone nommé `.mp3` peut sortir de ces cas :

1. un MP4 ou 3GP d'une autre marque (`3gp4`, `3gp5`, `mp41`, `M4B `, `dash`…) renommé `.mp3` ;
2. un MP3 précédé d'octets de remplissage, ou enveloppé dans un en-tête `RIFF…WAVE` ;
3. un autre format (AMR `#!AMR`, OGG/Opus `OggS`) nommé `.mp3`.

Le cas 3 ne serait pas un bug : ces formats ne sont pas autorisés par l'ADR-0045. Il faudrait alors une décision (feature) pour les accepter.

## Hors périmètre

- Les autres demandes du 2026-10-05 sur les annonces vont au chantier feature `annonces-v2` :
  - décompte des caractères ;
  - illustrations ajoutées par l'équipe ;
  - 3 annonces visibles par auteur au lieu de la date de fin ;
  - 10 thèmes de couleur.
- Accepter de nouveaux formats audio (AMR, OGG/Opus, WebM) : il faudrait amender l'ADR-0045.
- Valider l'audio au-delà de son en-tête : c'est la remarque de la revue de sécurité, en dette.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Découper les 5 demandes ? | Bugfix audio d'un côté, chantier feature `annonces-v2` pour le reste | Ce chantier ne corrige que le refus du MP3 |
| D'où vient le MP3 ? | Enregistré au téléphone | Hypothèses 1 et 2 en tête ; le fichier tranchera |
| Où a-t-il été vu ? | Environnement `Develop` | Reproduction locale sur `Develop` avec le même fichier |

## Questions encore ouvertes

- Le fichier refusé, ou ses 16 premiers octets en hexadécimal, ainsi que le téléphone et l'application d'enregistrement.
- Le rôle avec lequel l'annonce a été créée.

## Portes de sortie

Un seul lot, aucune migration : les portes de sortie sont ici, `plan.md` et `prd.md` sont retirés.

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [ ] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [ ] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
