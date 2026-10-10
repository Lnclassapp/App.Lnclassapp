# Journal — Des images dans les fiches de cours

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

- …

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

## 2026-10-10 — Lot 0

- **Clés étrangères en RESTRICT, pas CASCADE** : l'ADR proposait `on_delete: :cascade` ; `SchemaConstraintsTest` impose RESTRICT hors d'une liste fermée (ADR-0036). Corrigé dans la migration et l'ADR. Conséquence pour le Lot C : une question qui part doit d'abord perdre son image.
- **Adaptateurs et tâches de purge remontés au Lot 0** : `PortContractsTest` refuse un port sans adaptateur et `RecurringTasksTest` une tâche sans classe.
- **Une seule migration** au lieu de trois.
- **Environnement local** : 5 erreurs préexistantes, sans rapport avec le chantier (PostgreSQL 18 lève `RestrictViolation`, que Rails ne range pas en `InvalidForeignKey`). `npx` absent : `bin/rails test` sans chemin échoue au `css:build` ; les tests passent dossier par dossier.

## 2026-10-10 — Lot C

- **Suppression d'une question qui porte une image** (FK RESTRICT) : `ExerciseRepository#update(replace_questions: true)` détache d'abord les images des anciennes questions, réécrit les questions, rattache les images encore citées, puis supprime avec leur fichier celles qui ne le sont plus. C'est le seul chemin qui supprime des questions.
- **Rattachement prudent** : une image ne se rattache que si elle n'est à aucune question ; citer le `public_id` de l'image d'un autre exercice ne la déplace pas.
- **Exercice verrouillé** (déjà tenté) : les questions ne sont pas réécrites, donc l'image ne change plus. Le formulaire verrouillé ne l'affiche pas encore (clé `image_locked` posée au Lot 0, non utilisée).
- **Carte de question élève** : l'image est placée avant le `fieldset`, pas dedans, pour que la `legend` reste son premier enfant (UDR-0084 §3.4 dit « avant la legend »).
- **Refus numéroté** : `PublishExercise` rend `errors: { base: [code], number: [N] }` pour la première question en cause ; `image_alt_blank` est refusé de la même façon.

## 2026-10-10 — Lot A

- **Un emplacement enregistré par Trix est un `<div>`** : Trix réécrit les `<p>` de l'import en `<div>` (son bloc par défaut). `ImageSlot::PATTERN` lit désormais `<p>` et `<div>` ; sans cela, le compteur disparaissait après le premier enregistrement et le Lot B aurait laissé publier une fiche à emplacement restant.
- **Événement `rich-text-editor:inserting`** (détail `{ file }`), émis juste avant `insertFile` : c'est le seul instant où l'emplacement peut être sélectionné pour que l'image le remplace. `uploaded` porte aussi `file`, pour retrouver la description de l'emplacement réclamé. Le blog n'écoute pas cet événement : son comportement ne change pas.
- **Valeurs `uploadField` et `squeeze`** ajoutées à `rich-text-editor` ; absentes, le blog garde `article_image[file]` et une seule qualité.
- **Clés retirées** : `teams.essentials.form.content_hint` et l'erreur `content.attachment` (texte seul), remplacée par `content.invalid` (sgid illisible, refus du repository).
- **Suite système** : `test/system/catalog/essential_images_test.rb` enregistré à 4,6 s (à chaud). Reste ~10,4 s de budget pour les lots C et D.
- **Environnement local** : `test/system/teams/blog_management_test.rb` échoue aussi sur `HEAD` sans ce lot (ligne 71, ou délai de `drop_generated_image`) : pas causé par le lot, à revoir hors chantier.
