# Journal — Historique de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | Un compte ajouté à `StudentArchiveQuery` | Non |
| 2026-10-15 | La carte bleue donne le vrai total, la liste reste limitée à 200 | La liste est bornée (`RESULTS_LIMIT`), le total ne doit pas mentir | Non |
| 2026-10-15 | Titre de mois masqué en CSS (utilitaire `ui-reveal-group`, `:has` ; les variantes arbitraires sont refusées par `design_tokens_test`) tant qu'aucune de ses lignes n'est révélée (Lot A) | « Voir plus » reste le contrôleur `reveal` partagé, inchangé ; aucun JavaScript propre à la page | Non |
| 2026-10-15 | Pastille de la matière rendue en `span` (Lot A), pas par `ui_subject_bubble` | `ui_subject_bubble` est un lien, et aucune ligne de l'historique n'en est un (UDR-0013) ; UDR-0090 §3.2 corrigée | Non |
| 2026-10-15 | `ResultRow` gagne `material_slug` (Lot 0) | Les illustrations des matières sont choisies par slug (`subject_illustration`, UDR-0069 §3.3), pas par catégorie : la catégorie ne donnerait que trois icônes | Non |
| 2026-10-15 | La couleur de la note suit la note lue (`grade_on_20 >= 14`), pas le pourcentage brut | 68 et 69 % s'affichent « 14/20 » par arrondi et restaient à l'encre, contre CA-4 (revue `pr-test-analyzer`). L'accueil (`_recent_activity`) garde la règle sur 70 % : à aligner | Non |

## Ce qui a dérapé

- Lot A : la variante arbitraire `not-has-[li:not([hidden])]:hidden` est refusée par `test/design/design_tokens_test.rb` ; remplacée par l'utilitaire nommé `ui-reveal-group`.
- Lot A : `record_timings` ne lit pas la ligne du premier test d'un fichier quand Puma démarre au milieu ; durée du fichier système posée à la main (4,6 s + 2,2 s du test à 1 280 px).
- Écart aux maquettes, gardé selon UDR-0090 §3.4 : sur téléphone et tablette verticale, les exercices passent avant les classes (les maquettes montrent les classes d'abord).
- Écart aux maquettes, gardé par cohérence : sous 640 px, les cartes « Mes exercices terminés » et « Mes classes » touchent les bords (règle `data-bleed` de l'application) ; en sombre, la carte bleue suit les jetons de la carte « Ma classe » de l'accueil (bleu clair, texte foncé), pas le bleu profond des maquettes.
- `bin/ci-quiet` (2026-10-15) : ROUGE, hors chantier. Unitaires : couverture 99,99 % par `Queries::Assessment::DailyExerciseQuery`, bouchon du Lot C d'`accueil-eleve` sur la base 587e914e ; `image_header_test.rb:516` (chrono à 0,52 s pour 0,5, machine chargée). Système : `sign_in_test.rb:114`, `public_pages_test.rb:89/:100`, `team_invitation_test.rb:62`, `staff_invitation_test.rb:50` (même cause : numéro formaté) rouges aussi sur la base 587e914e ; `classroom_test.rb:76`, `teacher_signup_test.rb:80`, `cold_start_test.rb:31`, `blog_management_test.rb:71` instables (verts au second passage). Performance : `import_exercises_performance_test.rb:38` (machine chargée). Aucun test de l'historique en échec.

## Ce qu'on a appris sur la codebase

- La couleur de la note suivait `Grading::PASS_THRESHOLD` (50 %) ; les écrans élève redessinés passent tous à 70 % (14/20).
- `StudentArchiveQuery` n'exposait aucun total : seulement les 200 derniers résultats.
- `ui_subject_bubble` est toujours un lien : pour une ligne non cliquable, la pastille se rend à la main avec `subject_illustration`.
- Les variantes Tailwind arbitraires (`[…]`) sont interdites dans les vues : un sélecteur particulier devient un `@utility` nommé dans `application.tailwind.css`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| « Ma classe » colore encore la note dès 10/20 (`PASS_THRESHOLD`) | Hors périmètre ; UDR-0090 §4 vise 14/20 partout | `ma-classe-eleve` |
| Index UDR (`script/docs/build_index`) et `docs/chantiers/README.md` | Faits à la fusion, pas sur la branche | clôture de la PR |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 (branche `feature/historique-eleve`) |
| **PR** | à ouvrir après la PR `accueil-eleve` |
| **ADR produits** | — |
| **UDR produits** | UDR-0090 |
