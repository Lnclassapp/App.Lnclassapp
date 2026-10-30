# Journal — « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Mesure « avant » (PRD §7), Lot 0, 2026-10-30** : `GET /courses/:slug` pour un élève de la classe du niveau de la leçon, sans copie
  ni devoir, leçon de 4 notions × 3 exercices (4 questions de 4 propositions chacun) + 1 exercice « Toute la leçon », avec
  `PrepareInterrosQuery` d'aujourd'hui : **36 requêtes SQL**, 0 en cache. Méthode : test d'intégration jetable (hors dépôt),
  deuxième `GET` après un premier d'échauffement, abonné à `sql.active_record` ; sont écartées les requêtes `SCHEMA`,
  `TRANSACTION` et `BEGIN` / `COMMIT` / `SAVEPOINT` / `RELEASE`. À refaire à l'identique après le Lot B.
- La clé étrangère d'une table de l'application doit être en `on_delete: :restrict` (`test/db/schema_constraints_test.rb`) : `subjects`
  et `exercises.subject_id` l'ont, contrairement à l'extrait de l'ADR §6.
- `RAILS_ENV=test bin/rails db:migrate` re-dump `db/schema.rb` depuis la base de test, périmée : après une migration, recharger la base de
  test par `db:schema:load`, jamais par `db:migrate`.
- `test/design/design_tokens_test.rb` réserve « Source Serif » aux fichiers de la fiche de cours (`SHEET_EXCEPTION`) : `prepare_sheet.css`
  n'y figure pas (voir le point remonté à l'orchestrateur).

### Lot A — import de l'indice et des sujets

- L'import écrit l'indice (`hint`, nettoyé par `strip`, 1 à 400) et les sujets (`subjects[]` : titre 1 à 200, notions 1 à 600, 10 sujets au
  plus, 10 exercices au plus par sujet, un type inattendu refusé au chemin de la clé). Les exercices d'un sujet se placent après ceux de
  la leçon ; `replace_draft` supprime puis réécrit les sujets et rend `subjects:`. `write` garde sa forme (pas de clé `subjects`).
- Un exercice « avec une notion » = un exercice de sujet portant une clé `notion` non vide (le fichier n'a pas d'autre moyen de citer une
  notion) ; l'erreur est notée à `subjects[i].exercises[j].notion` et porte `subject:` (le titre).
- Fichiers ajoutés au lot par accord de l'orchestrateur : schéma `lnclass.course-tree.v3.json` (`hint`, `subjects`, `subject_exercise` avec
  la clé `notion` ; formes seulement, les bornes restent à l'adaptateur pour que l'erreur soit nommée ; pas de v4 nécessaire), motifs
  `subject_exercise_with_notion`, `too_many_subjects`, `too_many_subject_exercises` dans `ImportError::ELEMENT` (leurs phrases citent le
  sujet ou la leçon), libellés de l'aide, `subjects_created` au rapport (noté seulement quand la leçon porte des sujets), fabrique
  `revision_thales_document`. Un test par `RunImport` couvre l'import Thalès (indices, 3 sujets), CA-9, un type inattendu, un texte trop
  long et le volume.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
