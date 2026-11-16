# PRD — Faire entrer des classes entières

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass compte 7 élèves. Une seule classe qui aurait adopté l'app en apporterait davantage ([memo](memo.md)). La page Croissance compte les enseignants et le parrainage, mais rien ne relie un enseignant à une classe qui travaille. Le chantier livre d'abord **la plus petite mesure qui désigne le goulot** : une tâche de production en lecture seule, sur les tables actuelles, sans nouvelle table ni traceur (ADR-0049, ADR-0062). Il ne lance ensuite **qu'un seul** des quatre lots d'action, celui que la mesure désigne.

## 2. Verdict au cadrage

**Le goulot ne peut pas être tranché avec certitude depuis le dépôt.** Il est en revanche borné.

| Goulot | Ce que le dépôt en dit | État |
|---|---|---|
| 3. Codes distribués que les élèves n'utilisent pas | Un enseignant qui donne le code d'une classe de 40 à 80 élèves en amène plus de 7. Pour que 7 soit vrai, il faudrait que **chaque** distribution ait échoué presque entièrement. | **Peu probable.** À confirmer par l'indice « devoir donné à une classe vide ». |
| 2. Enseignants inscrits sans classe, ou sans code distribué | Le parcours fait 8 écrans du landing au code. Il **bloque net** si l'établissement n'a aucune classe ouverte pour l'année, et aucun signal ne remonte à l'équipe. L'accueil de l'enseignant propose de copier le code, mais seule la page de la classe propose WhatsApp. | **Suspect principal si des enseignants sont inscrits.** |
| 1. Trop peu d'enseignants | Le CRM ne fait entrer personne. Son brouillon WhatsApp ne contient pas le lien d'inscription de l'établissement, et ses contacts ne sont reliés à aucun compte. La page d'accueil parle à l'élève, et l'enseignant n'a qu'un bouton secondaire. | **Suspect principal si le nombre d'enseignants est proche de zéro.** |
| 4. Notoriété | Hors du code. | Retenu **par élimination** : peu d'enseignants **et** peu d'échanges notés dans le CRM. |

Entre 1 et 2, le chiffre qui tranche est **le nombre d'enseignants inscrits**. La page Croissance l'affiche déjà sur 90 jours. Le reste de la chaîne n'est affiché nulle part.

## 3. La mesure : définitions et règle de verdict

Toutes ces données se lisent sur les tables existantes. Comptes seulement : ni nom, ni numéro, ni identifiant.

### 3.1 Définitions (chacune testée)

| Terme | Définition |
|---|---|
| Enseignant | `users.role = 'teacher'`, `anonymized_at IS NULL`, avec un `teacher_schools.primary`. Voie : `teacher_profiles.joined_via`. Mois d'inscription : `users.created_at`, groupé par mois. |
| Année en cours | `Entities::Classroom::SchoolYear.current(today)`. |
| Classe ouverte | `classrooms.status = 'active'` de l'année en cours. |
| **E1 Inscrit** | Enseignant. |
| **E2 Classes ouvertes** | E1 dont l'établissement principal a au moins une classe ouverte. E1 − E2 = **bloqués** (écran « Aucune classe ouverte »). |
| **E3 Classe cochée** | E1 avec au moins une ligne `teacher_classrooms` vers une classe ouverte. |
| **E4 Classe peuplée** | E3 dont au moins une classe cochée a au moins 1 élève (adhésion `classroom_students` principale, en cours, compte non anonymisé), quelle que soit sa voie. |
| **E5 Devoir donné** | E1 qui a au moins un `classroom_assignments.assigned_by_id` (devoir actif ou archivé). |
| **E6 Classe adoptée** | E3 dont au moins une classe cochée compte **au moins 5 élèves qui ont commencé un exercice** (`exercise_sessions`). C'est « une classe qui s'en sert ». |
| Indice 2b / 3 | Parmi E3 − E4 : ceux qui ont **donné un devoir** à une classe vide (investis, élèves absents, donc plutôt 3) et ceux qui n'en ont pas donné (plutôt 2b). |
| Élèves par classe | Élèves inscrits (non anonymisés, classe principale ouverte), répartis en deux groupes : classe **avec** enseignant coché, classe **sans** enseignant. Pour chaque groupe, leur voie : `standard`, `link` ou `code`. |
| Écoles du CRM | Établissements par étape **saisie** (`crm_accounts.stage`, ou `prospect` sans ligne). Pour chaque étape : le nombre total, combien ont au moins 1 échange noté (`crm_interactions`), au moins 1 enseignant, au moins 1 classe ouverte, au moins 1 classe peuplée. Plus le total des échanges notés sur les 30 derniers jours. |

