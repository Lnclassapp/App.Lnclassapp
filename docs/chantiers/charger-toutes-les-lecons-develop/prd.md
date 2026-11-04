# PRD — Develop charge toutes les leçons v3 du dépôt, entières

## 1. Contexte

Develop doit avoir exactement les leçons des fichiers au format 3 du dépôt, tous niveaux, 3ème comprise, leçons à sujets comprises ([memo](memo.md), ticket #473). Chaque fichier y remplace entière la leçon du même titre, puis seul un fichier changé est rechargé. Les autres environnements ne changent pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Pré-déploiement de Develop (`contenus:charger`) | Créer ou remplacer entière chaque leçon v3 du dépôt, puis la publier | Supprimer une leçon sans fichier ; toucher aux établissements, classes, comptes |
| Team | Voir sur Develop les leçons du dépôt | — (rien de nouveau à l'écran) |
| Student, Teacher, Parent, SchoolStaff | — | Garder, sur Develop, résultats, devoirs envoyés et lectures d'une leçon remplacée (coût consenti) |

Règle d'autorisation inchangée : l'auteur est le plus ancien membre d'équipe actif, `Policies::Catalog::ManageContentPolicy`.

## 3. Parcours utilisateur

### Chemin nominal

1. Develop se déploie ; le pré-déploiement lance `contenus:charger`.
2. Chaque fichier v3 de `docs/contenus/lecons-traitees/*/*/*.json` est importé en mode « leçon entière » : `created` si absente, `replaced` sinon.
3. La cascade de publication suit ; le journal compte les statuts.
4. Au déploiement suivant, un fichier inchangé dit `unchanged`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Fichier changé | Remplacé entier de nouveau (`replaced`) |
| Leçon de Develop sans fichier | Intacte |
| Import refusé (référentiel, schéma) | `refused`, raisons au journal, les autres leçons continuent |
| Staging, production, Demo, PR | Exactement comme avant |

## 4. Critères d'acceptation

```gherkin
# CA-1
Étant donné l'environnement Railway « Develop »
Quand le pré-déploiement lance contenus:charger
Alors chaque fichier v3 de docs/contenus/lecons-traitees, 3ème comprise, est créé ou remplacé entier

# CA-2
Étant donné une leçon à sujets de devoir (Thalès) publiée sur Develop, avec la séance d'un élève
Quand le pré-déploiement lance contenus:charger
Alors elle est remplacée entière, notions, fiches, exercices et sujets du fichier compris
Et la séance de l'élève est effacée

# CA-3
Étant donné un second déploiement sans changement de fichier
Alors aucune leçon n'est rechargée (« inchangée »)

# CA-4
Étant donné une leçon de Develop sans fichier dans le dépôt
Quand le pré-déploiement lance contenus:charger
Alors elle reste telle quelle

# CA-6
Étant donné un fichier à sujets (Thalès) que Develop avait chargé en « exercices et sujets », inchangé depuis
Quand le pré-déploiement lance contenus:charger sur Develop
Alors la leçon est remplacée entière une fois, puis dite « inchangée » au déploiement suivant

# CA-5
Étant donné l'environnement « Staging », « production », « Demo » ou un environnement de PR
Alors le comportement est exactement celui d'avant
```

| CA | Test |
|---|---|
| CA-1 | `automatic_load_stage_test` (tout dossier, sujets ou non → `:lesson`) ; `load_repository_lessons_test` (« Develop loads every v3 file… ») ; `automatic_lesson_load_test` (« Develop loads every v3 file of every folder, 3ème included… ») |
| CA-2 | `load_repository_lessons_test` (« Develop replaces whole a present lesson with subjects… ») ; `automatic_lesson_load_test` (« Develop replaces whole the published Thalès lesson… ») |
| CA-3 | `automatic_lesson_load_test` (« an unchanged file is not loaded again… ») ; `load_repository_lessons_test` (« Develop does not reload an unchanged file… ») |
| CA-4 | `load_repository_lessons_test` (« Develop never deletes… ») ; `automatic_lesson_load_test` (leçon « Leçon ancienne » intacte) |
| CA-6 | `load_repository_lessons_test` et `automatic_lesson_load_test` (« …whose unchanged file was (only) loaded exercises-only before… ») |
| CA-5 | `automatic_load_stage_test` (Staging, production, Demo, PR, inconnu) ; tests Staging de `load_repository_lessons_test` et `automatic_lesson_load_test` (Thalès en `:exercises`, notion renommée refusée, 3ème sans sujet non chargée) |

## 5. Hors périmètre

Voir [memo](memo.md#hors-périmètre).

## 6. Décisions liées

- Pas de nouvel ADR : aucun port, table ni contrat nouveau (le constructeur de `LoadRepositoryLessons` perd seulement `manifest_paths`).
- [ADR-0124](../../decisions/adr/0124-standard-de-test.md) : « Amendement du 2026-11-04 » (remplace la décision n° 1 et le §4.5 pour Develop).
- [ADR-0123](../../decisions/adr/0123-develop-charge-les-lecons-v3-du-programme-entieres.md) : §4.2 amendé (3ème incluse, leçons à sujets en `:lesson` sur Develop).
- Pas d'UDR : aucune vue touchée.
