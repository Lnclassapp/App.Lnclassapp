# Journal — Refonte de l'application

## 2026-09-18 — Cadrage, inventaire, plan

### Ce qui a été fait

- **Inventaire exhaustif** de l'application actuelle, par six explorations parallèles : [`inventaire/`](inventaire/), 6 fichiers, 5 582 lignes, ~95 features. Chacune avec son acteur, son parcours, ses règles métier chiffrées, ses tables et son état réel.
- **[`securite.md`](securite.md)** : 18 constats vérifiés, classés par gravité, chacun assorti de la règle à appliquer dans le nouveau projet.
- **[`plan.md`](plan.md)** : graphe de lots calibré pour 72 h, périmètre réduit de 95 à ~25 features.
- **[ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md)** : le PIN à 4 chiffres est conservé, sous six compensations indissociables.

### Ce que l'inventaire a révélé, et qui n'était pas su

Trois fonctionnalités que tout le monde croyait acquises **n'ont jamais tourné** :

1. **Remédiation et lacunes.** Le parcours réel de l'élève passe par `SubmitQuestionAttempt`, qui n'appelle ni la détection ni la résolution. Le seul use case qui pilote le cycle n'est appelé que par un job jamais mis en file. Table, écrans et code existent ; rien ne les atteint.
2. **Création d'exercice.** Le formulaire lève une `NameError` avant de s'afficher (`Entities::Question` au lieu de `Entities::Assessment::Question`), et `questions_attributes` n'est pas dans la liste blanche — les questions n'auraient de toute façon jamais été enregistrées.
3. **« La messagerie ».** C'est un système d'**annonces unidirectionnelles** de l'équipe vers une audience de rôle. Pas de destinataire, pas de fil, pas de réponse, pas d'accusé de lecture. La branche `feature/ticket-5-messaging` ne contient aucun commit absent de `docs/process-v2` : c'est bien l'état final.

**Conséquence sur le budget** : ces trois-là sont à *concevoir*, pas à reprendre. Les estimer comme des portages aurait été le plus gros raté de la refonte.

### Le motif transverse

Sur six contextes, le même défaut : **l'application vérifie l'authentification partout et l'autorisation presque nulle part.** `app/domain/policies/` est annoncé dans `CLAUDE.md` et ne contient aucune policy pour `identity` ni `communication`. D'où la règle qui ouvre le nouveau projet : une policy par use case, chacune avec son test.

Même motif côté UI : 30 briques du design system existent et sont systématiquement contournées. **0 usage conforme sur 927 rayons posés.**

### Une correction que je me suis faite

J'avais recommandé des API strictes pour les composants (`variant:`, `size:`, `state:`) afin de rendre le contournement impossible. Les chiffres du §1.9 de [`inventaire/ui-design-system.md`](inventaire/ui-design-system.md) disent l'inverse : les deux composants aux API les plus rigides totalisent **0 appel**, les deux plus adoptés ont les API les plus laxistes. **L'adoption suit la tolérance de l'API, pas sa qualité.** Le plan a été corrigé : peu de composants, tous substantiels ; beaucoup de tokens aux noms courts ; et l'interdiction des valeurs arbitraires vérifiée par un test, pas par une consigne.

### Décisions prises

| Sujet | Décision |
|---|---|
| Architecture cible | **Hexagonale conservée**, corrigée sur les points listés au §2 du plan |
| PIN à 4 chiffres | **Conservé**, sous les six compensations de l'ADR-0025 |
| Périmètre à 72 h | ~25 features : socle, design system, parcours élève, parcours enseignant |
| Multi-établissements enseignant | **Une école par enseignant en v1** — l'ancien ne l'exploitait pas non plus (`schools.first`) |
| Espace direction d'établissement | **Coupé**, premier à rattraper après la livraison |
| Nouveau projet | Créé par Kamkara, qui y copie `docs/` v2 |
| Mise en ligne | 72 h, date ferme, **de vrais élèves et de vrais enseignants** |

### Ce qui reste ouvert

- **Le seuil de couverture au moment de livrer.** L'[ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md) fixe 100 % bloquant dès le premier commit du nouveau projet. Il a été convenu de « voir avec la couverture des tests au moment venu ». **C'est le point de vigilance numéro un de ce chantier** : si la règle est assouplie le troisième soir sous la pression de la date, on aura reconstruit en trois jours exactement l'application qu'on remplace — celle dont la suite de tests ne se chargeait plus et dont personne ne s'en était aperçu. Si assouplissement il y a, qu'il soit **une décision datée dans un ADR**, pas un `--no-verify` à 23 h.
- **Le repli si le Lot D dérape** : assignation faite par l'équipe, enseignant en lecture seule sur ses classes. **À décider au jour 2, pas au jour 3.**
- Le sort des 8 chantiers de bugs ouverts sur l'application actuelle, qui ne sera pas mise en ligne.