**Limites** (imprimées en pied de sortie) :
- le partage d'un code n'est pas enregistré, donc 2b et 3 ne se distinguent que par l'indice ;
- une déclaration de classe retirée est effacée ;
- une ré-adhésion écrase la voie ;
- le code appartient à la classe, pas à l'enseignant.

### 3.2 Règle de verdict (seuils par défaut, modifiables par le porteur)

Les étapes se lisent dans l'ordre. Le premier goulot atteint est retenu.

1. **E1 < 10** → goulot **1**. Si, en plus, moins de 10 établissements du CRM ont un échange noté → goulot **4** (personne n'est allé les chercher).
2. **Bloqués ≥ 30 % de E1** → goulot **2a** : établissements sans classe ouverte.
3. **E3 < 50 % de E2** → goulot **2a′** : l'enseignant ne coche pas de classe.
4. **E4 < 50 % de E3** → goulot **2b**, ou **3** si plus de la moitié de E3 − E4 a donné un devoir.
5. Sinon, **médiane d'élèves par classe peuplée < 10** → goulot **3**.

## 4. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Opérateur en production (console Railway) | Lancer `bin/rails entonnoir:classes` | Écrire en base par la tâche : transaction `READ ONLY`, `statement_timeout` de 60 s |
| Team, Teacher, SchoolStaff, Student | — | Aucun écran ne change dans le lot A |

Aucune policy : la tâche n'a pas d'entrée web.

## 5. Parcours

### Chemin nominal

1. Après le train #653, le porteur lance `bin/rails entonnoir:classes` depuis la console Railway de production.
2. La tâche imprime quatre blocs :
   - l'entonnoir enseignants (E1 à E6), au total, par voie d'inscription et par mois d'inscription ;
   - l'indice 2b / 3 ;
   - les élèves par classe avec ou sans enseignant ;
   - les écoles du CRM par étape.
3. Elle imprime ensuite la ligne **« Goulot désigné : … »** (règle §3.2) et les limites.
4. Le porteur colle la sortie dans `journal.md`. L'orchestrateur lance le seul lot d'action correspondant (plan).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun enseignant | Une ligne « Aucun enseignant inscrit. », puis le bloc CRM et le goulot selon la règle (1, ou 4 si le CRM a moins de 10 établissements avec un échange). |
| Une écriture tente de passer dans la transaction | PostgreSQL la refuse, et la tâche échoue sans rien modifier. |
| Requête plus longue que 60 s | La lecture s'arrête avec l'erreur PostgreSQL. Aucune connexion ne reste occupée. |
| Aucun compte CRM | Les établissements sans ligne valent `prospect`. Le bloc s'imprime quand même. |

## 6. Critères d'acceptation

```gherkin
Fonctionnalité: entonnoir des classes en lecture seule

  Scénario: l'entonnoir enseignant compte chaque étage
    Étant donné un enseignant dont l'établissement n'a aucune classe ouverte
    Et un enseignant qui a coché une classe sans élève
    Et un enseignant qui a coché une classe de 5 élèves ayant chacun commencé un exercice
    Quand l'opérateur lance l'entonnoir des classes
    Alors la ligne total affiche E1 3, E2 2, E3 2, E4 1, E5 0, E6 1
    Et la ligne « bloqués » affiche 1

  Scénario: une classe de l'année passée ne compte pas
    Étant donné un enseignant qui n'a coché qu'une classe de l'année scolaire précédente
    Quand l'opérateur lance l'entonnoir des classes
    Alors il est compté en E1 et pas en E3

  Scénario: les comptes anonymisés sont exclus
    Étant donné un enseignant anonymisé et un élève anonymisé dans une classe cochée
    Quand l'opérateur lance l'entonnoir des classes
    Alors ni l'un ni l'autre n'est compté

  Scénario: l'indice sépare les classes vides avec ou sans devoir
    Étant donné deux enseignants qui ont coché une classe vide, dont un seul a donné un devoir
    Quand l'opérateur lance l'entonnoir des classes
    Alors l'indice affiche « classe vide avec devoir : 1 · sans devoir : 1 »

  Scénario: les élèves sont répartis selon que leur classe a un enseignant
    Étant donné un élève venu seul dans une classe sans enseignant
    Et un élève venu par le code dans une classe cochée
    Quand l'opérateur lance l'entonnoir des classes
    Alors le bloc élèves affiche « sans enseignant : standard 1 » et « avec enseignant : code 1 »

  Scénario: les écoles du CRM sont croisées avec l'usage réel
    Étant donné un établissement à l'étape « démo faite » avec un échange noté et un enseignant
    Et un établissement sans ligne CRM
    Quand l'opérateur lance l'entonnoir des classes
    Alors l'étape « démo faite » affiche 1 établissement, 1 avec échange, 1 avec enseignant
    Et l'étape « prospect » compte l'établissement sans ligne

  Scénario: le goulot est désigné selon la règle
    Étant donné 3 enseignants inscrits et 2 établissements avec un échange noté
    Quand l'opérateur lance l'entonnoir des classes
    Alors la sortie affiche « Goulot désigné : 4 »

  Scénario: lecture seule, comptes seulement
    Étant donné des enseignants et des élèves nommés
    Quand l'opérateur lance l'entonnoir des classes
    Alors la sortie ne contient aucun nom, numéro ni identifiant public
    Et une écriture tentée dans la transaction est refusée, sans rien changer en base

  Scénario: base vide
    Quand l'opérateur lance l'entonnoir des classes sur une base sans enseignant
    Alors la sortie affiche « Aucun enseignant inscrit. » et « Goulot désigné : 4 »
```

La règle de verdict est une fonction pure du domaine, testée seule, avec un cas par branche (§3.2, branches 1 à 5, plus la branche « 4 »).

## 7. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::AdoptionVerdict` : Ruby pur, prend les compteurs et rend le goulot (`:teachers`, `:awareness`, `:no_open_class`, `:no_class_ticked`, `:code_not_shared`, `:code_ignored`, `:none`). Seuils en constantes. |
| Infrastructure | `Queries::Classroom::ClassAdoptionQuery` : quatre lectures bornées (enseignants, indice, élèves, CRM), dans le style de `GrowthMetricsQuery`. Aucune table, aucun index, aucune migration. |
| Delivery | `lib/tasks/entonnoir_classes.rake` (`entonnoir:classes`) : transaction `READ ONLY`, `statement_timeout`, impression à largeur fixe. Elle reprend le modèle de `entonnoir:brut`, sans toucher `lib/tasks/entonnoir.rake`. |
| UI | Aucune dans le lot A. |

La requête vit dans `classroom` parce que la règle porte sur la classe. Elle lit `identity` (enseignants), `school` (établissements) et `crm` (étapes) en lecture seule, comme `SchoolUsageQuery` le fait déjà dans l'autre sens.

## 8. Décisions rattachées

- **ADR-XXXX-adoption-par-les-classes-lue-sur-les-tables** (projet) : la « classe adoptée » et l'entonnoir enseignant sont des définitions métier fixes, lues en direct sans table ni traceur. C'est la suite d'ADR-0049 et ADR-0062. Les lots d'action et une future section de la page Croissance devront les réutiliser telles quelles.
- **Aucune UDR pour le lot A** : aucune vue ne change.
- Les lots d'action B1 à B4 (plan) ouvrent chacun **leur** UDR, et leur ADR s'il touche aux droits, **au moment où l'un d'eux est retenu**. Les écrire maintenant, ce serait décider de quatre interfaces dont trois ne seront pas construites.

## 9. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves inscrits (non anonymisés) | 7 | 300 | |
| Classes adoptées (E6) | inconnu, probablement 0 | 5 | |
| Enseignants inscrits (E1) | inconnu (page Croissance, 90 j) | | |
| Enseignants bloqués sans classe ouverte | inconnu | 0 | |
| Goulot désigné | non tranché | — | |
