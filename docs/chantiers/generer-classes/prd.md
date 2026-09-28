# PRD — Générer les classes manquantes des établissements

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

3 851 établissements ont été importés avant le référentiel et n'ont aucune classe ; un réimport les ignore ([memo](memo.md)). L'équipe lance, depuis l'écran Établissements, une génération en arrière-plan qui donne leurs classes aux seuls établissements sans aucune classe de l'année en cours, avec le barème de l'import. Le compte rendu est un rapport de l'écran des imports ([ADR-0056](../../decisions/adr/0056-generation-des-classes-manquantes.md), [UDR-0043](../../decisions/udr/0043-generer-les-classes-manquantes.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (tout sous-rôle) | lancer la génération, suivre son rapport, relancer | lancer une seconde génération tant qu'une première tourne |
| Teacher, Student, School admin | — | voir le bouton, appeler la route (403), lire le rapport (403) |

Règle : `Policies::School::ManageSchoolPolicy` (la même que l'import d'établissements, ADR-0028), vérifiée au lancement **et** au démarrage du job.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur « Établissements », l'équipe clique sur « Générer les classes manquantes » (bouton secondaire de l'en-tête).
2. Une confirmation explique : seuls les établissements actifs ou en brouillon **sans aucune classe de l'année scolaire en cours** reçoivent leurs classes, selon le barème de l'import (public/privé, collège = premier cycle), à partir des niveaux, séries et liaisons actuels ; les autres ne sont jamais modifiés ; la génération tourne en arrière-plan.
3. « Lancer la génération » : toast « Génération des classes lancée. », arrivée sur le rapport de la génération, rechargé toutes les 3 s tant qu'elle tourne.
4. À la fin : établissements dotés, sans classe à générer, en erreur, total ; classes générées ; niveaux et séries sautés s'il y en a.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| « Annuler » ou Échap dans la confirmation | rien n'est lancé |
| Une génération déjà en cours | retour sur « Établissements », toast d'erreur « Une génération des classes est déjà en cours. » ; aucun second rapport |
| Relance après une génération terminée | nouveau rapport ; les établissements dotés sont sautés ; seuls les nouveaux sans classe reçoivent les leurs |
| Référentiel incomplet | établissements sans classe à générer comptés, niveaux/séries sautés comptés, rien d'écrit pour eux |
| Écriture refusée pour un lot | lot rejoué établissement par établissement ; l'établissement refusé passe en erreur (nommé), les autres sont dotés |
| Droit retiré avant l'exécution | rapport `failed`, rien d'écrit |
| Job tué | rapport en cours, libéré après 10 min au lancement suivant (ADR-0039) ; relancer reprend les restants |
| Non-équipe | 403 |

## 4. Critères d'acceptation

```gherkin
# GC-01 — parcours nominal
Étant donné un lycée public sans classe, un collège privé sans classe
Et un lycée qui a déjà 3 classes de l'année
Quand l'équipe clique sur « Générer les classes manquantes » et confirme
Alors le toast « Génération des classes lancée. » s'affiche sur le rapport de la génération
Et une fois le job exécuté, le lycée public a 77 classes et le collège privé 12
Et le lycée qui avait des classes a toujours exactement les 3 mêmes
Et le rapport compte 2 établissements dotés et 89 classes générées

# GC-02 — la confirmation explique et protège
Étant donné l'écran Établissements
Quand l'équipe clique sur « Générer les classes manquantes »
Alors une confirmation dit que seuls les établissements sans aucune classe de l'année scolaire en cours sont concernés
Et « Annuler » la ferme sans rien lancer

# GC-03 — idempotence
Étant donné une génération terminée
Quand l'équipe relance la génération
Alors aucune classe n'est créée pour les établissements déjà dotés

# GC-04 — un seul lancement à la fois
Étant donné une génération en cours
Quand l'équipe lance une génération
Alors elle est refusée avec « Une génération des classes est déjà en cours. » et aucun rapport n'est créé

# GC-05 — candidats
Étant donné des établissements actif, brouillon et désactivé sans classe
Et un établissement dont la seule classe de l'année est archivée
Et un établissement qui n'a que des classes de l'année précédente
Quand la génération s'exécute
Alors l'actif, le brouillon et celui de l'année précédente reçoivent leurs classes
Et le désactivé et celui à la classe archivée ne changent pas

# GC-06 — barème et référentiel incomplet
Étant donné un référentiel où la 1ère n'a aucune série liée
Quand la génération s'exécute pour un lycée public
Alors il reçoit ses classes sans 1ère, et le rapport compte le niveau sauté

# GC-07 — lot refusé
Étant donné un lot dont l'écriture est refusée pour un établissement
Quand la génération s'exécute
Alors cet établissement est en erreur, nommé dans le rapport, et les autres sont dotés

# GC-08 — autorisation
Étant donné un enseignant connecté
Quand il appelle la génération
Alors il reçoit 403, et aucun rapport n'est créé
Et un rapport dont l'auteur a perdu son droit passe « failed » sans rien écrire

# GC-09 — volume
Étant donné 500 établissements sans classe
Quand la génération s'exécute
Alors elle se termine en moins de 60 s, chaque code d'adhésion distinct
```

| Critère | Test |
|---|---|
| GC-01, GC-02 | `test/system/school/generate_classrooms_test.rb` |
| GC-03, GC-06, GC-07, GC-08 (job) | `test/domain/use_cases/classroom/generate_missing_classrooms_test.rb` (ports simulés) |
| GC-04, GC-08 (lancement) | `test/domain/use_cases/classroom/start_classroom_generation_test.rb`, `test/controllers/teams/classroom_generations_controller_test.rb` |
| GC-05 | `test/infrastructure/repositories/school/school_repository_test.rb`, `test/jobs/classroom/generate_missing_classrooms_job_test.rb` |
| GC-09 | `test/performance/classroom/generate_missing_classrooms_performance_test.rb` (`PERF=1`) |

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Classroom::StartClassroomGeneration`, `UseCases::Classroom::GenerateMissingClassrooms` ; `Entities::Catalog::ImportKind::CLASSROOM_GENERATION` et `authorize_report` ; port `SchoolRepositoryPort#without_classrooms` ; `ImportReportRepositoryPort#create` accepte un checksum absent |
| Infrastructure | migration : `kind` `classrooms`, `checksum_sha256` nul pour ce seul type ; `SchoolRepository#without_classrooms` ; job `Classroom::GenerateMissingClassroomsJob` ; `config.x.import_jobs` |
| Delivery | `POST /teams/schools/classroom-generations` → `Teams::ClassroomGenerationsController#create` ; `Teams::ImportsController#show` autorise par `authorize_report` |
| UI | en-tête de `teams/schools/index` (bouton + confirmation) ; rapport : libellés propres au type, ligne et page sans fichier |

## 6. Décisions rattachées

- [ADR-0056](../../decisions/adr/0056-generation-des-classes-manquantes.md) — Génération après coup des classes manquantes, suivie par un rapport d'import sans fichier (amende ADR-0030 et ADR-0039)
- [UDR-0043](../../decisions/udr/0043-generer-les-classes-manquantes.md) — Générer les classes manquantes depuis l'écran Établissements

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| 500 établissements sans classe (mix du plan) | — | < 60 s | voir [journal](journal.md) |
| 3 900 établissements (volume de production) | — | < 10 min (seuil des rapports bloqués) | voir [journal](journal.md) |
