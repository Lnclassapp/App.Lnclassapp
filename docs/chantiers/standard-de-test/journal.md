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
| 2026-11-02 | Lot B (retours de captures) — le trimestre ne commence jamais avant la rentrée (1er septembre) : fenêtre = max(rentrée, veille − 12 semaines) → veille, soit 8 semaines au 2 novembre, 12 à partir du 24 novembre ; en deçà de 2 semaines depuis la rentrée, rien n'est joué. L'empreinte complète n'est donc stable d'une date à l'autre qu'à partir du 24 novembre (la réduite, de 3 semaines, dès le 22 septembre). Échéances : plus de `update_columns`, `AssignResource` les calcule, le jour de séance étant posé à chaque devoir sur le jour d'échéance voulu (assignation + 3 jours, lundi si dimanche) ; rendus à temps (0 à 2 jours) et en retard (5 jours et plus) ne dépendent pas du jour de la semaine. Classe réaliste : ~60 % de réguliers, ~25 % d'irréguliers, ~15 % de décrochés ; 2 devoirs à venir ; séances « fait seul » sur des exercices non assignés, la moitié dans les 7 derniers jours. Durée `bin/jeu-standard --reset` : 224 s ; empreinte complète `3dfb22c3a9` ; réduite `f58319b0a2` | Retours du porteur sur les captures | non |
| 2026-11-02 | Lot B — le collège n'a de leçons v3 qu'en 3ème (4ème, 5ème, 6ème sont dans `sans_v3`) : une seule classe y est active ; « plusieurs classes » vaut pour le lycée (Tle D, 1ère D, 3ème, Tle C, 1ère C) et pour le grand établissement (une classe par niveau : Tle D 1, 1ère D 1, 3ème 1). La classe de l'élève sans activité (lycée Tle A1) reste entièrement sans activité | Décision d'exécution | à confirmer |
| 2026-11-02 | Lot B — `db/seeds/demo/saint_michel.rb` supprimé : il ne tournait plus (`SubmitQuestionAttempt` n'existe plus, ses leçons de Tle D étaient en format 1 retiré). `bin/tester-pr --activite` joue désormais le jeu standard (implicite) puis `standard/activite.rb`. Les semis `pr` et `demo` de `db/seeds.rb` jouent l'activité après le jeu de base ; `development` la joue par `bin/jeu-standard` | Plan Lot B | non |

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

## Lot F — un rôle par environnement

- **Develop** : charge les seuls fichiers du manifeste (`jeu.yml`, `expected_paths`, leçon longue comprise) en `:lesson` ; les autres leçons v3 du programme ne sont plus lues ni remplacées ; aucune suppression (les ~350 leçons présentes restent). Les leçons à sujets gardent `:exercises` partout (ADR-0122), manifeste ou non : décision de lecture à confirmer.
- **Staging** : nouveau mode `:create_only` (ImportCourseTree) pour les leçons v3 sans sujets des dossiers du programme : créée et publiée si aucune leçon de même titre, niveau, matière, série ; sinon rien (statut `ignored`, ni envoi, ni import, ni republication).
- **Production, PR, Demo, inconnu** : inchangés (rien).
- Rapport de chargement (`contenus:charger`) : « N leçon(s) examinée(s) : x créée(s), y ignorée(s), z remplacée(s), w à sujets rechargée(s) ».
- Limite : une leçon créée par Staging dont la publication échoue reste en brouillon aux déploiements suivants (la leçon présente n'est plus touchée) ; l'erreur est journalisée, publication à la main.
- Conséquence sur ADR-0122 et 0123 : amendées par l'ADR du chantier, non modifiées ici. Le jeu standard (comptes, établissements) n'est pas semé sur Develop par ce lot : ajout de données à confirmer.

## Lot C — grand établissement et pages lentes

- **Jeu** : `db/seeds/standard.rb` charge déjà le grand établissement (« Groupe Scolaire Modèle Savane », 42 classes, ~36 élèves par classe) et `activite.rb` y échantillonne l'activité (une classe par niveau, 8 élèves, 12 semaines) : de quoi remplir les pages d'une classe avec historique. **Seeds non touchés**, pas de `grand.rb` (non nécessaire). `bin/jeu-standard --reset` mesuré : **265 s** au total (plafond 300 s).
- **Outil** : `bin/pages-lentes [--seuil=ms] [--role=eleve|enseignant|direction|equipe]` (tâche `pages:lentes`, `script/pages_lentes.rb`) : development seulement (RAILS_ENV, Railway, DATABASE_URL refusés avant Rails ; la tâche refuse aussi). Vraies requêtes par `ActionDispatch::Integration::Session` (login PIN, TOTP pour l'équipe), une page chauffée avant mesure, temps serveur, requêtes SQL (`sql.active_record`, SCHEMA et cache exclus), Bullet et traces de requêtes coupés. Signal au-dessus du seuil (500 ms) ou de 100 requêtes. Durée : 16 s pour 45 pages.
- **Résultat sur le jeu complet** (seuil 500 ms, 100 requêtes) : **aucune page au-dessus des seuils**. Les plus lentes : élève « ma classe » 423 ms / 83 requêtes ; enseignant accueil 317 ms / 24 ; équipe fiche d'établissement 314 ms / 19 ; élève leçon 305 ms / 39 ; enseignant leçon de la classe 245 ms / 24 ; direction classe 203 ms / 11. Pages non mesurées : « mes annonces » (fermé à l'enseignant par le drapeau du pilote).
- **Chantiers `optimize` proposés** (non signalés par le seuil, mais les plus chargées) :
  1. `optimize eleve-ma-classe` : `/students/classroom`, 423 ms, 83 requêtes, cause probable : requêtes répétées par camarade ou par matière (N+1).
  2. `optimize enseignant-accueil` : `/teachers`, 317 ms, 24 requêtes, cause probable : agrégats de toutes les classes de l'établissement (42) calculés à l'affichage.
  3. `optimize equipe-fiche-etablissement` : `/teams/schools/:id`, 314 ms, 19 requêtes, cause probable : effectifs et activité des 42 classes comptés classe par classe.
  4. `optimize eleve-lecon` : `/courses/:slug` côté élève, 305 ms, 39 requêtes, cause probable : état de chaque notion et exercice lu un par un.
- Limite : mesure à froid de base de données non faite (pages chauffées) ; un seul enseignant et un seul élève (les plus actifs de la classe la plus active).
