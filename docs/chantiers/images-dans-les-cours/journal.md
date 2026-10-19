# Journal — Des images dans les fiches de cours

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-19 | Avant la fusion de `Develop` : décisions renumérotées ADR-0104 et UDR-0129 | `Develop` avait donné 0089 (exercice du jour) et 0084 (accueil élève) à d'autres chantiers. Seules les lignes écrites par cette branche ont changé | Non |

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
| **Livré le** | 2026-10-14 |
| **PR** | |
| **ADR produits** | ADR-0104 |
| **UDR produits** | UDR-0129 |

## 2026-10-10 — Lot 0

- **Clés étrangères en RESTRICT, pas CASCADE** : l'ADR proposait `on_delete: :cascade` ; `SchemaConstraintsTest` impose RESTRICT hors d'une liste fermée (ADR-0036). Corrigé dans la migration et l'ADR. Conséquence pour le Lot C : une question qui part doit d'abord perdre son image.
- **Adaptateurs et tâches de purge remontés au Lot 0** : `PortContractsTest` refuse un port sans adaptateur et `RecurringTasksTest` une tâche sans classe.
- **Une seule migration** au lieu de trois.
- **Environnement local** : 5 erreurs préexistantes, sans rapport avec le chantier (PostgreSQL 18 lève `RestrictViolation`, que Rails ne range pas en `InvalidForeignKey`). `npx` absent : `bin/rails test` sans chemin échoue au `css:build` ; les tests passent dossier par dossier.

## 2026-10-10 — Lot C

- **Suppression d'une question qui porte une image** (FK RESTRICT) : `ExerciseRepository#update(replace_questions: true)` détache d'abord les images des anciennes questions, réécrit les questions, rattache les images encore citées, puis supprime avec leur fichier celles qui ne le sont plus. C'est le seul chemin qui supprime des questions.
- **Rattachement prudent** : une image ne se rattache que si elle n'est à aucune question ; citer le `public_id` de l'image d'un autre exercice ne la déplace pas.
- **Exercice verrouillé** (déjà tenté) : les questions ne sont pas réécrites, donc l'image ne change plus. Le formulaire verrouillé ne l'affiche pas encore (clé `image_locked` posée au Lot 0, non utilisée).
- **Carte de question élève** : l'image est placée avant le `fieldset`, pas dedans, pour que la `legend` reste son premier enfant (UDR-0129 §3.4 dit « avant la legend »).
- **Refus numéroté** : `PublishExercise` rend `errors: { base: [code], number: [N] }` pour la première question en cause ; `image_alt_blank` est refusé de la même façon.

## 2026-10-10 — Lot A

- **Un emplacement enregistré par Trix est un `<div>`** : Trix réécrit les `<p>` de l'import en `<div>` (son bloc par défaut). `ImageSlot::PATTERN` lit désormais `<p>` et `<div>` ; sans cela, le compteur disparaissait après le premier enregistrement et le Lot B aurait laissé publier une fiche à emplacement restant.
- **Événement `rich-text-editor:inserting`** (détail `{ file }`), émis juste avant `insertFile` : c'est le seul instant où l'emplacement peut être sélectionné pour que l'image le remplace. `uploaded` porte aussi `file`, pour retrouver la description de l'emplacement réclamé. Le blog n'écoute pas cet événement : son comportement ne change pas.
- **Valeurs `uploadField` et `squeeze`** ajoutées à `rich-text-editor` ; absentes, le blog garde `article_image[file]` et une seule qualité.
- **Clés retirées** : `teams.essentials.form.content_hint` et l'erreur `content.attachment` (texte seul), remplacée par `content.invalid` (sgid illisible, refus du repository).
- **Suite système** : `test/system/catalog/essential_images_test.rb` enregistré à 4,6 s (à chaud). Reste ~10,4 s de budget pour les lots C et D.
- **Environnement local** : `test/system/teams/blog_management_test.rb` échoue aussi sur `HEAD` sans ce lot (ligne 71, ou délai de `drop_generated_image`) : pas causé par le lot, à revoir hors chantier.

## 2026-10-10 — Corrections de revue

Revue du diff réuni (security-reviewer, silent-failure-hunter, pr-test-analyzer).

- **Plus de perte d'image sans message.** Question : une image citée qu'elle ne peut pas prendre (autre exercice, citée deux fois, inconnue, purgée) lève `ExerciseRepositoryPort::ImageUnavailable`. La transaction s'annule et le use case rend `:invalid`, `questions: [:image_unavailable]`. Fiche : un sgid valide hors des images admises rend `content: [:image_unavailable]` au lieu d'être retiré par l'assainisseur.
- **Suppressions journalisées** : `[EssentialRepository]` et `[ExerciseRepository] images supprimées ids=… public_ids=…`.
- **Emplacement mal écrit** : un bloc entier `[[image: …]]` que le motif ne lit pas (liste, titre, gras, vide, plus de 150 caractères) est refusé. À l'import, c'est `image_slot_malformed` sur `….content` ; à la publication, `image_slots_malformed` passe avant `image_slots_left`. Au milieu d'une phrase, l'emplacement reste du texte (ADR-0104 §4.3 inchangé).
- **Cache** : `max-age=3600, private` au lieu de `max-age=31536000, private, immutable`. Après une heure, la revalidation par ETag rejoue la règle de lecture. Une ligne sans son fichier répond 404 et le journal le dit. ADR-0104 §4.5 révisé.
- **Envois** : `rate_limit` de 60 par minute et par compte sur les deux `create`. Le 429 porte son texte, que `image_upload.js` affiche comme un 422.
- **Formulaire verrouillé** : l'image d'une question déjà tentée s'affiche en lecture seule avec `image_locked` (UDR-0129 §3.2). La dette du Lot C est soldée.
- **Clés retirées** : `teams.essentials.form.image_alt_label`, `image_alt_hint` et `image_alt_missing`, que rien ne lisait. La ligne de texte de remplacement de la fiche reprend celle de l'article.
- **Enseignant** : `ReadsOwnLevel` ne borne que l'élève. Un enseignant reçoit donc pour l'image la même réponse que pour la fiche ou l'exercice qui la porte. Les tests le figent : 200 publié, 404 archivé.
- **Durées système** : `question_image_test` 5,2 s et `publish_essential_with_images_test` 2,3 s. Le chantier en est à 12,1 s sur 15.

## 2026-10-14 — Clôture (session fiches-interactives)

- **Pourquoi maintenant** : le chantier `fiches-interactives` réutilise ces images ; le porteur décide de fusionner celui-ci d'abord et de garder 300 Ko et 1200 px.
- **`Develop` fusionné** (un commit de documentation) avant la preuve.
- **Couverture** : une branche manquait (`ReadQuestionImage`, image non rattachée lue sans compte) ; test ajouté.
- **`bin/ci` local** : vert hors échecs connus de la machine (5 erreurs PostgreSQL 18 `RestrictViolation`, inscription sans JavaScript, blog `drop_generated_image`). Quatre tests système (archivage ×2, AN-22, IL-08) ont dépassé leur délai sous la charge de la suite et passent seuls ; aucun ne touche aux images.
- **Machine** : `npx` absent, contourné pour la session par un `npx` local qui lance `node_modules/.bin`.
