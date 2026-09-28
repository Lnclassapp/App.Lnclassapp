# PRD — Code d'établissement pour l'inscription des enseignants

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un enseignant choisissait librement son établissement à l'inscription ([memo](memo.md)). Désormais, chaque établissement a un **code d'établissement** unique, que l'équipe lui transmet ; l'enseignant le saisit sur `/teacher-signup`, ou ouvre le lien `/e/<code>`, et son établissement est trouvé automatiquement. Décisions : [ADR-0057](../../decisions/adr/0057-code-d-etablissement.md), [UDR-0044](../../decisions/udr/0044-inscription-enseignant-par-code-d-etablissement.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur anonyme | s'inscrire comme enseignant avec un code valide d'établissement actif ; ouvrir `/e/<code>` (10 par minute) | s'inscrire sans code, choisir un établissement dans une liste, savoir si un code refusé existe |
| Team (tout sous-rôle) | lire le code sur la fiche d'un établissement, le copier, copier le lien, le régénérer | — |
| Teacher, Student, School admin | — | voir la fiche, régénérer un code (403) |
| Personne connectée | — | ouvrir `/teacher-signup` ou `/e/<code>` (renvoyée à son accueil) ; envoyer le formulaire (403) |

Règles : `Policies::Identity::RegisterTeacherPolicy` (inchangée) pour l'inscription ; `Policies::School::ManageSchoolPolicy` pour la régénération (ADR-0028).

## 3. Parcours utilisateur

### Chemin nominal — l'enseignant saisit le code

1. Sur `/teacher-signup`, la rubrique « Établissement et matière » demande le **code d'établissement** (6 caractères, exemple `K7M-4QZ`) et la matière. Plus de DRENA ni de liste d'établissements.
2. Il remplit le reste, envoie : compte créé, rattaché à l'établissement du code (principal), session ouverte, arrivée sur « Quelles classes enseignez-vous ? ».

### Chemin nominal — l'enseignant ouvre le lien

1. `/e/k7m4qz` affiche le même formulaire ; à la place du champ, un bandeau « Votre établissement » donne le nom de l'établissement et sa DRENA, et le code voyage en champ caché. Un lien « Ce n'est pas votre établissement ? Saisir un autre code » ramène à `/teacher-signup`.
2. Même fin.

### Chemin nominal — l'équipe transmet et régénère le code

1. Sur la fiche d'un établissement, l'en-tête montre « Code d'établissement » `K7M-4QZ`, « Copier le code », « Copier le lien » et le lien `/e/k7m4qz`.
2. Menu ⋮ → « Régénérer le code » → confirmation qui dit que l'ancien code cesse de fonctionner et que les enseignants inscrits ne sont pas touchés → « Régénérer le code » : toast « Nouveau code d'établissement : X ». L'en-tête se remplace sans rechargement.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code vide | 422, « Saisissez le code de votre établissement. » sous le champ |
| Code au mauvais format | 422, « Code d'établissement invalide. Il compte 6 caractères, par exemple K7M-4QZ. » |
| Code au format d'un code de classe (3 lettres, 2 chiffres) | 422, « Ce code est un code de classe. Demandez le code d'établissement à votre établissement. » |
| Code inconnu, remplacé, ou d'un établissement inactif ou en brouillon | 422, **le même** « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » ; aucun compte |
| `/e/<code>` dans ces mêmes cas | 404, « Code d'établissement invalide. » et « Saisir le code » |
| Plus de 10 ouvertures de `/e/…` dans la minute, même adresse | 429, « Trop de tentatives », sans aperçu |
| Plus de 5 envois du formulaire dans la minute | 429 dans le formulaire (inchangé) |
| Erreur de saisie après un code valide (PIN non confirmé…) | 422 ; le bandeau de l'établissement remplace le champ, le code est gardé |
| Régénération par un non-membre de l'équipe | 403, code inchangé |
| « Annuler » dans la confirmation | rien ne change |

## 4. Critères d'acceptation

```gherkin
# CE-01 — inscription par le code saisi
Étant donné l'établissement actif « Lycée Classique d'Abidjan » de code « k7m4qz »
Quand un visiteur remplit l'inscription avec le code « K7M 4qz » et l'envoie
Alors il est enseignant, rattaché à ce lycée comme établissement principal
Et il arrive sur la déclaration de ses classes avec le toast de bienvenue

# CE-02 — inscription par le lien
Quand un visiteur ouvre « /e/k7m4qz »
Alors il voit « Lycée Classique d'Abidjan » et sa DRENA, sans champ de code ni liste de DRENA
Et en envoyant le formulaire rempli, il est rattaché à ce lycée

# CE-03 — code refusé, message neutre
Étant donné un code inconnu, un code d'établissement désactivé, un code d'établissement en brouillon
Quand un visiteur s'inscrit avec l'un d'eux
Alors il reçoit 422 et le même message « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. »
Et aucun compte n'est créé
Et « /e/<code> » répond 404 « Code d'établissement invalide. » dans les trois cas

# CE-04 — format et code de classe
Quand un visiteur saisit « ABC » ou « KFM37 »
Alors il reçoit le message de format, ou celui du code de classe, sans aucune recherche

# CE-05 — limite de débit
Quand une même adresse ouvre « /e/<code> » 11 fois dans la minute
Alors la 11ᵉ reçoit 429 sans aperçu de l'établissement

# CE-06 — la fiche montre le code
Étant donné un membre de l'équipe sur la fiche d'un établissement
Alors il voit le code « K7M-4QZ », « Copier le code », « Copier le lien » et le lien « /e/k7m4qz »
Et « Copier le code » met « K7M-4QZ » dans le presse-papiers avec le toast « Code copié »

# CE-07 — régénérer
Quand il choisit « Régénérer le code » dans le menu ⋮ et confirme
Alors un nouveau code valide remplace l'ancien sans rechargement, avec son toast
Et l'ancien code est refusé à l'inscription, les enseignants déjà inscrits restent rattachés
Et la régénération est tracée au journal d'audit

# CE-08 — autorisation
Étant donné un enseignant connecté
Quand il demande la régénération du code d'un établissement
Alors il reçoit 403 et le code ne change pas

# CE-09 — tout établissement a un code
Étant donné des établissements sans code avant la migration
Quand la migration s'exécute
Alors chacun reçoit un code valide, tous distincts, les codes existants ne changent pas
Et la base refuse un établissement sans code, un code au mauvais format ou un doublon

# CE-10 — l'import donne un code
Quand l'équipe importe des établissements
Alors chacun reçoit un code valide, distinct des codes existants et de ceux du lot
```

| Critère | Test |
|---|---|
| CE-01, CE-02, CE-03 (parcours) | `test/system/identity/teacher_signup_test.rb` |
| CE-01 à CE-05 (requêtes) | `test/controllers/identity/teacher_registrations_controller_test.rb` |
| CE-01, CE-03, CE-04 (règles) | `test/domain/use_cases/identity/register_teacher_test.rb`, `test/domain/dtos/identity/teacher_registration_input_test.rb`, `test/domain/entities/school/school_code_test.rb` |
| CE-02, CE-03 (aperçu) | `test/infrastructure/queries/school/school_code_preview_query_test.rb` |
| CE-06, CE-07 (parcours) | `test/system/teams/school_code_test.rb` |
| CE-06 à CE-08 (requêtes) | `test/controllers/teams/school_codes_controller_test.rb`, `test/controllers/teams/schools_controller_test.rb` |
| CE-07, CE-08 (règles) | `test/domain/use_cases/school/regenerate_school_code_test.rb` |
| CE-07 (écriture) | `test/infrastructure/repositories/school/school_repository_test.rb` |
| CE-09 | `test/db/add_school_codes_migration_test.rb`, `test/db/schema_constraints_test.rb` |
| CE-10 | `test/domain/use_cases/school/import_schools_test.rb`, `test/infrastructure/repositories/school/school_repository_test.rb` |

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::SchoolCode` (format, tirage, normalisation, affichage) ; `Entities::School::School#school_code` ; `Dtos::Identity::TeacherRegistrationInput#school_code` (sans DRENA ni établissement) ; `UseCases::Identity::RegisterTeacher` (par code, sans port DRENA) ; `UseCases::School::RegenerateSchoolCode` ; `UseCases::School::ImportSchools` tire les codes ; port `SchoolRepositoryPort` : `find_by_school_code`, `taken_school_codes`, `replace_school_code`, `insert_many` avec code |
| Infrastructure | migration `schools.school_code` (`string(6) NOT NULL`, index unique, `CHECK` de format) et `school_code_rotated_at` ; `SchoolRepository` ; `Queries::School::SchoolCodePreviewQuery` ; `SchoolDetailQuery` et `SchoolsQuery` exposent le code affiché |
| Delivery | `GET /e/:code` → `Identity::TeacherRegistrationsController#with_code` (limité en débit) ; `PATCH /teams/schools/:school_public_id/code` → `Teams::SchoolCodesController#update` |
| UI | `identity/teacher_registrations/{new,_form,_school_preview}` ; `teams/schools/_header` (bloc du code, entrée de menu, confirmation) ; `teams/school_codes/update.turbo_stream` |

## 6. Décisions rattachées

- [ADR-0057](../../decisions/adr/0057-code-d-etablissement.md) — Code d'établissement : colonne, format, génération, régénération, anti-énumération (amende ADR-0030)
- [UDR-0044](../../decisions/udr/0044-inscription-enseignant-par-code-d-etablissement.md) — Inscription enseignant par code d'établissement, et code sur la fiche (amende UDR-0024 et UDR-0036)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Migration de ~3 900 établissements | — | aucun verrou d'écriture tenu plus d'un lot | voir [journal](journal.md) |
