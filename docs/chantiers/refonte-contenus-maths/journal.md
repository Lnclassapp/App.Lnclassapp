# Journal — Refonte des contenus de mathématiques

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-29 | Lot A : le schéma v3 refuse d'abord (5 questions, explanation 20-2000, 4 problèmes, 1 exercice par notion) ; le rapport donne alors le code `schema` au chemin de l'élément. Les raisons propres (`too_few_questions`, `lesson_exercise_count`…) restent dans l'adaptateur, pour un appel sans schéma. | Le moteur valide le schéma avant l'adaptateur ; les deux disent le même chemin. | Non |
| 2026-10-29 | Lot R : `essentials.sheet` devient `NOT NULL default {}` (l'ADR dit « non nul ») ; `{}` = notion sans fiche, exclue par `RevisionSheetQuery`. `SheetDocument` est remplacé par `StatementBlocks` (sujet en blocs, ADR-0115) et `CourseSheetTextHelper` par `Catalog::SheetTextHelper`, car encore utilisés. `/courses/:slug/fiche` répond 301 vers `#fiche-de-revision`. | Garder la validation des sujets en blocs et les vues cahier sans l'ancien code. | Non |
| 2026-10-29 | Alignement des raisons (CA-18) : l'import fait foi. Le schéma v3 ne compte plus les questions, les problèmes, l'exercice d'une notion ni la correction, et ne juge plus le fond des figures : l'adaptateur rend `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`/`invalid_count`, `blank`/`too_short`(nouveau)/`too_long`, `figure_invalid`. Le script rend le code de l'import pour tout le reste (`schema` quand le schéma refuse, qui masque alors l'adaptateur), et n'avertit que de ce que l'import ignore. Remplace la décision du Lot A ci-dessous. | Un fichier refusé par le script doit l'être par l'import pour la même raison ; test de parité. | Non (ADR §4.1 mis à jour) |
| 2026-10-29 | Lot A : `replace_draft` garde l'auteur de la leçon (le port n'a pas d'`author_id`) ; les séances de remédiation hors leçon dont la lacune disparaît deviennent ordinaires. | Pas de port à changer ; la base impose `remediation ⇔ lacune`. | Non |
| 2026-10-29 | Lot F2 : le point dérivé (Thalès) est une contrainte `{"point","on","parallel_to","through"}` recalculée à chaque tracé ; le volume du solide est affiché en `V ≈` sans unité ; le solide se recadre à chaque curseur (pas d'échelle fixe). | Aucun curseur sur geometry (Lot 0 bis) : le point déplaçable D commande E ; la sortie de `solid` reste lisible sans connaître le maximum du curseur. | Non (forme ajoutée à l'ADR §4.2) |
| 2026-10-29 | Correction solide : l'échelle est calculée une seule fois, sur le solide dont chaque dimension réglée par un curseur vaut son `max` (le contrôleur passe `controls` au module, dans l'objet de rappels) ; elle remplace « se recadre à chaque curseur » du Lot F2. | Le recadrage à chaque mouvement masquait l'effet du curseur de hauteur. | Non |
| 2026-10-29 | Lots P1+P2 : la bande des mesures de `geometry` passe sur deux colonnes et s'ajoute à la hauteur de la figure (le `viewBox` grandit) au lieu de prendre sur elle ; les curseurs de la pyramide et du cône de la leçon 9 ont des `max` resserrés (9/8 et 6/8). | Avec 6 longueurs, la bande prenait 188 px sur 320 : le triangle de Thalès sortait écrasé (vu sur la capture) ; l'échelle fixée sur le `max` rendait les solides trop petits. | Non |
| 2026-10-29 | Figures responsives (mesuré sur les 10 leçons, de 320 à 1 280 px) : rien ne débordait, mais le texte tombait à 8 px sur téléphone et montait à 26 px sur ordinateur. Le contrôleur agrandit le texte (`--figure-text`, de 1 à 1,4 selon la largeur affichée) ; la figure est limitée à 520 px ; sous 1 000 px son cadre s'amincit ; le canvas prend la hauteur de son dessin ; sur la droite graduée, des étiquettes trop proches se répartissent sur 2 rangs. | Une figure illisible sur téléphone ne sert à rien ; le format 4/3 laissait un grand vide sous les droites graduées. | Non |
| 2026-10-29 | Lot revues (6 revues + challenger) : `Figure` exige les paramètres de chaque sorte, min < max et des curseurs dans les bornes de la sorte (le navigateur ne reçoit plus une figure qu'il refuse) ; `NotDraft` à l'écriture devient `lesson_already_published` ; `stat_chart.js` borne ses valeurs ; jeton de génération dans `figure_controller` ; le script ne plante plus sur une méthode ou des figures mal formées ; la migration R compte ce qu'elle supprime et retire les variantes. | Constats vérifiés des revues ; aucun n'était une faille exploitable. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : le plan ne listait pas `import_error.rb` ni `run_import.rb` ; sans eux, aucun nouveau motif d'import (`format_retired`…) n'existe. Le champ du lot a été élargi en cours de route.
- Lot A : `saint_michel.rb` importe des leçons de Tle D au format 1, désormais retiré ; la démo `--activite` s'arrête avec un message clair. Le Lot P2 ne couvre que `lecons_completes.rb` (3e) : voir la dette.
- Lot R : retirés en plus du plan, car morts sans la fiche cahier : create/update_essential, essential_input, image_slot, helpers course_sheet_*, schéma `lnclass.essentials.v1`. Anciens tests système de la page v2 supprimés ; `course_catalog`, `boucle_pedagogique`, `import_flow`, `imports_end_to_end` migrés vers la fiche v3. Échecs préexistants : QuestionFillBlank/Numeric/Ordering/Matching (balisage du résultat), `figure_test` sans durée enregistrée, garde de migrations sans `origin/main` dans le worktree.

- Alignement des raisons (CA-18) : le test système CA-3 de `import_course_tree_test` attendait encore le message du schéma ; vu seulement en phase 5, car les tests système ne tournent pas à chaque lot. `teams/import_flow_test` (fichier de 20 Mo) a échoué une fois en suite chargée, vert seul deux fois : course au rendu de la modale.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rapport d'import : une leçon brouillon remplacée est comptée comme créée (pas de `courses_replaced`). | Le PRD ne le demande pas ; le journal applicatif trace désormais le remplacement. | — |
| CA-10 : aucun test ne crée de copie avant le réimport refusé pour prouver qu'elle reste intacte. | Le refus a lieu avant toute écriture (testé) ; le cas copie est indirect. | — |
| La migration R retire les lignes des images sans purger les octets du service de stockage. | Base remise à zéro par le porteur ; aucun fichier en production. | — |
| Rejet en bloc (format retiré) : le message n'apparaît pas dans la modale d'import, seulement dans la liste et le rapport (vu par le challenger). | Comportement antérieur du rejet en bloc, hors périmètre. | À ouvrir si gênant |
| `bin/tester-pr --activite` (`saint_michel.rb`) s'arrête : ses 18 leçons de Tle D, toutes matières, sont au format 1 retiré. | Le pilote ne réécrit que les mathématiques de 3e. Les autres matières attendent leur propre gabarit. | Réécriture v3 des leçons de Tle D, à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
