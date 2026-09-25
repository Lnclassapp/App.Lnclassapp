# Plan — Nouvelle application, mise en ligne à 72 h

| | |
|---|---|
| **Chantier** | `docs/chantiers/refonte-application/` |
| **Contrainte** | date ferme, 72 h |
| **Utilisateurs au jour 1** | de **vrais élèves et de vrais enseignants**, confirmé |
| **Écrit le** | 2026-09-18 |


> **Ce plan est la vague 1 du programme.** Le plan de recodage complet — toutes les vagues, les décisions à prendre avant chacune, la traçabilité de chaque feature — est dans [`feuille-de-route.md`](feuille-de-route.md). Les décisions de fondation qui bloquent ce plan sont celles du §3 dont la colonne « Bloque » vaut V1 ; aucun Lot 0 ne démarre avant qu'elles soient acceptées.

---

## 1. La décision de périmètre, et pourquoi

L'inventaire recense **~95 features** ([`inventaire/`](inventaire/), 3 478 lignes). Elles ne rentrent pas dans 72 h, et ce n'est pas une question de vitesse de frappe.

Ce qui contraint, c'est la forme du graphe. Le **Lot 0 gèle les contrats** — schéma, entités, ports, policies, design system. Tant qu'il n'est pas fini, aucun lot vertical ne peut partir : c'est la règle 1 de [`workflows/README.md`](../../workflows/README.md#phase-3--planifier). Le parallélisme ne s'applique qu'**après** le socle, et derrière chaque lot il y a la phase 5 — un rôle distinct qui exécute. Trois développeurs ne valident pas 95 features en trois jours, quel que soit le nombre d'agents.

> **Donc on ne livre pas 95 features. On livre une boucle complète et étroite, entièrement testée.**

```
l'équipe publie un cours, une fiche, un exercice
        ↓
un enseignant déclare ses classes et leur assigne le contenu
        ↓
un élève rejoint sa classe avec un code, voit ce qui lui est assigné,
fait l'exercice, obtient son résultat
```

**Environ 25 features au lieu de 95.** Le socle entier, le design system, l'authentification traitée correctement, et les **deux** parcours qui auront de vrais utilisateurs au jour 1. Le reste arrive par lots, sur des fondations qui tiennent — et vite, parce que l'inventaire décrit déjà chaque feature avec ses règles métier.

### Ce qui est explicitement coupé

| Coupé | Pourquoi c'est tenable |
|---|---|
| **Tout l'espace direction d'établissement** | Aucun parcours élève ni enseignant n'en dépend. Les écoles et les classes sont créées par l'équipe |
| **Le multi-établissements enseignant** | **Une école par enseignant en v1** — ⚠️ **contredit l'ADR-0004 (multi-établissements) : à trancher par un ADR qui le remplace, pas encore écrit** (décision F-06 de la [feuille de route](feuille-de-route.md#3-registre-des-décisions-de-fondation)). L'ancien n'exploitait de toute façon pas son propre modèle : il prenait `schools.first`, sans notion d'école courante ni de sélecteur. On assume la simplification au lieu de la subir |
| **Tableaux de bord et rapports de classe** | L'enseignant assigne et voit sa classe ; les rapports détaillés attendent |
| **Remédiation et lacunes** | **N'a jamais tourné en production** — à concevoir, pas à reprendre ([`inventaire/assessment.md`](inventaire/assessment.md)) |
| **Sujets d'examen** | Reporté par décision produit, période de préparation aux examens |
| **Imports JSON en masse** | Saisie manuelle pour le volume du lancement |
| **Annonces** | Aucun parcours élève n'en dépend |
| **Élèves de démonstration** | Générait des milliers de comptes en effet de bord d'un import |
| **Validation collaborative** | Feature d'équipe, aucun parcours utilisateur n'en dépend |

### Ce que la confirmation « vrais élèves et vrais enseignants » impose

Aucun allègement n'est possible. En particulier, **le parcours de récupération de mot de passe reste dans le périmètre** : l'ancienne application n'en avait aucun, et un PIN à 4 chiffres oublié y signifiait la perte définitive du compte, sans recours. Avec de vrais utilisateurs, ça se produit le premier jour, en nombre. C'est un coût de support qu'on ne peut pas reporter.

---

## 2. Les prérequis non négociables

Ils ne sont pas des features, ce sont des propriétés du socle. Aucune livraison sans eux — détail et preuves dans [`securite.md`](securite.md).

- **Aucune route publique ne crée un rôle privilégié.** Le défaut fatal de l'ancienne app : `/team-signup` ouvrait le rôle le plus puissant à un formulaire anonyme.
- **`force_ssl` actif dès le premier déploiement.**
- **`rate_limit` sur l'authentification** — sans quoi un PIN à 4 chiffres avec un numéro de téléphone public tombe en une nuit.
- **`reset_session` à la connexion et à la déconnexion**, et une expiration de session.
- **Une policy par use case, testée.** C'est la règle qui remplace l'empilement de `before_action` — la cause racine de tous les trous d'autorisation trouvés.
- **100 % de couverture, lignes et branches** ([ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md)), `# :nocov:` interdit.

---

## 3. Le graphe de lots

```
Lot 0 — SOCLE  (séquentiel · ~24 h · bloquant)
  0a schéma + entités + ports + policies
  0b authentification complète
  0c baseline design : tokens + bibliothèque UI
        │
        ├──► Lot A — Inscription et connexion élève      ┐
        ├──► Lot B — Publication de contenu (équipe)     ├─ parallèle
        ├──► Lot C — Passage d'un exercice               │  fichiers disjoints
        └──► Lot D — Espace enseignant et assignation    ┘
                        │
                        └──► Lot E — PROUVER (parcours bout en bout, déploiement)
```

---

### Lot 0a — Schéma, entités, ports, policies

- **Couche** : domaine + infrastructure
- **Fichiers** : `db/migrate/*` · `app/domain/entities/{identity,catalog,classroom,assessment}/` · `app/domain/ports/**` · `app/domain/policies/**` · `app/infrastructure/orm/**`
- **Dépend de** : rien
- **Test associé** : `test/domain/domain_purity_test.rb` · un test d'entité par agrégat · un test de policy par policy
- **Done quand** : les 21 tables du périmètre existent, chaque entité a son test, chaque policy a son test, et `bin/rails test` est vert à 100 % de couverture sur `app/domain/`

**Tables du périmètre** — 21 sur les 27 de l'ancienne app :

| Domaine | Tables |
|---|---|
| Identité | `users` · `students` · `teachers` · `teams` |
| Organisation | `schools` · `classrooms` · `classroom_students` · `teacher_classrooms` |
| Taxonomie | `levels` · `series` · `level_series` · `materials` |
| Catalogue | `courses` · `essentials` |
| Évaluation | `exercises` · `questions` · `answers` · `exercise_sessions` · `question_attempts` · `exercise_badges` |
| Assignation | `classroom_assignments` |

Écartées : `school_roles`, `school_staffs`, `teacher_schools` (une école par enseignant en v1), `drenas`, `knowledge_gaps`, `messages`.

**Corrections de schéma exigées** (toutes constatées dans l'ancien, [`inventaire/`](inventaire/)) :
- index unique sur `students.user_id`, `teams.user_id` — les associations sont des `has_one`, l'unicité se garantit en base
- `classrooms.unique_code` : la longueur de colonne doit correspondre au code généré (l'ancien générait 6 caractères pour `limit: 5`)
- index sur les clés étrangères manquantes
- un seul `primary: true` par élève garanti par index partiel

### Lot 0b — Authentification

- **Couche** : domaine + infrastructure + delivery + ui
- **Fichiers** : `app/domain/use_cases/identity/` · `app/controllers/identity/` · `app/views/identity/` · `config/initializers/`
- **Dépend de** : Lot 0a
- **Test associé** : `test/domain/use_cases/identity/*_test.rb` · `test/controllers/identity/*_test.rb` · `test/system/authentication_test.rb`
- **Done quand** : un élève **et** un enseignant s'inscrivent, se connectent, se déconnectent et récupèrent leur mot de passe ; les six prérequis du §2 sont vérifiés par un test qui échoue si on les retire

Le socle d'authentification porte les **trois** rôles de la v1 — `student`, `teacher`, `team` — parce que la policy de chacun se déclare ici. Les écrans d'inscription spécifiques vivent dans les lots A et D.

**Règles métier à reprendre telles quelles** — elles sont justes et se perdraient sans l'inventaire :
- Le **contact téléphonique est l'identifiant**, 10 chiffres, préfixes `01`/`05`/`07` (Moov, MTN, Orange). Normalisation : suppression des non-chiffres, puis retrait de `00225` ou `225`.
- **Le dernier mot du nom complet est le prénom**, tout ce qui précède est le nom de famille. Convention ivoirienne. ⚠️ L'ancien cassait sur les prénoms composés — « Kouassi Jean Baptiste » donnait prénom « Baptiste ». **À corriger, pas à reproduire.**

**À décider par ADR avant de coder** : le PIN à 4 chiffres. Défendable sur téléphone en Côte d'Ivoire, mais 10 000 combinaisons avec un identifiant public exigent en contrepartie `rate_limit`, verrouillage progressif, et un second facteur sur les rôles privilégiés.

### Lot 0c — Baseline design et bibliothèque UI

- **Couche** : ui
- **Fichiers** : `app/assets/stylesheets/application.tailwind.css` (bloc `@theme`) · `app/views/components/**` · `docs/design/`
- **Dépend de** : rien — **peut démarrer en parallèle de 0a**
- **Test associé** : `test/system/design_system_test.rb` — chaque composant rendu dans chacune de ses variantes et de ses états
- **Done quand** : aucune vue du projet n'utilise de valeur arbitraire (`rounded-[…]`, `#hexa`, `p-[13px]`), et chaque composant est appelable avec son API

C'est la **baseline** au sens de l'article de Lenny : le point de départ que tout le monde forke au lieu de le reconstruire.

**Ce qui se reprend de l'ancien** — le noyau réellement adopté : `--color-primary` (#0066ff, 283 usages), l'échelle `--color-neutral-*` (479 usages), `.card-ln` (55), `.badge` (72), `--color-success`/`warning`/`error`.

**Ce qui se complète** — et c'est le vrai travail : l'ancien `@theme` n'a **ni échelle d'espacement, ni token d'ombre**. Un design system sans échelle d'espacement est une palette, pas un système.

**Ce qui change de méthode.** Le §1.9 de [`inventaire/ui-design-system.md`](inventaire/ui-design-system.md) recense **30 briques existantes et systématiquement contournées**. Trois enseignements en découlent, et ils sont contre-intuitifs — ils contredisent la parade évidente, qui aurait été d'imposer des API strictes.

**a) L'adoption suit la tolérance de l'API, pas sa qualité.** Les deux composants aux API les plus rigides — `components/_modal` (`form` et `method` obligatoires) et `components/forms/_field` — totalisent **0 appel**, contre 9 modales et 100 % des champs écrits à la main. Les deux plus adoptés ont les API les plus laxistes : `_dropdown` (une icône, un bloc) et `_button` (qui accepte `label` **ou** `text` pour ne jamais lever d'erreur).

> Une API stricte n'a de sens que si elle est **la seule voie possible** — c'est-à-dire si le style brut correspondant n'est plus disponible. Sinon elle produit l'inverse de ce qu'elle cherche.

**b) Un token qui exige une syntaxe arbitraire est mort en tant que token.** Score des trois rayons : **0 usage conforme sur 927 rayons posés**. `rounded-[var(--radius-ln)]` ne fait gagner aucune frappe face à `rounded-xl` et se lit moins bien.

> Tout token doit produire un utilitaire **au moins aussi court que son équivalent brut**. `rounded-ln` bat `rounded-xl` ; `rounded-[var(--radius-ln)]` ne bat rien.

**c) En dessous de trois déclarations, ce n'est pas un composant, c'est un token.** `.card-ln` est la **seule brique dont l'usage conforme dépasse le contournement** (55 contre 41) : elle encapsule une transition, un décalage au survol et deux ombres — la réécrire coûte cher. `.badge` encapsule cinq déclarations triviales : 55 usages de la base, 7 des variantes, chacun l'habille lui-même.

> Un composant n'est adopté que lorsqu'il devient **moins cher que sa réécriture**. Badge, pastille, filet : à traiter comme des tokens.

**Conséquence sur le périmètre du Lot 0c** : la bibliothèque contient **peu de composants, tous substantiels** (carte, champ complet avec label et erreur, bouton, modale, état vide, état d'erreur, état de chargement — ce dernier n'existe nulle part aujourd'hui), et **beaucoup de tokens aux noms courts**. Et l'interdiction des valeurs arbitraires est vérifiée par un test, pas par une consigne — sans quoi on rejouera les 30 contournements.

### Lot A — Inscription et connexion élève

- **Couche** : delivery + ui
- **Fichiers** : `app/controllers/students/` · `app/views/students/registrations/` · `app/views/identity/sessions/`
- **Dépend de** : Lot 0
- **Test associé** : `test/system/student_onboarding_test.rb`
- **Done quand** : un élève rejoint sa classe via `/c/<code>`, se connecte, et voit son espace

⚠️ **Deux défauts de l'ancien à ne pas reproduire** : le mot de passe laissé vide devenait le numéro de téléphone ; et la création n'était pas transactionnelle, laissant un `User` orphelin qui bloquait définitivement le numéro.

### Lot B — Publier un cours, une fiche, un exercice

- **Couche** : domaine + infrastructure + delivery + ui
- **Fichiers** : `app/domain/use_cases/catalog/` · `app/controllers/catalog/` · `app/views/catalog/`
- **Dépend de** : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/*_test.rb` · `test/system/publish_content_test.rb`
- **Done quand** : un membre de l'équipe crée un cours, y ajoute une fiche, y ajoute un exercice avec ses questions, et le publie

⚠️ **Dans l'ancien, la création d'exercice était cassée à l'affichage** (`NameError` sur `Entities::Question`) et les questions n'étaient de toute façon jamais persistées. Cette feature est donc **à construire**, pas à reprendre. Et un brouillon y était lisible par n'importe qui via son URL directe.

### Lot C — Passer un exercice

- **Couche** : domaine + infrastructure + delivery + ui
- **Fichiers** : `app/domain/use_cases/assessment/` · `app/controllers/assessment/` · `app/views/assessment/`
- **Dépend de** : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/*_test.rb` · `test/system/take_exercise_test.rb`
- **Done quand** : un élève démarre une session, répond aux questions, obtient son score et son badge ; une session terminée est verrouillée

Types de questions à reprendre : `true_false`, `single_choice`, `multiple_correct_2`, `multiple_correct_3`. Barèmes et seuils de badge exacts dans [`inventaire/assessment.md`](inventaire/assessment.md).

⚠️ Les bonnes réponses n'étaient pas cachées au rôle enseignant dans l'ancien. Dans le nouveau, **seul un test de policy garantit qu'un élève ne les voit jamais**.

### Lot D — Espace enseignant et assignation

- **Couche** : domaine + infrastructure + delivery + ui
- **Fichiers** : `app/domain/use_cases/classroom/` · `app/controllers/teachers/` · `app/controllers/classroom/` · `app/views/teachers/` · `app/views/classroom/`
- **Dépend de** : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/*_test.rb` · `test/system/teacher_assigns_resource_test.rb`
- **Done quand** : un enseignant s'inscrit, déclare les classes qu'il enseigne, leur assigne un cours ou un exercice, et l'élève de cette classe le voit dans son espace

C'est le lot le plus lourd des quatre : il porte à lui seul un rôle entier — inscription, onboarding, espace classe, assignation. **Une école par enseignant** — sous réserve de l'ADR qui doit remplacer l'ADR-0004 (voir §1).

⚠️ **Trois défauts de l'ancien à ne pas reproduire** :
- l'onboarding était déduit de `classrooms.empty?` au lieu d'être un état persisté — un enseignant qui retirait ses classes retombait indéfiniment en onboarding, et l'une des deux boucles de redirection infinies venait de là ;
- `@teacher_classrooms` n'était affecté nulle part, ce qui rendait le bouton d'assignation mort dans l'interface ;
- rien ne vérifiait qu'une classe ouverte par un enseignant lui appartenait — **c'est une policy testée, pas un `before_action`**.

Modèle : la table polymorphe `classroom_assignments` ([ADR-0007](../../decisions/adr/0007-hierarchie-pedagogique-et-assignations-polymorphes.md)), suppression en soft delete ([ADR-0016](../../decisions/adr/0016-conservation-historique-assignations.md)).

⚠️ L'ancien portait ici trois `belongs_to` scopés levant `PG::UndefinedTable`, et des constantes ORM inexistantes appelées depuis les queries de lecture — la cause du blocage de connexion des élèves. **Le repository doit être couvert à 100 %, branches comprises.**

### Lot E — Prouver et livrer

- **Couche** : toutes
- **Dépend de** : Lots A, B, C, D
- **Test associé** : le parcours complet, en navigateur réel
- **Done quand** :
  - le parcours bout en bout passe en test système, sur Chrome headless en CI — **pas seulement sous `rack_test`**
  - couverture à 100 % lignes et branches, CI verte
  - un rôle **distinct de l'auteur** a refait le parcours à la main, en conditions réelles
  - les six prérequis du §2 sont vérifiés
  - déploiement Railway, `force_ssl` confirmé actif en production

---

## 4. Les trois risques qui feront déraper ce plan

**Le Lot 0 déborde.** C'est le risque numéro un : il est séquentiel et tout en dépend. S'il n'est pas fini à la fin du jour 1, le parallélisme n'a plus la place de s'exprimer. **Parade** : 0c démarre en parallèle de 0a — le design ne dépend pas du schéma.

**Le Lot D est déséquilibré.** Il porte un rôle entier là où les autres lots portent un parcours. Si un seul lot doit glisser, c'est lui — et il n'y a pas de repli, puisque de vrais enseignants sont attendus au jour 1. **Parade** : le démarrer en premier parmi les lots parallèles, et lui affecter le plus d'agents.

**Les features qui n'ont jamais tourné.** Remédiation, création d'exercice, design system : on croit reprendre, on construit en réalité. **Parade** : elles sont signalées ⚠️ dans chaque lot. Un lot marqué « à construire » ne s'estime pas comme une reprise.

---

## 5. Ce qui vient après les 72 h

Par ordre, et chacun est déjà décrit dans l'inventaire — donc rapide à planifier :

1. **L'espace direction d'établissement** — la coupe la plus coûteuse, à rattraper en premier
2. **Les rapports de classe et le multi-établissements enseignant**
3. **Les imports JSON en masse** — indispensable au passage à l'échelle
4. **La remédiation et les lacunes** — à concevoir, avec son PRD et son ADR
5. **Les annonces**, puis une éventuelle **messagerie de classe** — qui n'a jamais existé et reste à concevoir entièrement
6. **Les sujets d'examen**, à la période de préparation
