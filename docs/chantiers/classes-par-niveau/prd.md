# PRD — Ajuster le nombre de classes par niveau d'un établissement

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le barème donne à chaque établissement un nombre moyen de classes par niveau ; l'équipe doit l'ajuster à la réalité, en ajoutant ou en retirant des classes ([memo](memo.md)). Sur la fiche d'un établissement, un bloc « Classes par niveau » compte les classes de l'année par niveau et par série, et offre « + » (la classe suivante, nommée comme au barème) et « − » (la dernière, confirmée, seulement si elle n'a jamais servi, supprimée définitivement) ([ADR-0059](../../decisions/adr/0059-ajuster-les-classes-d-un-niveau.md), [UDR-0046](../../decisions/udr/0046-classes-par-niveau.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (tout sous-rôle) | voir le bloc ; ajouter une classe à un couple ouvert d'un établissement actif ; retirer la dernière classe d'un couple si elle n'a jamais servi | ajouter à un établissement désactivé ou en brouillon ; retirer une classe utilisée, ou qui n'est pas la dernière |
| Teacher, Student, School admin | — | appeler les routes (403) |

Règle : `Policies::Classroom::ManageClassroomPolicy` (celle d'« Ajouter une classe », ADR-0028, ADR-0030).

## 3. Parcours utilisateur

### Chemin nominal

1. Sur la fiche d'un établissement, sous le titre « Classes (N) », le bloc « Classes par niveau » liste une ligne par niveau (et par série au second cycle) : libellé (« 6ème », « Tle D »), nombre de classes de l'année, « − » et « + ».
2. « + » sur « 6ème » (4 classes) : la « 6ème 5 » est créée ; toast « Classe « 6ème 5 » ajoutée. Code : KFM37 » ; la ligne passe à 5, le titre de la fiche et la liste des classes se mettent à jour, sans rechargement.
3. « − » sur « 6ème » : une confirmation « Retirer la classe « 6ème 5 » ? » dit qu'elle sera supprimée définitivement et qu'une classe qui a servi ne peut pas l'être. « Retirer la classe » : toast « Classe « 6ème 5 » retirée. », la ligne repasse à 4, la fiche suit.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| « Annuler » ou Échap dans la confirmation | rien n'est retiré |
| La dernière classe a (ou a eu) un élève | toast d'erreur « Cette classe a des élèves : archivez-la plutôt. », rien ne change, confirmation refermée |
| … un enseignant déclaré | « Un enseignant a déclaré cette classe : archivez-la plutôt. » |
| … une assignation (même archivée) | « Cette classe a des cours assignés : archivez-la plutôt. » |
| La classe nommée n'est plus la dernière de son niveau | « Cette classe n'est plus la dernière de son niveau : rechargez la fiche. », rien ne change |
| La classe a déjà été retirée | 404 (toast d'erreur) |
| Ligne à 0 | « − » désactivé |
| Établissement désactivé ou en brouillon | le bloc s'affiche sans « + », avec une note ; un envoi direct reçoit 422 et le motif d'« Ajouter une classe » |
| Couple non ouvert (série déliée) qui a des classes | ligne affichée, sans « + » ; un envoi direct reçoit 422 |
| Nom suivant pris entre-temps (deux clics simultanés) | le nom est recalculé une fois, la classe suivante est créée |
| Sans JavaScript | redirection vers la fiche, message en flash |
| Non-équipe | 403 |

## 4. Critères d'acceptation

```gherkin
# CN-01 — le bloc compte par niveau et par série
Étant donné un lycée avec 4 classes de 6ème et 2 classes de Tle D de l'année, et une 6ème de l'an dernier
Quand l'équipe ouvre sa fiche
Alors le bloc « Classes par niveau » montre « 6ème » à 4, « Tle D » à 2, « Tle A1 » à 0
Et la somme des lignes est le nombre du titre « Classes (N) » et de la colonne « Classes » du tableau des établissements
Et un collège ne montre que les niveaux du premier cycle

# CN-02 — ajouter la classe suivante
Étant donné un lycée actif avec « 6ème 1 » à « 6ème 4 »
Quand l'équipe clique « + » sur la ligne « 6ème »
Alors la classe « 6ème 5 » est créée pour l'année en cours avec un code d'adhésion unique
Et le toast donne son nom et son code en majuscules
Et la ligne passe à 5 sans rechargement, et la fiche liste « 6ème 5 »
Et le journal d'audit trace l'ajout

# CN-03 — la numérotation suit le plus grand numéro, sans collision
Étant donné « Tle D 1 » et « Tle D 3 »
Quand l'équipe ajoute une Tle D
Alors elle s'appelle « Tle D 4 »
Et si « Tle D 4 » est prise au moment de l'écriture, le nom est recalculé une fois

# CN-04 — mêmes règles que « Ajouter une classe »
Étant donné un établissement en brouillon, un établissement désactivé, un collège
Quand l'équipe ajoute une classe
Alors le brouillon et le désactivé sont refusés (motif d'« Ajouter une classe »), le collège refuse la 2nde
Et la fiche d'un établissement non actif n'offre pas « + »

# CN-05 — retirer la dernière classe vide
Étant donné « 6ème 1 » à « 6ème 5 », la « 6ème 5 » sans élève, enseignant ni assignation
Quand l'équipe clique « − » sur la ligne « 6ème » et confirme
Alors la « 6ème 5 » est supprimée définitivement, la ligne passe à 4 sans rechargement
Et le journal d'audit trace le retrait avec le nom de la classe

# CN-06 — refus si la classe a servi
Étant donné une « 6ème 5 » qu'un élève a rejointe (ou qu'un enseignant a déclarée, ou qui a une assignation)
Quand l'équipe la retire
Alors elle est refusée avec « Cette classe a des élèves : archivez-la plutôt. » (ou le motif correspondant)
Et rien n'est supprimé ni tracé

# CN-07 — seulement la dernière
Étant donné une confirmation ouverte pour « 6ème 5 », puis une « 6ème 6 » ajoutée par un autre membre
Quand l'équipe confirme
Alors le retrait est refusé (« n'est plus la dernière »), rien n'est supprimé

# CN-08 — confirmation
Quand l'équipe clique « − »
Alors une confirmation nomme la classe qui sera retirée
Et « Annuler » la ferme sans rien retirer

# CN-09 — autorisation
Étant donné un enseignant, un élève ou une direction connectés
Quand ils appellent l'ajout ou le retrait
Alors ils reçoivent 403 et rien n'est écrit

# CN-10 — au téléphone
Étant donné un écran de 390 px
Alors les lignes tiennent sans défilement horizontal, « − » et « + » font au moins 48 px
Et les parcours CN-02, CN-05 et CN-06 se jouent de la même façon
```

| Critère | Test |
|---|---|
| CN-01 | `test/infrastructure/queries/school/level_classrooms_query_test.rb`, `test/controllers/teams/schools_controller_test.rb` |
| CN-02, CN-03, CN-04 | `test/domain/use_cases/classroom/add_level_classroom_test.rb`, `test/domain/entities/classroom/classroom_numbering_test.rb`, `test/controllers/teams/level_classrooms_controller_test.rb` |
| CN-05, CN-06, CN-07 | `test/domain/use_cases/classroom/remove_level_classroom_test.rb`, `test/infrastructure/repositories/classroom/classroom_repository_test.rb`, `test/controllers/teams/level_classrooms_controller_test.rb` |
| CN-08, CN-10 (et CN-02, CN-05, CN-06 de bout en bout) | `test/system/school/classrooms_by_level_test.rb` |
| CN-09 | `test/controllers/teams/level_classrooms_controller_test.rb` |

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Classroom::AddLevelClassroom`, `UseCases::Classroom::RemoveLevelClassroom` ; `Entities::Classroom::ClassroomNumbering` (préfixe, nom suivant, dernière) ; `Entities::Classroom::Placement` (contrôle niveau/série, extrait de `CreateClassroom`) ; `ClassroomRepositoryPort#names_in_level` et `#delete_if_unused` |
| Infrastructure | `ClassroomRepository#names_in_level`, `#delete_if_unused` (verrou, trois vérifications, suppression) ; `Queries::School::LevelClassroomsQuery` (lignes du bloc) |
| Delivery | `POST /teams/schools/:school_public_id/level-classrooms`, `DELETE /teams/schools/:school_public_id/level-classrooms/:public_id` → `Teams::LevelClassroomsController` |
| UI | `teams/schools/_level_classrooms` rendu dans `show` ; `teams/level_classrooms/update.turbo_stream.erb` (réponse commune de « + » et « − ») |

Aucune migration.

## 6. Décisions rattachées

- [ADR-0059](../../decisions/adr/0059-ajuster-les-classes-d-un-niveau.md) — Ajuster les classes d'un niveau : la suivante au nom du barème, la dernière supprimée seulement si elle n'a jamais servi (précise ADR-0036 et ADR-0041)
- [UDR-0046](../../decisions/udr/0046-classes-par-niveau.md) — Bloc « Classes par niveau » de la fiche d'un établissement (complète UDR-0036 et UDR-0031)
