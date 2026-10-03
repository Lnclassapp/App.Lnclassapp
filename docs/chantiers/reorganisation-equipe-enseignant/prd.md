# PRD — Réorganisation des espaces Équipe et Enseignant

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le porteur réorganise deux espaces livrés (memo, grill G1 à G12). **Équipe** : la configuration (Référentiel, Imports) quitte le quotidien pour une 2e carte de la barre latérale et un menu « Plus » sur téléphone ; le pilotage gagne une recherche de DRENA et, au clic sur une DRENA, les chiffres de chacun de ses établissements. **Enseignant** : l'accueil passe à « Mes classes » (menu ⋮), « Cours » (une bulle par niveau enseigné, à l'illustration de sa matière, plus « Inviter »), « Activités » ; le parrainage devient une carte de la barre latérale ; un exercice s'assigne de nouveau depuis le catalogue, aux seules classes de l'enseignant du niveau du cours, et la page d'une classe signale les assignations hors niveau.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe (tout sous-rôle) | voir la 2e carte « Configuration » et le menu « Plus » ; ouvrir la page Référentiel ; filtrer le pilotage par DRENA en cliquant son nom ; lire « Par établissement » | voir les bascules d'assignation du catalogue (elle n'a pas de classes) |
| Enseignant d'un établissement **actif** | voir la section Cours par niveau, la bulle « Inviter », la carte Parrainage (grand écran) et le bloc d'invitation (téléphone) ; assigner un exercice publié depuis le catalogue à **ses** classes du niveau du cours | assigner à une classe d'un autre niveau ou d'une autre série (refus serveur, existant) ; assigner à une classe dont il n'est pas l'enseignant ; ouvrir la page Référentiel ou le pilotage (403) |
| Enseignant d'un établissement inactif ou en brouillon | voir la section Cours par niveau | voir « Inviter », la carte Parrainage ou le bloc d'invitation (absents, 403 sur la page d'invitation, règle existante) |
| Élève, parent, direction | — (rien ne change) | ouvrir la page Référentiel ou le pilotage (403, règle existante) |

Règles d'autorisation, toutes existantes : `Policies::School::ReadIndicatorsPolicy` (pilotage, dont « Par établissement »), le garde de rôle `team` de `Teams::BaseController` (page Référentiel, comme l'accueil équipe), `Policies::Identity::InviteColleaguePolicy` (bulle « Inviter », carte et bloc d'invitation), `Policies::Classroom::AssignPolicy` et la règle de niveau d'`UseCases::Classroom::AssignResource` (`:conflict`, `other_level`). **Aucune policy n'est créée ni modifiée.**

## 3. Parcours utilisateur

### Chemin nominal — équipe

1. Awa (équipe) ouvre son accueil sur ordinateur : la barre latérale montre sa carte de profil, la carte des destinations (Accueil, Cours, Établissements, Pilotage) puis une carte « Configuration » (Référentiel, Imports). L'accueil n'a plus de section « Référentiel ».
2. Elle ouvre « Référentiel » : les 5 tuiles (DRENA, niveaux, séries, matières, barème des classes) et la structure scolaire, comme avant sur l'accueil.
3. Sur téléphone, la barre du bas montre Accueil, Cours, Établissements, Pilotage et « Plus » ; « Plus » ouvre un menu avec Référentiel et Imports.
4. Elle ouvre « Pilotage » : en tête du tableau « Par DRENA », un champ « Chercher une DRENA ». Elle tape « abidj » : seules les DRENA dont le nom contient « Abidjan » restent.
5. Elle clique « Abidjan 1 » : la page passe sur la DRENA Abidjan 1 (période gardée) ; à la place de « Par DRENA », le tableau « Par établissement » liste ses établissements actifs, 25 par page, triés par élèves.

### Chemin nominal — enseignant

1. Koffi, professeur de Mathématiques en 3ème 1, 3ème 2, 1ère A et Tle D, ouvre son accueil : « Mes classes » (menu ⋮ en haut à droite avec « Modifier mes classes »), puis « Cours », puis « Activités ».
2. « Cours » montre trois bulles à l'illustration des Mathématiques, « 3ème », « 1ère A » et « Tle D » (ses deux 3ème n'en font qu'une), puis la bulle « Inviter ».
3. Il touche « Tle D » : le catalogue liste les cours de Mathématiques de Tle communs à toutes les séries et ceux de la série D, jamais ceux de Tle C.
4. Il ouvre un cours, une fiche : chaque exercice publié porte une bascule « Assigner · Tle D 1 » (une par classe de Tle D qu'il a). Il touche « Assigner » : la modale des jours s'ouvre la première fois, puis l'exercice est assigné, avec son échéance.
5. Sur la page d'un exercice, le bloc « Assigner à mes classes » porte les mêmes bascules.
6. Sur ordinateur, la barre latérale montre sous ses destinations la carte « Parrainage » : compteur, badge Ambassadeur s'il y a lieu, lien, « WhatsApp » et « Copier le lien ». Sur téléphone, le bloc « Inviter un collègue » reste en bas de l'accueil.
7. Sur la page de sa Tle D 1, un exercice de 3ème assigné avant la règle porte la mention « Hors niveau · Vos élèves ne peuvent pas l'ouvrir ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Enseignant sans classe déclarée | « Cours » : aucune bulle de niveau, le texte « Déclarez vos classes pour retrouver ici les cours de vos niveaux. », la bulle « Inviter », et le lien « Voir tout le catalogue » |
| Matière de l'enseignant sans illustration (Anglais, EPS…) | Bulle à l'illustration générique |
| Niveau sans cours publié dans la matière | La bulle reste ; le catalogue filtré dit « Aucun cours ne correspond » avec ses filtres (état vide existant) |
| Établissement de l'enseignant inactif ou en brouillon | Pas de bulle « Inviter », pas de carte Parrainage, pas de bloc d'invitation |
| Aucune classe de l'enseignant au niveau du cours | Pas de bascule ; une phrase au-dessus des exercices : « Aucune de vos classes n'est en <niveau série>. » |
| Première assignation dans une classe sans jours de séance | La bascule ouvre la modale « Quels jours voyez-vous la <classe> ? » (existante) |
| POST d'assignation vers une classe hors niveau | 422, toast d'erreur existant, rien n'est écrit (règle existante, testée de nouveau) |
| Exercice, fiche ou cours non publié | Pas de bascule |
| Équipe sur une fiche ou un exercice du catalogue | Aucune bascule ; son menu ⋮ inchangé |
| Recherche de DRENA sans correspondance | « Aucune DRENA ne correspond. » ; sans JavaScript, toutes les lignes restent |
| DRENA sans établissement actif | « Par établissement » : état vide « Aucun établissement actif dans cette DRENA » |
| Page « Par établissement » hors bornes (`school_page=99`) | Dernière page ; valeur invalide (texte, tableau, octet nul) → page 1 |
| Recherche d'établissement sans correspondance | « Aucun établissement ne correspond. » et un lien « Effacer » |
| Élève, enseignant ou direction sur `/teams/referential` | 403 |

## 4. Critères d'acceptation

```gherkin
# RE-01 — deux cartes dans la barre latérale de l'équipe
Étant donné un membre de l'équipe connecté sur un écran large
Quand il ouvre une page de l'espace équipe
Alors la barre latérale montre la carte des destinations Accueil, Cours, Établissements, Pilotage
Et une carte « Configuration » avec Référentiel puis Imports
Et « Imports » n'est plus dans la carte des destinations

# RE-02 — menu « Plus » sur téléphone
Étant donné un membre de l'équipe sur un écran de 390 px
Quand il touche « Plus » dans la barre du bas
Alors un menu s'ouvre avec Référentiel et Imports
Et la barre du bas compte 5 entrées
Et sur la page Imports, « Plus » porte aria-current="page"

# RE-03 — page Référentiel
Étant donné un membre de l'équipe
Quand il ouvre /teams/referential
Alors il voit les tuiles DRENA, niveaux, séries, matières et barème des classes, chacune vers son écran de gestion
Et la structure scolaire (niveaux et leurs séries)
Et l'entrée « Référentiel » de la carte « Configuration » porte aria-current="page"

# RE-04 — refus de la page Référentiel
Étant donné un élève, un enseignant ou une direction connecté
Quand il ouvre /teams/referential
Alors la réponse est 403

# RE-05 — l'accueil équipe sans Référentiel
Étant donné un membre de l'équipe
Quand il ouvre /teams
Alors il voit « Régions éducatives » puis « Activité récente »
Et aucune section « Référentiel »

# RE-06 — chercher une DRENA
Étant donné le pilotage national avec les DRENA « Abidjan 1 », « Abidjan 2 » et « Bouaké »
Quand l'équipe tape « abidj » dans « Chercher une DRENA »
Alors seules les lignes Abidjan 1 et Abidjan 2 restent visibles
Et quand elle tape « zzz », le message « Aucune DRENA ne correspond. » apparaît

# RE-07 — une DRENA mène à ses établissements
Étant donné le pilotage sur 30 jours
Quand l'équipe clique le nom « Abidjan 1 » dans « Par DRENA »
Alors l'adresse porte drena=<public_id d'Abidjan 1> et period=30d
Et le tableau « Par établissement » remplace « Par DRENA »
Et il liste les établissements actifs d'Abidjan 1 avec leurs classes, enseignants, élèves et élèves actifs
Et un établissement d'une autre DRENA n'y figure pas

# RE-08 — les établissements font le total de leur DRENA
Étant donné une DRENA et ses établissements actifs
Quand on lit sa ligne « Par DRENA » et son tableau « Par établissement » sur la même période
Alors la somme des classes, des enseignants, des élèves et des élèves actifs des établissements égale la ligne de la DRENA

# RE-09 — tri et pages
Étant donné une DRENA de 30 établissements actifs
Quand l'équipe ouvre son pilotage
Alors la page montre 25 établissements, triés par élèves décroissants puis par nom
Et un établissement sans classe y figure avec des zéros
Et le lien « Suivant » mène aux 5 derniers en gardant period et drena

# RE-10 — chercher un établissement de la DRENA
Étant donné le pilotage filtré sur une DRENA dont un établissement « Lycée Moderne de Cocody » est en page 2
Quand l'équipe cherche « cocody » dans le champ du tableau
Alors « Lycée Moderne de Cocody » est listé, sur une page de résultats qui garde period et drena

# RE-11 — ordre et titres de l'accueil enseignant
Étant donné un enseignant configuré
Quand il ouvre son accueil
Alors les sections sont, dans l'ordre, « Mes classes », « Cours », « Activités »
Et le titre « Activité de vos classes » n'apparaît plus

# RE-12 — « Modifier mes classes » dans le menu de la carte
Étant donné un enseignant, avec ou sans classe déclarée
Quand il ouvre le menu « Actions sur mes classes » en haut à droite de « Mes classes »
Alors il y trouve « Modifier mes classes », qui mène à la déclaration des classes
Et la carte n'a plus de pied avec ce bouton

# RE-13 — une bulle par niveau et série enseignés
Étant donné un professeur de Mathématiques en 3ème 1, 3ème 2, 1ère A et Tle D, et une classe archivée de 4ème
Quand il ouvre son accueil
Alors « Cours » montre, dans l'ordre, les bulles « 3ème », « 1ère A », « Tle D » puis « Inviter »
Et chaque bulle de niveau porte l'illustration des Mathématiques
Et aucune bulle « 4ème »

# RE-14 — une bulle mène aux cours de son niveau, de sa série et de la matière
Étant donné des cours publiés de Mathématiques en Tle sans série, en Tle D, en Tle C, et un cours de Physique-Chimie en Tle D
Quand l'enseignant touche la bulle « Tle D »
Alors le catalogue liste les cours de Mathématiques de Tle sans série et de Tle D
Et ni le cours de Tle C ni celui de Physique-Chimie

# RE-15 — catalogue filtré par série
Étant donné le catalogue
Quand on l'ouvre avec level=tle et series=d
Alors il liste les cours de Tle sans série et de la série D, et seulement eux
Et une série inconnue ne donne aucun cours

# RE-16 — enseignant sans classe
Étant donné un enseignant configuré sans classe active cette année
Quand il ouvre son accueil
Alors « Cours » n'a aucune bulle de niveau
Et il lit « Déclarez vos classes pour retrouver ici les cours de vos niveaux. »
Et il voit la bulle « Inviter » et le lien « Voir tout le catalogue »

# RE-17 — matière sans illustration
Étant donné un professeur d'Anglais
Quand il ouvre son accueil
Alors ses bulles de niveau portent l'illustration générique

# RE-18 — « Inviter » réservé à l'établissement actif
Étant donné un enseignant dont l'établissement principal est inactif
Quand il ouvre son accueil sur un écran large ou sur téléphone
Alors il ne voit ni la bulle « Inviter », ni la carte « Parrainage », ni le bloc « Inviter un collègue »

# RE-19 — carte Parrainage dans la barre latérale
Étant donné une enseignante d'un établissement actif, avec 3 filleuls
Quand elle ouvre une page de son espace sur un écran large
Alors la barre latérale charge la carte « Parrainage » sous ses destinations
Et la carte montre « 3 collègues inscrits grâce à vous », le badge « Ambassadeur », son lien /e/<code>?ref=<jeton>, « WhatsApp » et « Copier le lien »
Et un partage WhatsApp est compté comme depuis la page d'invitation

# RE-20 — bloc d'invitation sur téléphone seulement
Étant donné une enseignante d'un établissement actif
Quand elle ouvre son accueil à 390 px
Alors le bloc « Inviter un collègue » est visible en bas de l'accueil
Et à 1280 px il est masqué, la carte « Parrainage » de la barre latérale le remplace

# RE-21 — assigner depuis une fiche du catalogue
Étant donné un professeur de Mathématiques avec les classes Tle D 1 et Tle D 2 et des jours de séance renseignés
Quand il ouvre une fiche publiée d'un cours de Tle D
Alors chaque exercice publié porte une bascule « Assigner » pour Tle D 1 et une pour Tle D 2
Et un clic sur « Assigner » de Tle D 1 assigne l'exercice à Tle D 1 seulement, avec son échéance
Et la bascule devient « Assigné · Pour <jour> » sans recharger la page

# RE-22 — assigner depuis la page d'un exercice
Étant donné le même enseignant
Quand il ouvre la page d'un exercice publié de ce cours
Alors le bloc « Assigner à mes classes » porte une bascule par classe de Tle D

# RE-23 — seulement les classes du niveau et de la série
Étant donné un professeur avec les classes Tle C 1 et Tle D 1
Quand il ouvre une fiche d'un cours de Tle D
Alors seule Tle D 1 a une bascule
Et pour un cours de Tle sans série, Tle C 1 et Tle D 1 en ont une

# RE-24 — aucune classe au bon niveau
Étant donné un professeur sans classe de 3ème
Quand il ouvre une fiche d'un cours de 3ème
Alors aucun exercice n'a de bascule
Et il lit « Aucune de vos classes n'est en 3ème. »

# RE-25 — refus serveur hors niveau (régression)
Étant donné un professeur de la classe 3ème 1
Quand il envoie à la main l'assignation d'un exercice de Tle D à 3ème 1
Alors la réponse est 422 avec le refus « other_level »
Et aucune assignation n'est écrite

# RE-26 — l'équipe ne voit pas de bascule au catalogue
Étant donné un membre de l'équipe
Quand il ouvre une fiche ou un exercice du catalogue
Alors aucune bascule d'assignation n'apparaît
Et son menu ⋮ de gestion est inchangé

# RE-27 — assignation hors niveau signalée
Étant donné une classe Tle D 1 avec une assignation active d'un exercice de 3ème, faite avant la règle de niveau
Quand son enseignant ouvre la page de la classe
Alors la ligne de cet exercice porte « Hors niveau » et « Vos élèves ne peuvent pas l'ouvrir. »
Et les assignations du bon niveau ne portent pas cette mention

# RE-28 — aucun montant, aucun « Versement »
Étant donné un enseignant
Quand il ouvre son accueil
Alors la page ne contient ni « Versement », ni « Prepa », ni « FCFA »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | **Rien de nouveau.** La règle de niveau existe (`Entities::Catalog::LevelAudience`, `UseCases::Classroom::AssignResource` → `other_level`). Aucune entité, aucun port, aucun use case créé ou modifié. |
| Infrastructure | `Queries::Classroom::TeacherHomeQuery` : `material_slug` et `course_levels` (couples niveau/série distincts des classes actives de l'année, triés par position du niveau puis nom de série) · `Queries::Catalog::CourseCatalogQuery` : paramètre `series:` (slug, appliqué avec le niveau : série vide ou cette série) · nouvelle `Queries::School::DrenaSchoolsQuery` (établissements actifs d'une DRENA et leurs quatre chiffres, mêmes définitions que la ligne DRENA, paginés par 25, recherche par nom) · nouvelle `Queries::Classroom::CatalogAssignmentTargetsQuery` (classes de l'enseignant au niveau et à la série d'un cours, jours de séance renseignés ou non, et l'état d'assignation de chaque exercice dans chaque classe) · `Queries::Classroom::ClassroomOverviewQuery` : `out_of_level` par assignation active |
| Delivery | Route `GET /teams/referential` → `Teams::ReferentialsController#show` · `Catalog::CoursesController::FILTERS` + `series` · `Teams::DashboardsController` : `school_page`, `school_q` sous filtre DRENA · `Identity::ReferralsController#show` : réponse au frame `sidebar_referral` · `Catalog::EssentialsController` et `Assessment::ExercisesController` : cibles d'assignation pour l'enseignant |
| UI | `NavigationHelper` (`SECONDARY_DESTINATIONS`, `HOME_SECTIONS`), `shared/navigation/_sidebar`, `_bottom_bar`, `_more_menu` · `teams/homes/show`, `teams/referentials/show` (reprend `_referential`) · `teams/dashboards/_drenas`, `_schools` · `classroom/teacher_homes/show`, `_course_levels` · `identity/referrals/_sidebar_card` · `catalog/essentials/_exercise_progress`, `assessment/exercises/show` · `classroom/assignments/_targets` · `classroom/classrooms/_assigned_exercises` · illustrations `app/assets/images/subjects/*.svg` · tokens `--color-tint-*` · `ui_dropdown` gagne `placement: :above` · contrôleur Stimulus `table-filter` |

## 6. Décisions rattachées

- **ADR : aucun nouveau.** Le chantier n'ajoute ni port, ni table, ni dépendance, ni contrat, ni stratégie de persistance : il ajoute des lectures (CQRS, ADR-0026) et réutilise la règle de niveau existante. Il **amende l'[ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md)** (la lecture « Par établissement », mêmes définitions que « Par DRENA », sans cache, sous le budget de l'ADR-0067), comme le veut l'UDR-0049 §4 pour tout indicateur ajouté.
- **[UDR-0068](../../decisions/udr/0068-configuration-et-pilotage-par-etablissement.md)** — espace équipe : 2e carte « Configuration », menu « Plus », page Référentiel, recherche de DRENA, « Par établissement ». Amende les UDR-0006, 0018, 0049.
- **[UDR-0069](../../decisions/udr/0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md)** — espace enseignant : accueil réordonné, Cours par niveau, carte Parrainage, assignation depuis le catalogue, « Hors niveau ». Amende les UDR-0006, 0013, 0015, 0021, 0026, 0042, 0050, 0062.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Pilotage filtré sur la plus grande DRENA du jeu de mesure, p95 serveur | 361 à 429 ms avant cache, sous 300 ms depuis (ADR-0067) | < 300 ms (budget ADR-0067) | — |
| Accueil enseignant, p95 serveur | *(non mesuré)* | < 100 ms (budget ADR-0067) | — |
| Fiche du catalogue vue par un enseignant, p95 serveur | *(non mesuré)* | < 100 ms | — |
| Requêtes SQL de la carte Parrainage (frame différé) | — | ≤ 2, une seule fois par page et seulement à partir de `lg` | — |