### État à la reprise

Rien n'est lancé. Le Lot 0 peut démarrer immédiatement : 0a (schéma, entités, ports, policies) et 0c (design system) sont indépendants et partent en parallèle.

## 2026-09-22 — Processus complété, plan de recodage complet

### Ce qui a été fait

- **Le processus a été complété avant toute analyse du code**, parce qu'il ne savait pas mener ce qu'on lui demandait :
  - nouveau cycle [`programme.md`](../../workflows/programme.md) — phase 0 d'amorçage du dépôt, planification par vagues, registres des décisions et des contradictions, protocole d'exploration de l'existant ;
  - [hiérarchie des sources de vérité](../../README.md#hiérarchie-des-sources-de-vérité) dans `docs/README.md` — ADR/UDR d'abord, l'inventaire ne décide jamais, « le code fait foi » ne vaut que pour décrire l'existant ;
  - conventions §3 : l'exception `hotfix → main` et son report obligatoire dans `Develop` n'étaient écrits nulle part ;
  - conventions §8, `feature.md`, `blueprints/result.md` : « suivre le code voisin » est sans objet sur un dépôt neuf — les écarts deviennent des décisions de fondation ;
  - skills : `plan-lots` envoyait la PR vers `main` et signalait comme ouvert un écart de nommage déjà corrigé ; `feature` branchait depuis `main` au lieu de `Develop` ; `hotfix` n'avait pas l'étape de report.
- **Le prompt de la demande a été réécrit** en prompt maître + brief d'explorateurs : [`prompt-exploration.md`](prompt-exploration.md).
- **Chantier remis d'aplomb** : le grill du memo était vide alors que ses réponses étaient au journal ; le `prd.md` était le gabarit — il devient le [PRD cadre](prd.md) (matrice acteurs × permissions, exigences transverses, critères Gherkin transverses) ; `plan.md` affirmait « tranché par ADR » pour une décision qu'aucun ADR ne porte, et comptait 16 tables au lieu de 21.
- **[`feuille-de-route.md`](feuille-de-route.md)** : le plan de recodage complet, vagues V0 à V8, décisions de fondation F-01 à F-27, contradictions entre sources, traçabilité des features.

### Ce qui a été découvert

- Deux branches non fusionnées, `feature/ticket-4-auth` et `feature/ticket-4-auth-dashboard`, portent 6 et 7 commits (13 fichiers applicatifs) absents de la branche inventoriée.
- Les documents qui font autorité se contredisent sur au moins quinze points — dont le barème des badges (trois versions), le contexte borné de l'école et de la classe (trois versions) et le nombre d'établissements d'un enseignant.
- La fenêtre de 72 h ouverte le 2026-09-18 est échue ; aucun dépôt cible n'est référencé.

### Ce qui reste ouvert

- **Toutes les décisions de fondation sont au statut « ouvert »** : ce sont des recommandations, pas des décisions. Celles dont la colonne « Bloque » vaut V1 doivent être acceptées avant le premier Lot 0.
- La nouvelle date de la V1.

## 2026-09-22 (suite) — Exploration consolidée dans la feuille de route

### Ce qui a été fait

- **Cinq explorateurs** ont été lancés, un par périmètre, avec le brief de [`prompt-exploration.md`](prompt-exploration.md). Ils ont produit les fichiers [`inventaire/complements-*.md`](inventaire/) : **173 features identifiées** dans les périmètres ID, CO, SC, CL, CA et TR, sans compter AS, dont 28 absentes de l'inventaire.
- **[`feuille-de-route.md`](feuille-de-route.md)** :
  - §3 : six décisions de fondation ajoutées, F-28 à F-33 (authentification et session, navigateurs, chaîne de livraison, shell applicatif, vocabulaire de la fiche, validation collaborative) ; F-20 corrigée ;
  - §4 : contradictions C-16 à C-41 ;
  - §6 : table de traçabilité, feature par feature, avec la vague et le défaut à ne pas reproduire ;
  - §7 : couverture de chaque table de `feature_listing.md`, plus les tables absentes du listing et celles qu'exigent les décisions.
- **[`securite.md`](securite.md)** : défauts n° 19 à 28 ajoutés, dont trois bloquants.
- **[`prd.md`](prd.md) §6** et **[conventions §8](../../guide/conventions.md#8-écarts-connus-entre-la-doc-et-le-code)** alignés sur les registres.

### Ce qui a été découvert

- **L'inventaire du 2026-09-18 se trompait sur des points qui changent le plan** :
  - les élèves de démonstration n'étaient pas connectables, contrairement à ce qu'il affirmait ;
  - `level_series`, `teacher_classrooms` et `action_text_rich_texts` sont bien écrites, alors qu'il les disait mortes ;
  - la plupart des écrans de classe qu'il donnait pour fonctionnels lèvent une exception dès le premier exercice assigné ;
  - trois des quatre écrans d'accueil par rôle lèvent une exception (vérifié à l'exécution).
- **Quatre ADR se déclarent « appliqués » sans l'être** : 0011, 0012, 0020 et 0021 (C-16). L'ADR-0021 ne vit que sur la branche `feature/ticket-4-auth`, où il est cassé : **fusionner cette branche casserait les cinq inscriptions.**
- **Trois nouveaux défauts bloquants de sécurité** :
  - l'inscription « Prépa BAC » donne pour PIN le numéro de téléphone ;
  - le CRUD des établissements est ouvert à tout compte connecté ;
  - les rôles et le personnel d'un établissement se gèrent depuis une autre école.
- **La production est indéterminable.** La configuration Railway n'est pas versionnée, et `main` a 58 commits de retard sur `Develop`.

### Ce qui reste ouvert

- La section AS du §6, qui attend `complements-assessment.md`.
- `feature_listing.md` cite encore trois tables de liaison qui n'existent plus (C-35) : fichier du porteur produit, à corriger par lui.

## 2026-09-22 (fin) — Retraits du plan et intégration d'assessment

### Décision

Le porteur produit **retire du plan pour le moment** :
- les examens et Prepa BAC, c'est-à-dire toute l'ex-V7 ;
- les élèves de démonstration ;
- la messagerie de classe (ex-V6b) et le temps réel ;
- le rôle Parent ;
- LnclassAI.

Les annonces restent en V6. Les 26 features concernées gardent leur ligne dans la traçabilité, marquée « retirée ». Le nouveau dépôt n'en porte aucune trace. Pour réintégrer l'une d'elles, il faut une décision produit datée ici ([`feuille-de-route.md` §5](feuille-de-route.md#retiré-du-plan-2026-09-22)).

### Ce qui a été fait

- `complements-assessment.md` intégré :
  - §6.6 : 40 features ;
  - F-34 (moteur d'évaluation) ;
  - C-42 à C-49 ;
  - `securite.md` n° 29 à 31.
- Traçabilité close : 213 features. 78 sont livrées en V0-V1, 72 en V2-V4 et 15 en V5-V6 ; 48 sont écartées ou retirées.
- Portes cochées : « inventaire complet » et « table de traçabilité ».

### Ce qui a été découvert

- **Les bonnes réponses fuient vers les élèves** par un fragment mis en cache sans le rôle dans sa clé. Le critère Gherkin du PRD cadre impose désormais le cache actif.
- `Exercises::ContentEngineImportService` n'a jamais existé dans aucun commit.
- Les casses d'assignation datent toutes du commit `0991bd3` du 2026-08-29.

### Ce qui reste ouvert

- Les 32 décisions de fondation actives sont toutes des recommandations : aucune n'est acceptée. F-20 et F-24 sont en sommeil avec les features retirées. Trois bloquent la V0 et 21 bloquent la V1.
- La date de la V1.
- `feature_listing.md` : C-35.

## 2026-09-24 — Décision de fondation F-27 tranchée

| Sujet | Décision |
|---|---|
| F-27 — analytique, consentement, CSP | **Option C** : mesure côté serveur, aucun script tiers, CSP bloquante dès la V0, pas de bandeau de consentement. [ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md), `Accepté` |

- **Fait décisif du grill** : personne ne consulte aujourd'hui les données GTM ni Clarity. Les retirer ne fait perdre aucune décision en cours.
- **Coût assumé** : aucune mesure d'audience anonyme ni replay ; les indicateurs métier arrivent en V4 (`pilotage-equipe`). Un outil navigateur (option B : Plausible, Umami) reste possible plus tard, par un ADR qui remplace le 0049.
- **À faire valider hors équipe technique** : le cadrage juridique (loi n° 2013-450, ARTCI) pour les données d'élèves mineurs. L'option retenue est celle qui en dépend le moins.
- **Reste pour débloquer la V0** : F-29 (ADR-0051) et F-30 (ADR-0052).

## 2026-09-24 — Décision de fondation F-29 tranchée

| Sujet | Décision |
|---|---|
| F-29 — navigateurs supportés et budget de performance | **Option C** : plancher testé Chrome 111 / Safari 16.4 / Firefox 128 ; en dessous, page servie avec un bandeau, jamais de 406. Budget gzip bloquant en CI : JS commun ≤ 60 Ko, CSS ≤ 30 Ko. [ADR-0051](../../decisions/adr/0051-navigateurs-supportes-et-budget-de-poids.md), `Accepté` |

- **Fait décisif** : `allow_browser :modern` (Chrome 120) refuse les Android 7 et les WebView en retard, c'est-à-dire le public de l'ADR-0009. Le plancher retenu est celui de Tailwind v4 : en dessous, l'affichage se dégrade mais l'élève entre.
- **Mesures du 2026-09-24** : bundle actuel 132 Ko gzip, dont Trix (éditeur enseignant) téléchargé par chaque élève. Minifié : 108 Ko ; sans Trix ni Action Text : 51 Ko ; Turbo + Stimulus seuls : 40 Ko. Le plafond de 60 Ko tient, avec une douzaine de Ko de marge.
- **Vérifié avant d'écrire** : un bloc `allow_browser` qui ne fait pas de rendu laisse passer la requête (test jetable) ; la gemme `useragent` lit Samsung Internet et UC Browser comme Chrome, mais lit mal Opera, qui reste non surveillé ; le script de budget échoue bien sur l'application actuelle.
- **Laissé ouvert** : rendu KaTeX côté serveur ou chargé à la demande, à trancher en V1 avec TR-41.
- **Reste pour débloquer la V0** : F-30 (ADR-0052).

## 2026-09-24 — Décision de fondation F-30 tranchée · la V0 est débloquée

| Sujet | Décision |
|---|---|
| F-30 — chaîne de livraison et exécution des jobs | `railway.json` versionné ; `Staging` → recette, `main` → production, deux environnements Railway ; worker Solid Queue dans Puma **sans condition**, adaptateur `:solid_queue` aussi en développement ; échecs dans Mission Control Jobs (`/teams/jobs`) ; `/up` testé ; Thruster gardé. [ADR-0052](../../decisions/adr/0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md), `Accepté`, amende l'ADR-0010 |

- **Faits décisifs** : le worker n'a jamais tourné (`SOLID_QUEUE_IN_PUMA` jamais posée), donc la purge horaire non plus ; aucun `railway.json` alors que des fichiers Kamal inutilisés sont versionnés.
- **Découvert en vérifiant** : `force_ssl` et `assume_ssl` sont **commentés** dans la production actuelle, contrairement à ce que suppose `plan.md`. L'ADR-0052 les impose, avec `/up` exclu de la redirection.
- **Choix du porteur, contre la lettre de l'ADR-0010** : Thruster est gardé, parce que la compression sert le budget de l'ADR-0051.
- **Non vérifié, à confirmer au premier déploiement de recette** : l'expansion de `$PORT` par Railway, et la compatibilité de Mission Control Jobs avec la CSP sous nonce de l'ADR-0049.
- **Les trois décisions qui bloquaient la V0 (F-27, F-29, F-30) sont acceptées.** Prochaine étape : ouvrir le chantier `amorcage-depot` et fixer la date de la V1.

## 2026-09-25 — Décisions de fondation acceptées en bloc

| Sujet | Décision |
|---|---|
| ADR-0026 à ADR-0054 (sans 0042 ni 0046) et UDR-0007 | **Acceptés** par le porteur le 2026-09-25, avec trois corrections. Liste et effets : [`decisions-a-accepter.md`](decisions-a-accepter.md) |

**Les trois corrections du porteur**

1. **Badges** ([ADR-0033](../../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)) : quatre paliers, Bronze ≥ 50 %, Argent ≥ 70 %, Or ≥ 80 %, Diamant = 100 % (sans faute). Un badge par exercice, qui ne monte que vers un palier strictement supérieur. Seuils nommés dans le domaine : `PASS_THRESHOLD` 50, `MASTERY_THRESHOLD` 70, `GOLD_THRESHOLD` 80, `PERFECT_THRESHOLD` 100. « Diamant » redevient un terme d'interface autorisé ([UDR-0007](../../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md), glossaire).
2. **Taxonomie** ([ADR-0034](../../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md)) : niveaux, séries, `level_series` et matières (avec leur catégorie, CA-26) sont **créés par l'équipe dans l'interface**, pas seedés en production. Les seeds (`db/seeds/<contexte>.rb`) ne servent qu'en développement et en test, sous un garde d'environnement. La gestion de la taxonomie passe en V1 (CA-18, 19, 20, 22, 24, 25 et TR-13). Les précisions ci-dessous étendent la règle aux DRENA et aux établissements.
3. **Adhésion par code** ([ADR-0028](../../decisions/adr/0028-policies-de-domaine-par-use-case.md)) : pas d'exception. `Classroom::JoinWithCode` a sa policy, `Classroom::JoinPolicy`, qui accepte un acteur anonyme et vérifie une classe active et non archivée, un effectif sous le plafond, un code valide et non révoqué. ADR-0040 et ADR-0041 alignés.

**Précisions du porteur, intégrées avant l'acceptation**

- **A. DRENA** ([ADR-0034](../../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md)) : créées par l'équipe, comme la taxonomie ; aucun seed en production. `drenas.yml` devient une donnée de développement et de test, et un fichier d'exemple dont les slugs servent aux imports d'écoles d'exemple. Aucun format d'import de DRENA : SC-02 est écartée.
- **B. Établissements** ([ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md)) : importés en JSON par l'équipe dès la V1 (format `lnclass.schools`, alias de clés de l'ancien acceptés, rattachement à une DRENA), création unitaire à l'écran possible. Le type `mixte` est conservé (voir plus bas).
- **C. Classes par défaut** ([ADR-0030](../../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)) : générées dans la transaction qui crée ou importe l'établissement, avec le plan de l'ancien (public et privé) ; les séries de chaque niveau sont lues dans les `level_series` saisis par l'équipe. Corrigé : `schools.cycle` (`first`, `both`) en colonne, déduit à l'import du mot « collège » sans tenir compte des accents, modifiable ; correspondance par slug de niveau et de série, jamais par libellé ; niveau ou série absent sauté et compté ; noms toujours espacés (« Tle A1 2 ») ; aucun élève de démonstration ; code d'adhésion unique en base et dans le lot ; plafond et année selon l'ADR-0041.
- **D. Contenu** ([ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md)) : cours en arbre, fiches et exercices (questions et propositions comprises) s'importent en JSON dès la V1.
- **Imports en masse et partiels** ([ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md)) : fichier de 20 Mo au plus, stocké par Active Storage (ADR-0047), traité par un job Solid Queue (ADR-0052) ; validation complète (schéma, puis règles métier) avant toute écriture, erreurs avec leur chemin JSON ; les éléments valides sont écrits par lots `insert_all`, chacun entier ou pas du tout (une école avec ses classes, un cours avec sa descendance, une fiche avec ses exercices, un exercice avec ses questions et propositions) ; doublons ignorés et comptés ; rapport à quatre compteurs (importés, ignorés, en erreur, total). Seul un fichier à l'enveloppe ou à la version invalide, ou au-delà des limites, est rejeté en bloc. L'ADR-0020 passe en « Remplacé partiellement » : §2.1 et §2.2 restent en vigueur. Critère : 500 écoles ou 200 cours complets en moins de 2 minutes en local, par un test de performance écrit.
- **Exemptions** ([ADR-0028](../../decisions/adr/0028-policies-de-domaine-par-use-case.md)) : `Identity::Authenticate`, `Identity::ResetPinWithCode` et `Identity::AcceptInvitation`, use cases anonymes d'avant l'authentification, sont acceptés sans policy. Nouvelle policy V1 : `School::ManageSchoolPolicy`.
- **Remédiation de l'ADR-0043** validée telle quelle.
- **Hotwire pour tous les CRUD** ([ADR-0009](../../decisions/adr/0009-stack-frontend-vanilla-css-tailwind-hotwire.md) §3, point 6) : formulaire dans un Turbo Frame, liste mise à jour par un Turbo Stream. Ligne ajoutée à l'ADR-0009, sans nouvel ADR.
- **E. Feuille de route** : la V1 gagne tout `referentiels-equipe` (DRENA, établissements et leur import, génération des classes, taxonomie) et le chantier `import-contenu`. La V2 garde `espace-direction`, `mon-compte` et `annuaire-equipe`. La V4 garde `catalogue-complet`, `pilotage-equipe` et `installation-pwa`, plus `sous-roles-equipe`. F-12 et F-17 bloquent la V1. Bilan du §6 : 95 fonctionnalités en V1, 53 en V2, 15 plus tard, 50 écartées.

**Valeurs par défaut acceptées sans modification**

- Le niveau s'écrit `2nde`.
- Plafond d'effectif d'une classe : 80 (ADR-0041).
- TOTP obligatoire pour l'équipe et pour la direction (ADR-0031, ADR-0044).
- Verrouillage progressif à 5, 10 puis 20 échecs (ADR-0050).
- Bucket Railway sans sauvegarde automatique en V1 (ADR-0047).
- Sous-rôles d'équipe `admin`, `content`, `field` (ADR-0038).

**Appliqué dans la foulée**

- Statut `Accepté` dans les 24 ADR, l'UDR-0007 et l'index des ADR ; anciens ADR marqués (encadré, lignes `Remplacé par`, `Amendé par` ou `Complété par`, table « Décisions remplacées ») ; UDR-0001 et UDR-0003 marquées pour leur vocabulaire. L'index des UDR est tenu par l'agent des UDR.
- Feuille de route : F-01 à F-34 acceptées (sauf F-09, F-20, F-24, F-31) ; 40 contradictions fermées ; §3, §5 (V1, V2, V4), §6, §6.9 et §7 mis à jour pour la taxonomie, les référentiels et les imports.
- ADR-0012 et ADR-0020 : encadrés alignés sur l'import partiel. ADR-0009 : encadré et §3 complétés (Hotwire pour tous les CRUD).
- Documents de rang 5 corrigés : glossaire (Drena, School), `architecture.md` §2.7 et §5, blueprints `result` et `policy`, [`securite.md`](securite.md).

**Réponses du porteur aux choix du rédacteur (2026-09-25)**

- DRENA : créées par le formulaire de création, sans import ; SC-02 reste écartée.
- Type d'établissement : `mixte` est **conservé**. `school_type IN ('public','private','mixed')`, libellés Public, Privé, Mixte ; à l'import, `mixte` et ses alias sont acceptés. Pour la génération des classes, un établissement mixte suit le barème du privé, comme l'ancien code ([ADR-0030](../../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md), [ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md), glossaire).
- Acceptés : limites d'import (5 000 écoles, 500 cours, 2 000 fiches, 10 000 exercices, 1 000 erreurs détaillées) ; `import_reports` dans le contexte `catalog` ; chantier V4 `sous-roles-equipe` ; noms de classes toujours espacés ; séries A et C rattachées à la 2nde dans le seed de développement.

**Reste ouvert**

- F-09 (UDR-0005) et F-31 (UDR-0006) suivent leur propre acceptation.

## 2026-09-25 — Retour du porteur sur la V1

Consigné en détail dans le [journal de la boucle pédagogique](../boucle-pedagogique/journal.md#retour-du-porteur-du-2026-09-25). Ce qui touche le programme :

- **PRD cadre, §3 (qui peut quoi)** : l'enseignant voit les bonnes réponses de **tout exercice qu'il peut lire**, y compris avant de l'assigner, pour préparer sa classe (au lieu de « classe assignée »). Décision de l'orchestrateur, que le porteur peut rouvrir. L'élève ne voit jamais une bonne réponse avant d'avoir répondu (amendements des ADR-0028 et ADR-0054).
- **F-09** (UDR-0005, thème sombre écarté en V1) et **F-31** (UDR-0006, shell unique par rôle) sont **acceptées** : le point « Reste ouvert » ci-dessus est fermé.
- Protection des branches GitHub abandonnée (offre gratuite, HTTP 403) : le hook pre-commit et la discipline des PR la remplacent ; seul le porteur fait `Develop` → `main`.
- Établissements créés **uniquement par import JSON**, classes générées à ce moment ; éditeur riche (Action Text + Trix) en V1, texte seulement, sans pièce jointe (amendements des ADR-0030 et ADR-0051).


## 2026-09-28 — V1 en production, livraisons hors ordre, CI bloquée

### Ce qui a été livré

- **V1 en production** sur lnclass.com depuis le **2026-09-27** (PR #33 et #36 vers `main`). C'est la date de la V1 que ce journal attendait depuis le 2026-09-22. 94 features de V0-V1 sur 95 sont livrées ; CL-02 (modifier une classe) ne l'est pas. La détection et la résolution des lacunes (AS-14, AS-15, V5) sont parties avec la V1.
- **Trois mises en production le 2026-09-28** (PR #45, #69 et #73 vers `main`) :

| Chantier | Décisions | PR | Vague |
|---|---|---|---|
| [`profil-utilisateur`](../profil-utilisateur/memo.md) — « Mon profil » | ADR-0055, UDR-0041 | #37 | V2 (`mon-compte`, en partie) |
| [`generer-classes`](../generer-classes/memo.md) — classes manquantes | ADR-0056, UDR-0043 | #43 | suite de V1 |
| [`actions-en-menu`](../actions-en-menu/memo.md) — actions en menu ⋮ | UDR-0042 | #40 | suite de V1 |
| [`cycles-en-radio`](../cycles-en-radio/memo.md) — cycles en boutons radio | UDR-0005 ter | #47 | suite de V1 |
| [`code-etablissement`](../code-etablissement/memo.md) — code d'établissement pour l'inscription enseignant | ADR-0057, UDR-0044 | #49 | hors plan, rattaché à V1 |
| [`classes-par-niveau`](../classes-par-niveau/memo.md) — « + / − » par niveau | ADR-0059, UDR-0046 | #48 | hors plan, rattaché à V1 |
| [`bareme-classes`](../bareme-classes/memo.md) — barème des classes en base | ADR-0058, UDR-0045 | #52 | hors plan, rattaché à V1 |
| [`photo-de-profil`](../photo-de-profil/memo.md) | ADR-0060, UDR-0047 | #50 | V2 (`mon-compte`, en partie) |
| [`pilotage-equipe`](../pilotage-equipe/memo.md) | ADR-0062, UDR-0049 | #51 | V4, livré |
| [`afficher-pin`](../afficher-pin/memo.md) — bouton œil du PIN | UDR-0051 | #60 | suite de V1 |
| [`ci-rapide`](../ci-rapide/journal.md) — CI parallèle | ADR-0064 | #53 | outillage |
| [`croissance-parrainage`](../croissance-parrainage/memo.md) — parrainage, démarrage à froid, page Croissance | ADR-0063, UDR-0050 | #71 | hors plan, rattaché à V4 ; livre aussi CL-05 (V3) |

- [`feuille-de-route.md`](feuille-de-route.md) mise à jour : état d'avancement en tête, date de la V1 au §1, §5 (V0 à V6 et chantiers hors plan), §6 (mention « livrée »), §6.9 (colonne des livrées : 101), §8, §9.

### En cours et en attente

- **Durcissement de la photo** : PR #75, ouverte.
- **`canal-whatsapp`** : cadré par une autre session (PR #70, non fusionnée). Il touche la V6.
- **Backlog** : [`verification-whatsapp`](../verification-whatsapp/memo.md), grill interrompu à la question 2.

### Ce qui a dérapé

- **La CI GitHub est bloquée jusqu'au 2026-10-03** : limite de minutes atteinte. D'ici là, chaque fusion exige un `bin/ci` complet en local, et le déploiement de production est déclenché à la main sur Railway. Ajouté au §8 de la feuille de route.
- **Des fusions faites depuis l'interface web ont cassé `Develop`** : #48 et #49, puis #50 et #52, réparées par #56 et #61.
- **Livraison hors ordre** : la V2 et la V4 ont commencé avant la clôture de la V1. La recette `Staging` de la V1 par un rôle distinct n'est pas consignée, et le chantier `boucle-pedagogique` n'est pas clos.

### Décisions du porteur

| Sujet | Décision |
|---|---|
| Demandes en attente par établissement (`croissance-parrainage`) | **Limite de 5 gardée**, malgré le risque de saturation. Amendement de l'ADR-0063 |
| Vérification du numéro par WhatsApp | **Mise au backlog** ([`verification-whatsapp`](../verification-whatsapp/memo.md)) |
| Fusions depuis l'interface web | **À éviter. Option A** : seul l'agent fusionne, après CI verte (locale tant que GitHub est bloquée) |

### Ce qui reste ouvert

- Clore la V1 : consigner la recette `Staging` par un rôle distinct, passer les memos de `boucle-pedagogique` et d'`amorcage-depot` en `livré`, livrer ou écarter CL-02.
- Fermer au §4 les contradictions C-05, C-13, C-32 et C-38, qui renvoient à F-09, acceptée le 2026-09-25.
- ID-19 et ID-20 : livrées pour tous les rôles, à recetter côté direction avec la V2.
- [`features-refonte.md`](../../features-refonte.md) régénérée depuis le §6.

## 2026-09-28 — Clôture V1 et recadrage V2-V6

Demande du porteur : « Avant de commencer d'autres chantiers, fais une mise à jour des versions, de V1 à V6. »

### Clôture de la V1

- **Chantiers clos.** [`boucle-pedagogique`](../boucle-pedagogique/journal.md#clôture) passe en `livré` (en production depuis le 2026-09-27, PR #33 et #36 vers `main`) ; sa clôture liste les PR, les amendements d'ADR et les UDR-0009 à 0040. [`amorcage-depot`](../amorcage-depot/journal.md#clôture) passe en `livré` (#6, 2026-09-25), avec ses écarts 1 et 5 assumés.
- **Recette `Staging` par un rôle distinct : en cours (2026-09-28)**, menée par un autre agent. La case du §9 reste décochée jusqu'à son rapport.
- **Contradictions fermées** : C-05, C-13, C-32 et C-38 (§4). F-09 (UDR-0005) les tranche : sections « Tokens » des UDR-0001 à 0003 remplacées, UDR-0004 non applicable, carte de cours unique et couleur de matière par catégorie (avec l'UDR-0013), aucun mode sombre. Pour C-38, l'ADR-0013 reçoit une précision datée : le thème sombre n'y était qu'un exemple d'état local.
- **CL-02 (modifier une classe) passe en V3**, chantier `vie-de-la-classe` : aucun lot de la V1 ne la portait, et elle touche au plafond et au code de l'ADR-0041 et à la numérotation de l'ADR-0059. Les 94 features de V0-V1 sont livrées.
- Une quatrième mise en production a eu lieu le 2026-09-28 (#77 puis #78 vers `main`) : elle embarque le durcissement de la photo (#75).

### Recadrage des vagues V2 à V6

- **§5 réécrit** : pour chaque vague, le reste réel rangé par chantier et par ID, les décisions acceptées et celles à prendre, les dépendances, la porte inchangée ou précisée. Nouvelles sections : ordre recommandé, tableau de collision V2/V4, dette suivie, questions à poser au porteur (Q1 à Q15).
- **CA-23 (pages des séries) passe de V2 en V4**, `catalogue-complet` : page publique du catalogue, sœur de CA-17 et CA-21 ; en V2 elle aurait créé une collision avec la V4. Décision de l'architecte, que le porteur peut rouvrir.
- **`mon-compte` n'est plus un chantier** : sa partie livrée est close, le profil de direction et la recette du PIN côté direction passent dans `espace-direction`.
- **Rattachements** : `canal-whatsapp` (PR #70) à la V6, après `annonces` ; il pousse les annonces hors de l'application et amende l'ADR-0045 (et l'ADR-0032 pour le PIN). `verification-whatsapp` (backlog) à la V4 s'il reprend : il protège la file de `croissance-parrainage` et pose le port d'envoi commun.
- **Ajouts à la V2** venus des chantiers hors plan : la direction valide les enseignants en attente (ADR-0063) et lit le code de son établissement (ADR-0057).
- [`features-refonte.md`](../../features-refonte.md) aligné : sommaire V1 84, V2 30, V3 12, V4 12 ; total 213, 101 livrées. §6.9 recompté par script : V0-V1 94, V2-V4 54, V5-V6 15, écartées 50.

### Ordre recommandé

Avant tout chantier : recette de la V1, acceptation des décisions en production restées `Proposé` (ADR-0057, 0059, 0063, 0064 ; UDR-0044, 0046, 0050), `bugfix` des tests instables. Puis V2 (`espace-direction`, `annuaire-equipe`) avec `catalogue-complet` (V4) en parallèle ; V3 avec `sous-roles-equipe` (V4) et le lot AS-16 (V5) ; V5 ; V6 (`annonces`, puis `canal-whatsapp`).

### Dette suivie

- Tests instables : `JoinRequestConcurrencyTest` (« cached plan must not change result type »), `RoleHomesTest`, `session_result_test.rb`.
- Photo de profil : limites documentées de l'ADR-0060 (octets libres dans les données compressées, navigateur sans canvas), acceptées.
- Codes d'adhésion non libérés à l'archivage (V3) ; 3 900 codes d'établissement à transmettre à la main (ADR-0057).

### Ce qui reste ouvert

- Rapport de la recette `Staging` de la V1, puis la case du §9.
- Réponses du porteur aux questions Q1 à Q15 (feuille de route, §5).
- Memo de `photo-de-profil` encore « en cours » alors que le chantier est en production et durci.
