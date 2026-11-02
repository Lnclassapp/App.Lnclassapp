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

## Lot D — rendu automatique des leçons (premier passage complet, 2026-11-02)

- **Mesure** : une leçon se rend en 4,2 s en moyenne (import, publication, connexion, deux visites : 390 px puis ordinateur), un fichier v3 sur 417. Un passage complet en un seul processus : 417 x 4,2 s, environ 29 min. Une première tentative à 3 processus parallèles a fini en 30 min avec 263 interblocages PostgreSQL (`deadlock detected`, base de test partagée en parallèle) : ces 263 leçons ont été rejouées en série (18 min). Le découpage de la CI reste donc à un processus par part (35 fichiers, sous le seuil de parallélisme de 50).
- **Découpage** : 12 parts (tâche `lecons`, 35 fichiers, environ 2 min 30 de tests plus l'installation, sous les 5 minutes), partage glouton par taille de fichier (`LECONS_PART=i/12`).
- **Résultat** (revue du Lot D : la mesure attend la fin du rendu KaTeX, ignore le texte des formules pour `**`, compte un JSON illisible comme un import refusé) : passage complet rejoué en 18 parts sur 3 bases, **le même résultat qu'avant** : 41 leçons sur 417 en défaut (non corrigées, hors du lot) : 27 avec `**` dans le texte rendu, 15 qui débordent, 1 figure absente (2 leçons cumulent `**` et débordement), 0 import refusé. Les `**` sont de vrais défauts, pas des faux positifs des formules : ce sont des gras Markdown non interprétés à côté d'une formule, par exemple `**-liste**` dans `1ere-c/mathematiques/denombrement`, `**le nombre positif dont le carré…**` dans `3eme/mathematiques/racines-carrees`. Un premier passage avait compté 10 imports refusés (EDHC) : faux positif de la base de test, qui n'avait pas cette matière du référentiel réel ; le test la crée.
- **Mesure sans charge** : 35 fichiers en 147 s et 151 s (parts 5/12 et 2/12, machine libre), soit 4,2 s par leçon ; tâche `lecons` en 12 parts, sous 3 min 30 de tests. Sous charge (machine à 16-26 de charge à cause d'une autre suite), les mêmes leçons prennent 13 s : ne pas mesurer sur une machine occupée. Les leçons à milliers de formules (`tle-c/mathematiques/derivabilite-et-etude-de-fonctions`, 4 581 formules) prennent 15 s même seules.
- **Découverte** : KaTeX ne rend pas les `$…$` dans une `<option>` (liste déroulante de réponse) : la mesure ne les attend pas, sinon elle patiente 10 s par page pour rien.
- **Poste de travail** : Chrome 153 est installé avec un chromedriver 147 dans le PATH (`/opt/node22/bin`) : lancer les tests système avec un PATH sans lui pour que selenium-manager télécharge le bon pilote.
- **Écarts** : exercices et problèmes sont lus dans la page de la leçon (fiche de révision, « Prépare interros », « Prépare devoirs ») ; les pages `/exercises/<id>` ne sont pas visitées. La tâche `lecons` est ajoutée à `ci.yml` : `test/guards/ci_plan_test.rb` (hors de la fiche) attend encore `plan unit system ci` et doit être mis à jour.

Fichiers en défaut :

| Fichier (sous docs/contenus/lecons-traitees) | Défaut |
|---|---|
| `1ere-a1/mathematiques/denombrement.json` | `**` |
| `1ere-a1/mathematiques/equations-et-inequations.json` | `**` |
| `1ere-a1/physique-chimie/les-alcanes.json` | débordement |
| `1ere-a1/physique-chimie/les-alcenes-cas-de-l-ethylene.json` | débordement |
| `1ere-a2/mathematiques/denombrement.json` | `**` |
| `1ere-a2/mathematiques/equations-et-inequations.json` | `**` |
| `1ere-a2/physique-chimie/les-alcanes.json` | débordement |
| `1ere-a2/physique-chimie/les-alcenes-cas-de-l-ethylene.json` | débordement |
| `1ere-c/mathematiques/composees-de-transformations-du-plan.json` | `**`,débordement |
| `1ere-c/mathematiques/denombrement.json` | `**` |
| `1ere-c/mathematiques/derivation.json` | `**` |
| `1ere-c/mathematiques/generalites-sur-les-fonctions.json` | `**` |
| `1ere-c/physique-chimie/energie-mecanique.json` | `**` |
| `1ere-c/physique-chimie/hydrocarbures-insatures-les-alcenes-et-les-alcynes.json` | débordement |
| `1ere-c/physique-chimie/hydrocarbures-satures-les-alcanes.json` | débordement |
| `1ere-c/svt/la-photosynthese.json` | `**` |
| `1ere-d/mathematiques/denombrement.json` | `**` |
| `1ere-d/mathematiques/derivation.json` | `**` |
| `1ere-d/mathematiques/generalites-sur-les-fonctions.json` | `**` |
| `1ere-d/physique-chimie/energie-mecanique.json` | `**` |
| `1ere-d/physique-chimie/energie-potentielle-de-pesanteur.json` | `**` |
| `1ere-d/physique-chimie/hydrocarbures-insatures-les-alcenes-et-les-alcynes.json` | débordement |
| `1ere-d/physique-chimie/hydrocarbures-satures-les-alcanes.json` | débordement |
| `3eme/edhc/les-institutions-juridictionnelles.json` | figure |
| `3eme/mathematiques/angles-inscrits.json` | `**` |
| `3eme/mathematiques/equations-et-inequations-dans-r.json` | `**` |
| `3eme/mathematiques/racines-carrees.json` | `**` |
| `tle-a1/mathematiques/probabilite-et-variable-aleatoire.json` | `**` |
| `tle-a1/mathematiques/suites-numeriques.json` | `**` |
| `tle-a1/svt/l-heredite-du-sexe-et-du-groupe-sanguin-chez-l-homme.json` | `**` |
| `tle-a2/mathematiques/probabilite.json` | `**`,débordement |
| `tle-a2/mathematiques/suites-numeriques.json` | `**` |
| `tle-a2/svt/l-heredite-du-sexe-et-du-groupe-sanguin-chez-l-homme.json` | `**` |
| `tle-c/mathematiques/barycentre-et-lignes-de-niveaux.json` | `**` |
| `tle-c/mathematiques/divisibilite-dans.json` | `**` |
| `tle-c/physique-chimie/acides-carboxyliques-et-derives.json` | débordement |
| `tle-c/physique-chimie/les-alcools.json` | débordement |
| `tle-d/physique-chimie/acides-carboxyliques-et-derives.json` | débordement |
| `tle-d/physique-chimie/les-alcools.json` | débordement |
| `tle-d/physique-chimie/les-amines.json` | débordement |
| `tle-d/svt/la-transmission-de-deux-caracteres-hereditaires-chez-les-etres-vivants.json` | `**` |
