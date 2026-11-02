# Journal — Un standard de test pour Lnclass

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Cadrage repris : 4 principes + 8 objectifs validés par le porteur | Le premier cadrage ne couvrait que les 4 principes | oui, ADR-XXXX §4 |
| 2026-11-02 | Tranché par le porteur : Develop reçoit le jeu sans aucune suppression ; Staging ajoute les v3 absentes ; rendu des leçons en PR sur les fichiers touchés et au train en parts ≤ 5 min (dérogation au budget système) ; niveaux sans v3 : v1 si importable, sinon vides ; leçon 1 de chaque couple ; activité sur les 2 établissements, plusieurs classes, plusieurs semaines, déterministe | Recommandations du cadrage | oui, ADR-XXXX §4 « Tranché » |
| 2026-11-02 | Numéros fictifs : plage `0[157]0000xxxx` par défaut — le format de contact (`0[157]\d{8}`) n'admet aucune plage non attribuable | Garantie à confirmer par le porteur | non |
| 2026-11-02 | Lot 0 — constat v1 : les 27 couples sans v3 (2nde, 2nde-a, 2nde-c, 4eme, 5eme, 6eme) n'ont que des fichiers au format 1 ; `RunImport` les refuse (`format_retired`, versions 1 à 2 retirées) : aucune leçon v1 ne s'importe par la chaîne actuelle, ils sont écrits vides sous `sans_v3:` dans le manifeste | Décision n° 4 du porteur (v1 si importable, sinon vides) | non |
| 2026-11-02 | Lot A — durée mesurée de `bin/jeu-standard --reset` en local : 44 s au total (dont 33 s pour le semis : 1 732 élèves, 18 enseignants, 47 leçons importées et publiées) ; rejoué sans `--reset` : 3,6 s. Critère « moins de 5 minutes » tenu avec l'activité (Lot B) à ajouter | Mesure sur la machine de l'agent | non |
| 2026-11-02 | Lot A — les dix premiers numéros des élèves, enseignants et directions sont réservés aux comptes de `db/seeds/development.rb` (0100000001, 0500000001, 0700000000) : le jeu commence au onzième (élève `0100000010`, enseignant `0500000010`, direction `0700000010`). `--grand` supprimé : le grand établissement est toujours chargé (décision du porteur) | Sans cela, le semis de développement et le jeu se partageaient des comptes | non |
| 2026-11-02 | Lot H — l'environnement Railway `Demo` est un stade à part (jamais PR, aucun chargement des leçons du dépôt, référentiel + jeu standard, comptes équipe seulement avec `DEMO_TEAM_PIN` scellée). **Pas de remise à zéro automatique** du semis à chaque déploiement (elle supprimerait les données des visiteurs) : **à confirmer par le porteur** ; `bin/jeu-standard --reset --confirmer=Demo` reste manuel. Sans `DEMO_TEAM_PIN`, un administrateur équipe inerte (PIN aléatoire, sans second facteur) est créé, car l'import et la publication des leçons exigent un acteur équipe : **à confirmer** | Décision du porteur du 2026-11-02 ; l'acteur inerte est la seule façon de publier sans PIN public | non |

## Ce qui a dérapé

- Le premier cadrage a été commité avant que l'orchestrateur ne demande d'attendre la liste d'objectifs : il a été gardé et réécrit, sans PR.

## Dette et suites

- Endroit des démonstrations (Develop ou environnement dédié) : à décider.
- Remise à zéro de Develop au jeu standard : non décidée.

## Lot E — menace de l'aperçu local (écrite avant le code)

- **Entrée** : un fichier JSON du dépôt (`docs/contenus/lecons-traitees/…`), lancé à la main par un développeur sur sa machine ; jamais un fichier téléversé par un utilisateur de l'application.
- **Environnement** : le script `bin/apercu-lecon` refuse tout `RAILS_ENV` autre que development, `RAILWAY_ENVIRONMENT_NAME` ou `DATABASE_URL` posées (il ne force jamais l environnement), et la tâche `contenus:apercu` refuse tout environnement autre que `development` (production, Staging, Develop, PR, test) avant de lire le fichier ; rien n'est importé.
- **Chemin** : le chemin est résolu (liens symboliques suivis) et doit rester sous `docs/contenus/lecons-traitees/`, extension `.json` ; `..`, chemin absolu extérieur ou lien vers l'extérieur sont refusés (pas de lecture d'un fichier arbitraire).
- **Contrôles** : `script/contenus/valider.rb` d'abord (arrêt et erreurs affichées s'il y a un ✗), puis la vraie chaîne d'import (schéma JSON, règles de l'adaptateur, mêmes refus que l'écran Imports) ; un refus laisse la base intacte (l'import est transactionnel).
- **Portée** : un seul fichier à la fois, remplacement de la seule leçon de même titre (`replace: :lesson`), aucun mot de passe ni donnée d'élève lus ou écrits ; le compte élève affiché est un compte fictif de la plage `0[157]0000xxxx`.

- **Durée mesurée (Lot E)** : `bin/apercu-lecon` sur la leçon Thalès (3ème, 26 exercices, 4 sujets) en development : 2,9 s la première fois (création), 4,1 s en remplacement d'une leçon déjà publiée, démarrage de Rails compris. Cible < 15 s tenue. `--suivre` rejoue l'aperçu au changement de `mtime` (boucle de 1 s).
