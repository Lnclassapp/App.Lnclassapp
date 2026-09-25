# ADR-0039 : Import du contenu au format arbre versionné, validé par schéma, tout ou rien, avec un rapport persisté

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-17**, bloque la V4 |
| **Remplace** | [ADR-0012](./0012-deep-modules-et-strict-cqrs.md) §3.3 · [ADR-0020](./0020-optimisations-bulk-insert-donnees-catalogue.md) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0012 §3.3 prévoit `ImportCatalogData` et des `Strategies`, l'ADR-0020 §2.1 `insert_all!` dans le repository ; le code fait un troisième choix, cours par cours, sans atomicité (**C-18**).

L'ancien import dédoublonne sur `[name, level_id, material_id]` et crée la taxonomie à la volée. Il ne produit aucun rapport. Son statut est un texte libre (« publié »). Le seul format réellement utilisé est un arbre JSON : cours → `essentials` → `exercises` → `questions` → `answers`. Aucun `insert_all` n'est appliqué pour les cours (**C-16**).

## 2. Moteurs de décision

1. Un fichier mal formé ne laisse aucune trace partielle.
2. Aucune matière, aucun niveau ni aucune série ne naît d'une faute de frappe.
3. L'équipe voit ce qui a été importé, ignoré ou refusé, et pourquoi.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Un format par ressource (CSV) | Tableur | Aucun contenu existant dans ce format |
| B — **Arbre de l'ancien, versionné** | Les fichiers existent déjà | Un gros fichier par import |

## 4. Décision

> **Nous importons le contenu au format arbre de l'ancien, enveloppé et versionné, validé par un schéma JSON, en une seule transaction, et nous persistons un rapport pour chaque import.**

**Format `lnclass.course-tree`, version 1** :

enveloppe `{ "format": "lnclass.course-tree", "version": 1, "courses": [ … ] }` ; chaque cours reprend les clés de l'ancien (`name`, `subtitle`, `content`, `level_name`, `material_name`, `series_name`, `essentials[]` → `exercises[]` → `questions[]` → `answers[]`). La clé `status` est **supprimée** : tout contenu importé naît `draft` (ADR-0035). `question_type` ∈ `true_false`, `single_choice`, `multiple_correct_2`, `multiple_correct_3` ; `exercise_type` ∈ `fixation`, `evaluation`.

Le schéma vit dans `config/schemas/course_tree.v1.json` ; il est validé avec la gemme `json_schemer`. Un fichier sans `format` ni `version` est refusé.

**Résolution de la taxonomie**, sans jamais rien créer :

`level_name`, `material_name` et `series_name` sont comparés, après `parameterize`, au `slug` des lignes créées par l'équipe (ADR-0034) ; `material_name` peut aussi valoir le `shortname`. « Physique Chimie » est donc résolu en `physique-chimie`. Un nom inconnu, ou une série hors `level_series`, est une erreur de ligne.

**Règles de cohérence**, en plus du schéma : exactement 1 réponse correcte pour `true_false` et `single_choice`, 2 et 3 pour les deux autres ; `true_false` a exactement 2 réponses ; tout exercice a au moins une question.

**Doublons** : un cours dont `(name squish, level, material, series)` existe déjà est **ignoré** et compté `skipped_existing`. La V4 ne met jamais à jour un contenu existant par import.

**Exécution** : use case `Catalog::ImportCourseTree` (policy `Catalog::ManageContentPolicy`, ports `Ports::Catalog::CourseRepositoryPort` et `Ports::Assessment::ExerciseRepositoryPort`), lancé par le job `Catalog::ImportCourseTreeJob`, fichier ≤ 5 Mo. **Une** transaction : la moindre erreur annule tout. Insertion ligne à ligne par les repositories, sans `insert_all` (volumes de l'ordre de la centaine de lignes).

**Table `import_reports`** (contexte `catalog`) :

| Colonne | Contenu |
|---|---|
| `public_id` | identifiant exposé |
| `kind` | `course_tree` ou `schools` (V2, ADR-0034) |
| `format_version` | version du format |
| `filename`, `checksum_sha256` | fichier importé |
| `status` | `pending`, `running`, `succeeded` ou `failed` |
| `counts` | `jsonb` : `created`, `skipped_existing` |
| `errors` | `jsonb` : `[{ path: "courses[3].essentials[0].exercises[1]", code:, message: }]` |
| `imported_by_id` | FK `users` |
| `started_at`, `finished_at` | |

Les rapports sont consultables dans l'espace équipe. Un import déjà réussi du même `checksum_sha256` donne `:conflict`. Journal : `import.run`.

## 5. Conséquences

### 🟢 Positives

- C-18 est fermée : un seul chemin d'import, atomique et expliqué.
- Les doublons de taxonomie de l'ancien ne peuvent pas revenir.
- Tout est brouillon : rien d'importé n'est visible des élèves sans un geste de publication.

### 🔴 Coûts consentis

- Les fichiers de l'ancien doivent être enveloppés, et leur `status` retiré.
- Une seule erreur rejette tout le fichier : on corrige et on relance.
- Pas de mise à jour par import : corriger un contenu importé se fait à l'écran.
- Une gemme de plus (`json_schemer`).

## 6. Notes d'implémentation

```json
{
  "format": "lnclass.course-tree",
  "version": 1,
  "courses": [{
    "name": "Physique quantique", "level_name": "Tle", "material_name": "Physique Chimie", "series_name": "D",
    "subtitle": "…", "content": "…",
    "essentials": [{ "name": "Dualité onde-corpuscule", "subtitle": "Les bases", "content": "…",
      "exercises": [{ "title": "…", "description": "…", "exercise_type": "fixation",
        "questions": [{ "content": "…", "question_type": "single_choice",
          "answers": [{ "content": "…", "is_correct": true }, { "content": "…", "is_correct": false }] }] }] }]
  }]
}
```

## 7. Comment vérifier que la décision est respectée

- Tests de use case, avec un fichier de fixture par cas : matière inconnue → `failed` et zéro ligne créée ; cours existant → `skipped_existing` ; fichier sans enveloppe → `failed`.
- Test de schéma : `config/schemas/course_tree.v1.json` accepte la fixture ci-dessus.
- `grep -rn "find_or_create_by" app/infrastructure/repositories/catalog` ne renvoie rien.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0012 §3.3 et l'ADR-0020 en entier (C-18, C-16). Le reste de l'ADR-0020 concernait les élèves démo, retirés du plan.

## 9. Points à confirmer par le porteur

- Import en tout ou rien.
- Doublons ignorés, jamais mis à jour.
- Tout contenu importé naît brouillon.
