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
| 2026-11-02 | Lot H — l'environnement Railway `Demo` est un stade à part (jamais PR, aucun chargement des leçons du dépôt, référentiel + jeu standard, comptes équipe seulement avec `DEMO_TEAM_PIN` scellée, dont le PIN courant est appliqué à chaque semis). **Pas de remise à zéro automatique de Demo** (elle supprimerait les données des visiteurs) : accord de l'orchestrateur en attendant l'avis du porteur. Pour repartir de zéro : recréer la base Postgres de Demo au tableau de bord, puis redéployer (le semis recrée tout) ; aucune tâche de remise à zéro distante. Sans `DEMO_TEAM_PIN`, un administrateur équipe inerte (PIN aléatoire, sans second facteur) est créé, car l'import et la publication des leçons exigent un acteur équipe : à confirmer | Décision du porteur du 2026-11-02 ; l'acteur inerte est la seule façon de publier sans PIN public | non |
| 2026-11-02 | Plage de numéros fictifs `0[157]0000xxxx` **confirmée par le porteur** | Point 8 de l'ADR §4 | oui, ADR-XXXX §4 |
| 2026-11-02 | Lot B — durée mesurée de `bin/jeu-standard --reset` (jeu de base + activité complète, machine sans autre charge) : 221 s au total (3 min 42 s), dont 171 s pour l'activité (951 séances ; une première mesure à 12 élèves par classe, 1 122 séances, avait pris 242 s) ; critère « moins de 5 minutes » tenu, avec une marge de ~80 s : le Lot C (grand établissement) devra rester dans ce budget | Mesure du Lot B | non |
| 2026-11-02 | Lot B — empreinte des totaux de l'activité complète : `6e4a653bd4` (9 classes actives, 96 élèves, 108 devoirs, 951 séances, 218 lacunes…) ; sur l'activité réduite du test (3 semaines, 2 classes par établissement, 3 élèves par classe, 27 leçons) : `ea4ae5327a`, identique à un mardi et à un samedi de chargement | Elle change à chaque évolution légitime d'un calcul : la mettre à jour sciemment | non |
| 2026-11-02 | Lot B (suites de la revue) — arrivées datées : enseignants, matières, classes et élèves des trois établissements reculés à la rentrée − 2 à 5 jours (écart tiré de l'id), sauf 2 ou 3 élèves récents par établissement (jamais un élève actif). Empreinte : elle dépend du nombre de semaines tant que la fenêtre n'est pas pleine (12 semaines après la rentrée, soit dès le 24 novembre) ; la commande affiche ce nombre à côté de l'empreinte ; le test couvre une date de septembre. Volume réduit pour tenir le budget à 12 semaines (4 classes par établissement, Tle D à 25 élèves actifs sur 40, échantillon du grand à 8, 1 à 3 séances libres) : 878 séances au lieu de 1 300. Durée mesurée à 12 semaines pleines (veille simulée au 12 décembre) : 164 s de processeur, 391 s d'horloge sur une machine partagée à charge 16 à 25 ; à vide, par proportion avec la mesure du 2 novembre (168 s de processeur pour 221 s d'horloge), ≈ 215 s, sous 4 min 15. Empreintes : complète à 12 semaines `e69647469a`, complète au 2 novembre (8 semaines) `4f72e414d5`, réduite `4da42e1b74` | Revue du Lot B | non |
| 2026-11-02 | Lot B — le collège n'a de leçons v3 qu'en 3ème (4ème, 5ème, 6ème sont dans `sans_v3`) : une seule classe y est active ; « plusieurs classes » vaut pour le lycée (Tle D, 1ère D, 3ème, Tle C, 1ère C) et pour le grand établissement (une classe par niveau : Tle D 1, 1ère D 1, 3ème 1). La classe de l'élève sans activité (lycée Tle A1) reste entièrement sans activité | Décision d'exécution | à confirmer |
| 2026-11-02 | Lot B — `db/seeds/demo/saint_michel.rb` supprimé : il ne tournait plus (`SubmitQuestionAttempt` n'existe plus, ses leçons de Tle D étaient en format 1 retiré). `bin/tester-pr --activite` joue désormais le jeu standard (implicite) puis `standard/activite.rb`. Les semis `pr` et `demo` de `db/seeds.rb` jouent l'activité après le jeu de base ; `development` la joue par `bin/jeu-standard` | Plan Lot B | non |
| 2026-11-02 | Lot I — le jeu standard est semé sur Develop (établissements, classes, comptes ; leçons laissées à `contenus:charger`). Le Lot A rattachait à une classe ou un établissement du jeu un compte déjà là sur un contact du jeu, quel qu'il soit : désormais un compte n'est celui du jeu que s'il en a le rôle et le nom, sinon il est laissé tel quel et signalé, sur tous les stades. Équipe sur Develop : `STANDARD_TEAM_PIN` scellée seule, créée sans second facteur, jamais réécrite ; sans elle, pas de compte équipe (pas d'administrateur inerte : Develop ne publie rien par le jeu) | Décision du porteur du 2026-11-02 (Develop reçoit le jeu, rien supprimé) | oui, ADR-XXXX §4 point 5 |
| 2026-11-02 | Lot I, après la fusion de B — le stade `develop` reçoit aussi `standard/activite` (après `standard`). L'activité ne prend plus partout que les comptes du jeu : élèves inscrits par lui (`joined_via` « standard »), enseignants arrivés par lui (profil « standard ») ; un vrai testeur qui rejoint une classe ou un établissement du jeu sur Develop n'est ni rejoué ni redaté. Sur Develop elle tire ses exercices de toutes les leçons publiées du niveau (pas seulement du manifeste) : l'empreinte y diffère de celle du test. Premier déploiement plus long (activité complète : ~3 min mesurées en local par B) ; un échec y est imprimé et journalisé, jamais levé | Demande de l'orchestrateur ; aucune donnée existante touchée | non |

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

## Lot F — un rôle par environnement

- **Develop** : charge les seuls fichiers du manifeste (`jeu.yml`, `expected_paths`, leçon longue comprise) en `:lesson` ; les autres leçons v3 du programme ne sont plus lues ni remplacées ; aucune suppression (les ~350 leçons présentes restent). Les leçons à sujets gardent `:exercises` partout (ADR-0122), manifeste ou non : décision de lecture à confirmer.
- **Staging** : nouveau mode `:create_only` (ImportCourseTree) pour les leçons v3 sans sujets des dossiers du programme : créée et publiée si aucune leçon de même titre, niveau, matière, série ; sinon rien (statut `ignored`, ni envoi, ni import, ni republication).
- **Production, PR, Demo, inconnu** : inchangés (rien).
- Rapport de chargement (`contenus:charger`) : « N leçon(s) examinée(s) : x créée(s), y ignorée(s), z remplacée(s), w à sujets rechargée(s) ».
- Limite : une leçon créée par Staging dont la publication échoue reste en brouillon aux déploiements suivants (la leçon présente n'est plus touchée) ; l'erreur est journalisée, publication à la main.
- Conséquence sur ADR-0122 et 0123 : amendées par l'ADR du chantier, non modifiées ici. Le jeu standard (comptes, établissements) n'est pas semé sur Develop par ce lot : ajout de données à confirmer.

## Lot G — recette, preuve de vague, règle de fusion

- **Recette** : `docs/recette/` (README avec la table écran → parcours et la règle « on ne rejoue que ce qu'on touche », un parcours par rôle sur les comptes du jeu ; le parcours DRENA passe par le compte équipe terrain `0700003000`).
- **Garde de la section de preuve : retirée après la revue.** Une garde locale dans `bin/ci-quiet` (corps lu dans `tmp/pr-body.md` ou par `gh api`) est contournable et, faute de `gh` dans nos sessions, restait toujours abstenue : une fausse assurance. La règle tient par le modèle de PR (`.github/pull_request_template.md`) et `conventions.md`. Si le porteur veut une vraie garde : une GitHub Action lisant le corps de la PR (`github.event.pull_request.body`, déclenchée aussi sur `edited`).
- **Captures** : `test/system/catalog/lesson_capture_test.rb` (vide sans `CAPTURES_DIR`, 0,1 s déclarés dans `test_timings.yml`, ajouté à la dérogation du budget système) ; pleine page jusqu'à 12 000 px, 390 px et 1280 px, une leçon par matière.
- **Preuve réelle** : `bin/preuve-vague docs/contenus/lecons-traitees/tle-d` (45 fichiers, 5 matières, 293 s, 1 processus) : valider.rb **ok** ; affichage **échec**, 4 leçons en défaut, les mêmes que celles du passage complet du Lot D (3 débordements en physique-chimie : `les-alcools`, `acides-carboxyliques-et-derives`, `les-amines` ; 1 `**` en SVT : `la-transmission-de-deux-caracteres-hereditaires-chez-les-etres-vivants`) ; captures **ok** (10 images). Verdict global ECHEC, code 1 : la vague tle-d n'est pas prouvée tant que ces 4 leçons ne sont pas corrigées (chantiers de contenus). Les captures ne sont pas arrêtées par un affichage en défaut : on voit le défaut.
- **Découverte** : le test d'affichage d'un dossier de 45 fichiers compte plus de 50 tests avec ses pièges et passerait en parallèle (interblocages PostgreSQL, Lot D) : `bin/preuve-vague` impose `PARALLEL_WORKERS=1`.

- **Lot D, après les corrections des leçons (#454, #455, #456, fusionnées le 2026-11-02)** : les 41 leçons en défaut du premier passage sont corrigées (2 causes applicatives — gras coupé par une formule, CSS des blocs d'exercice — et 1 figure EDHC trop haute) ; rejeu complet `LECONS=tout` : 417 leçons, 0 défaut. La tâche `lecons` du train peut donc être bloquante sans bloquer le train.

## Lot C — grand établissement et pages lentes

- **Jeu** : `db/seeds/standard.rb` charge déjà le grand établissement (« Groupe Scolaire Modèle Savane », 42 classes, ~36 élèves par classe) et `activite.rb` y échantillonne l'activité (une classe par niveau, 8 élèves, 12 semaines) : de quoi remplir les pages d'une classe avec historique. **Seeds non touchés**, pas de `grand.rb` (non nécessaire). `bin/jeu-standard --reset` mesuré : **265 s** au total (plafond 300 s).
- **Outil** : `bin/pages-lentes [--seuil=ms] [--role=eleve|enseignant|direction|equipe]` (tâche `pages:lentes`, `script/pages_lentes.rb`) : development seulement (RAILS_ENV, Railway, DATABASE_URL refusés avant Rails ; la tâche refuse aussi). Vraies requêtes par `ActionDispatch::Integration::Session` (login PIN, TOTP pour l'équipe), une page chauffée avant mesure, temps serveur, requêtes SQL (`sql.active_record`, SCHEMA et cache exclus), Bullet et traces de requêtes coupés. Signal au-dessus du seuil (500 ms) ou de 100 requêtes. Durée : environ 16 s pour 48 pages (élève 9, enseignant 12, direction 10, équipe 17). Le programme sort avec un code non nul si une connexion est refusée ou si une page ne répond pas 200 (signal STATUT) ; il refuse aussi RAILWAY_ENVIRONMENT_NAME, DATABASE_URL et une base non locale.
- **Résultat sur le jeu complet** (seuil 500 ms, 100 requêtes, 48 pages, toutes en 200) : **aucune page au-dessus des seuils**. Les plus lentes : élève « ma classe » 371 ms / 83 requêtes ; équipe fiche d'établissement 278 ms / 19 ; élève leçon 226 ms / 39 ; enseignant accueil 198 ms / 24 ; enseignant leçon de la classe 152 ms / 24. Pages lourdes ajoutées : tableau de bord équipe filtré par DRENA (≈130-160 ms / 24), par année (≈80-100 ms / 8-9), établissements d'une DRENA (≈45 ms / 5). Les adresses de notion d'une classe ou du catalogue répondent 301 vers la leçon (déjà mesurée) : non retenues. « Mes annonces » est fermé à l'enseignant par le drapeau du pilote : non mesuré.
- **Chantiers `optimize` proposés** (non signalés par le seuil, mais les plus chargées) :
  1. `optimize eleve-ma-classe` : `/students/classroom`, 371 ms, 83 requêtes, cause probable : requêtes répétées par camarade ou par matière (N+1).
  2. `optimize enseignant-accueil` : `/teachers`, 198 ms, 24 requêtes, cause probable : agrégats de toutes les classes de l'établissement (42) calculés à l'affichage.
  3. `optimize equipe-fiche-etablissement` : `/teams/schools/:id`, 278 ms, 19 requêtes, cause probable : effectifs et activité des 42 classes comptés classe par classe.
  4. `optimize eleve-lecon` : `/courses/:slug` côté élève, 226 ms, 39 requêtes, cause probable : état de chaque notion et exercice lu un par un.
- Limite : mesure à froid de base de données non faite (pages chauffées) ; un seul enseignant et un seul élève (les plus actifs de la classe la plus active).
- **Verdict tle-d rejoué le 2026-11-02 19:07 sur le Develop à jour** : 45 fichiers, valider.rb ok, affichage ok, 10 captures, 272 s, Verdict OK (les 4 défauts du premier passage, 19:00, sont corrigés entre-temps).
- **Revue** : `bin/preuve-vague` refuse un dossier hors `docs/contenus/lecons-traitees` (liens suivis) et n'efface que `tmp/preuves/<vague>`.
