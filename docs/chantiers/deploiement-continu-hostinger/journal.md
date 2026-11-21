# Journal — Déploiement continu GitHub → VPS Hostinger

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | La garde de Staging et de la production lit la preuve de l'arbre, pas un statut de commit | La CI ne tourne qu'aux PR ; le commit de fusion n'a pas de statut, son arbre a la preuve | Oui, §5.3 |
| 2026-11-21 | Le job prend `deployer.py` de la tête de branche et ne passe que le SHA | Un retour arrière vers un SHA d'avant ce chantier n'aurait pas l'authentification Hostinger | Oui, §5.1 |
| 2026-11-21 | Aucune annulation, dans les trois environnements | Un job tué pendant la construction laisse `lnclass-construction` sur le VPS | Oui, §5.4 |

## À trancher

- [ ] 2026-11-21 · deploiement-continu-hostinger · Relecteur requis sur l'Environment `production` en plus de la branche `main` seule — appliqué : branche `main` seule (un relecteur n'est offert qu'avec GitHub Enterprise dans un dépôt privé) ; autres : ajouter le porteur comme relecteur si l'offre le permet ; recommandé : branche seule.
- [ ] 2026-11-21 · deploiement-continu-hostinger · Offre GitHub de l'organisation sans Environments pour un dépôt privé (GitHub Free) — appliqué : ne pas poser les secrets au niveau du dépôt, le déploiement reste manuel ; autres : secrets du dépôt (tout workflow de toute branche lirait le jeton Hostinger) ; recommandé : Environments (offre Team) ou déploiement manuel.
- [ ] 2026-11-21 · deploiement-continu-hostinger · Un seul jeton Hostinger ou trois (un par Environment) — appliqué : la doc recommande trois jetons distincts ; autres : un même jeton copié trois fois ; recommandé : trois, révocables séparément.

## Retouches

- Lot A : le garde-fou est branché dans le groupe `lint` de `config/ci.rb` ; l'attente du projet à usage unique vaut aussi pour `bascule` (même `run_once`, noms de projet distincts).

## Ce qui a dérapé

- Ruby 3.4 et les gems du projet ne sont pas installés dans la session : `ci_plan_test.rb` (qui emploie `it`) et `bin/rubocop` n'ont pas pu tourner ; le nouveau garde-fou évite `it` et tourne en Ruby 3.3.
- `actionlint` n'a pas pu être installé dans la session (téléchargement de binaire refusé) : le garde-fou Ruby vérifie la structure du workflow à sa place.

## Ce qu'on a appris sur la codebase

- `deployer.py` n'envoie aucun en-tête d'authentification à Hostinger : dans une session, le proxy de l'environnement l'ajoute.
- Le projet de construction porte un nom fixe pour les trois environnements : deux envois simultanés se remplaçaient.
- La branche par défaut du dépôt est `main`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Épingler par SHA les actions de `ci.yml` | Hors périmètre : `ci.yml` ne voit aucun secret du VPS | à ouvrir |
| Durcir `script/ci/tested_tree` : n'accepter la preuve `ci-tree-<arbre>` que d'un run du workflow `ci` (revue de sécurité, note) | Antérieur au chantier ; reste dans le cercle de M3 | à ouvrir |
| Test unitaire Python de `run_once` (verdict lié à la révision) | `deployer.py` n'a pas de banc de test Python | à ouvrir |
| Faire porter la révision à `/up` pour vérifier que la bonne image répond | Demande un changement de l'application | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-XXXX-deploiement-continu-hostinger |
| **UDR produits** | — |
