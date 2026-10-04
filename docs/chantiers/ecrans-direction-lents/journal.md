# Journal — Écrans de la direction dans leur budget

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Sur la copie de mesure, 303 élèves (7,2 %) quittent l'établissement mesuré, une heure après leur dernière session ; 152 rejoignent un autre établissement | Le jeu n'avait aucun ancien élève : la page ne mesurait que la recherche d'une liste vide | Non (protocole, [plan](plan.md#protocole)) |
| 2026-10-04 | Mesure « avant » à 10 mesures × 3 exécutions au lieu de 30 × 3 | 8 s par requête : 30 × 3 aurait pris 15 minutes pour un chiffre déjà stable (écart de 2 % entre exécutions) | Non |
| 2026-10-04 | L'index `classroom_students (student_id)` est joué en premier (ADR-0062 : index d'abord), mesuré, puis **annulé** | Il divise le temps par 12 (725 ms en p95), mais la réécriture qui suit ne l'utilise plus ; A/B : SQL p50 24,0 ms avec, 26,0 ms sans, dans le bruit | Non |
| 2026-10-04 | Réécriture de la liste : un pré-agrégat des adhésions de l'établissement (`array_agg … ORDER BY` + `HAVING NOT bool_or`) plutôt que `DISTINCT ON` | Mesurée la plus rapide des trois formes (9,8 ms contre 11,1 et 19,1 ms), et sans anti-jointure exposée à une erreur d'estimation | Non (réécriture locale) |
| 2026-10-04 | La requête des totaux n'est pas touchée | #169 (`fix/remediation-comptee-faite`) en modifie la ligne `kind` ; la réécrire ici créerait un conflit. Gain possible : quelques ms | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **La cible de 100 ms en p95 n'est pas atteinte au protocole (136 ms), alors que le SQL n'en coûte plus que 24.** Une fois la requête réécrite, j'ai d'abord pris le p95 pour du bruit de machine. La décomposition par mesure (temps CPU, GC, compilations YJIT de chaque requête) montre autre chose : les mesures lentes sont du CPU Ruby sans GC, qui coïncide avec la **compilation YJIT**. Elle se déclenche après 30 appels, donc entre la 4ᵉ et la 33ᵉ requête, précisément dans la fenêtre mesurée après 3 chauffes. Une fois la page chaude, après 60 requêtes, elle tient à 78 ms en p95. Toute page lourde en Ruby (200 lignes ici) paie ce coût dans le protocole actuel.
- **Le premier lancement du bench n'avait pas l'écran** : l'ajout au script avait échoué (fichier non relu avant l'édition), et `PERF_ONLY` filtrait alors tout, sans erreur. Le script ne signale pas un filtre qui ne correspond à aucun écran.
- **Une variante `DISTINCT ON` avec le `NOT EXISTS` d'origine** semblait la réécriture la plus naturelle : elle fait 19 ms, deux fois plus que le pré-agrégat. L'estimation de la jointure classes × adhésions (76 lignes estimées pour 4 235 réelles, car l'établissement mesuré a 55 élèves par classe contre 1,2 en moyenne) la pousse vers une anti-jointure coûteuse. C'est la même erreur d'estimation qui faisait, avant, les 148 millions de comparaisons.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **`classroom_students` n'a aucun index qui commence par `student_id`**, à part l'index unique partiel des adhésions principales actives (`WHERE primary AND left_at IS NULL`). Il ne sert ni aux adhésions quittées ni aux secondaires. Toute lecture « les classes d'un élève » qui inclut les départs parcourt donc la table. Ici, la réécriture a supprimé le besoin. Un futur écran par élève (historique de ses classes) devra mesurer avant de supposer l'index.
- **Un départ garde `primary = true`** : `MembershipRepository#leave_primary` ne pose que `left_at`. La présence se lit donc sur `left_at IS NULL`, jamais sur `primary`, et la définition de `DepartedStudentsQuery` compte aussi une adhésion secondaire non quittée comme présente (caractérisé par un test).
- **Le planificateur sous-estime la taille de l'établissement mesuré** (76 adhésions estimées contre 4 235 réelles) : le jeu concentre 55 élèves par classe dans cet établissement et 1,2 ailleurs. Il en résulte un `Seq Scan` + `Hash Join` (≈ 6 ms) là où une boucle imbriquée sur l'index `(classroom_id, student_id)` ferait ≈ 2 ms. On ne l'obtiendrait qu'en abaissant `random_page_cost` (réglage serveur), hors du périmètre.
- **La compilation JIT de PostgreSQL** coûtait à elle seule 360 à 410 ms par requête avant la réécriture (coût estimé de 0,7 à 24 millions, au-delà de `jit_above_cost`) ; après, le coût estimé (1 526) ne la déclenche plus.
- **YJIT est actif en mode production** et compile pendant les 30 premières requêtes d'un écran, puis par rafales (328 iseqs à la 116ᵉ requête de cet écran) : les 3 chauffes de l'ADR-0067 ne le sortent pas de la mesure.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `script/perf/dataset.rb` ne sème **aucun ancien élève** (ni aucune remédiation, déjà relevé par #169) : la copie a été transformée à la main | Consigne du lot : le jeu ne se répare pas ici. La requête de transformation est dans le [plan](plan.md#protocole), prête à y entrer | Lot D de ce plan |
| p95 de « Anciens élèves » à 136 ms au protocole (cible 100 ms) | Le SQL est réglé (24 ms). Le reste vient de la compilation YJIT et du GC (rendu de 200 lignes), pas d'un levier SQL. Pistes : les totaux par élève (7 ms, après la fusion de #169), le rendu des lignes, ou une chauffe du protocole plus longue que le seuil de YJIT | Décision du porteur : levier de rendu, ou amendement de l'ADR-0067 sur la chauffe |
| Les totaux (`#totals`) parcourent les 754 devoirs de l'établissement et filtrent les 200 élèves ensuite (7 ms) | Lignes modifiées par #169 ; un levier à la fois | Après la fusion de #169 |
| `measure_screens.rb` ne signale pas un `PERF_ONLY` qui ne correspond à aucun écran | Hors périmètre | Prochain chantier qui touche le script |
| Lots 2 (« Travail des élèves », 229 ms p95) et 3 (« Enseignants », 441 Ko) | Ce lot ne joue que le premier levier | Ce chantier |

## Recouvrements avec #169 (`fix/remediation-comptee-faite`)

- `app/infrastructure/queries/school/departed_students_query.rb` : ce chantier réécrit les lignes 14 à 27 (constantes de la liste) et 52 à 53 (`#departed`) ; #169 modifie la ligne 4 (en-tête) et les lignes 56 à 59 (`#totals`, `kind`). Aucune ligne commune ; la ligne 53 de ce chantier touche le contexte du bloc de #169 (`.where(NOT_PRESENT, …)`), séparé de ses lignes modifiées par `end` et une ligne vide. La fusion d'essai (`git merge-tree`) est **propre**, et les tests de la query, fusionnés, passent (11 runs, dont le cas de remédiation de #169).
- `test/infrastructure/queries/school/departed_students_query_test.rb` : #169 change le test « left for another school » et en insère un après ; ce chantier ajoute ses cas en fin de fichier. Fusion propre.
- `script/perf/measure_screens.rb` : la **même ligne**, au même endroit (`admin_departed_students`). Fusion propre.
- L'index `index_exercise_sessions_handed_in`, que #169 reconstruit sans la condition `kind`, sert les totaux de cette page ; ce chantier ne le touche pas.

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | aucun (réécriture locale d'une query, aucun index livré, aucun cache) |
| **UDR produits** | |
