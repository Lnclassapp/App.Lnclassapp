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
| 2026-10-04 | Lot 3, levier 3b : la confirmation « Retirer » d'« Enseignants » n'est plus copiée dans chaque ligne. Elle se charge à la demande dans le frame `modal` (`GET teachers/:public_id/removal`) et rend une page complète sans JavaScript. La policy du retrait passe avant toute lecture : 403, puis 404 comme le `DELETE`, y compris pour la direction d'un autre établissement. Les lignes et le menu perdent leur indentation | 60 modales faisaient 198 Ko et environ 72 ms de vue, pour une seule ouverte. Résultat : 368,5 → 152,5 Ko, vue 63,5 → 30,1 ms ; la confirmation pèse 3,6 Ko, avec un p95 de 30 ms. Le budget de 150 Ko n'est pas atteint (2,5 Ko de trop) : le levier 3c est proposé | Non : [UDR-0056](../../decisions/udr/0056-gestes-de-la-direction.md) et [UDR-0042](../../decisions/udr/0042-actions-de-ligne-dans-un-menu.md), amendements du 2026-10-04 |
| 2026-10-04 | Lot 3, levier 3c : dans `ui_icon_sprite`, les attributs racine des icônes (`viewBox`, `fill`, `stroke`, `stroke-width`) passent du `<svg><use>` au `<symbol>`, gardé | Les 2,5 Ko de trop après 3b : 152,5 → **141,7 Ko**, sous le budget de 150 Ko. Les captures sont identiques à l'octet, en clair et en sombre, survol compris (`currentColor` hérité par `<use>`). Le temps ne bouge pas (p50 59,5 → 58,8 ms) | Non |

## Clôture par l'orchestrateur (2026-10-04)

- **Le challenger a retrouvé les gains annoncés** (voir son rapport plus bas) : « Anciens élèves » de 8,7 s à environ 60 ms en p50, avec 172 comparaisons ancienne / nouvelle requête sans différence ; « Enseignants » de 441,1 à 141,7 Ko, à l'octet.
- **Budget de « Anciens élèves »** : au protocole de l'ADR-0067, le p95 reste à la limite (de 68 à 136 ms selon l'ordre des séries), à cause de la chauffe YJIT. Le protocole n'est pas modifié pour faire passer le chiffre ; la porte reste non cochée, et la question de la chauffe appartient au porteur (ADR-0067).
- **Lot 2 déplacé** vers `travail-eleves-budget` : il dépend de la fusion de #169.
- **Menu ⋮ masqué** : corrigé à part, par le chantier de correction `menu-enseignants-masque` (#171). À la fusion avec cette PR, garder `sticky-actions` (voir le journal de #171).

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
| Lot 2 (« Travail des élèves », 229 ms p95) | Lot 3 d'abord (141,7 Ko, fini) | Ce chantier |
| « Enseignants » : la colonne d'actions porte `sticky right-0 bg-white` au lieu de `sticky-actions` (UDR-0042, amendement du 2026-09-28). Un menu ⋮ ouvert passe sous la cellule de la ligne suivante, qui masque une partie de l'entrée et prend son clic. Défaut antérieur au chantier, invisible des tests système, qui ouvrent le menu de la dernière ligne | Hors du levier (un lot = un levier) ; vu sur les captures du levier 3c | À décider : correctif court (`sticky-actions` sur le `th` et les `td`, et un test qui ouvre le menu d'une ligne du milieu) |

## Recouvrements avec #169 (`fix/remediation-comptee-faite`)

- `app/infrastructure/queries/school/departed_students_query.rb` : ce chantier réécrit les lignes 14 à 27 (constantes de la liste) et 52 à 53 (`#departed`) ; #169 modifie la ligne 4 (en-tête) et les lignes 56 à 59 (`#totals`, `kind`). Aucune ligne commune ; la ligne 53 de ce chantier touche le contexte du bloc de #169 (`.where(NOT_PRESENT, …)`), séparé de ses lignes modifiées par `end` et une ligne vide. La fusion d'essai (`git merge-tree`) est **propre**, et les tests de la query, fusionnés, passent (11 runs, dont le cas de remédiation de #169).
- `test/infrastructure/queries/school/departed_students_query_test.rb` : #169 change le test « left for another school » et en insère un après ; ce chantier ajoute ses cas en fin de fichier. Fusion propre.
- `script/perf/measure_screens.rb` : la **même ligne**, au même endroit (`admin_departed_students`). Fusion propre.
- L'index `index_exercise_sessions_handed_in`, que #169 reconstruit sans la condition `kind`, sert les totaux de cette page ; ce chantier ne le touche pas.

## Rapport du challenger

*2026-10-04, phase 5, challenger empirique ([cycle optimisation](../../workflows/optimisation.md)). Je n'ai écrit aucun code de ce chantier ; j'ai rejoué la mesure sur ma propre copie et je n'ai corrigé aucun code.*

**Verdict : le gain annoncé est retrouvé sur les quatre écrans, et tous les Ko correspondent à l'octet près, sauf un (0,1 Ko, expliqué).** Les budgets HTML sont tenus. Le p95 de « Anciens élèves » est à la limite des 100 ms, et dépend de l'ordre de la série. Pour la direction, rien n'a changé, à une exception près, déjà documentée mais plus large qu'annoncé : l'alignement du titre de la confirmation.

### Protocole rejoué

- **Base** : `app_lnclassapp_perf_challenge`, une copie neuve de `app_lnclassapp_perf_rapports_lot_c`, transformée par la requête du [plan § Protocole](plan.md#protocole), qui rend `SELECT 303`, `UPDATE 303` et `INSERT 0 152`, comme annoncé. Elle compte 40 153 adhésions, dont 303 quittées, et 60 enseignants dans l'établissement mesuré. Les copies des auteurs n'ont pas servi.
- **Avant** : `faedcb85`, la base commune de la branche et de `Develop`. **Après** : `11a066d9`. Le script de mesure est celui de la branche dans les deux cas. `origin/Develop` (`57214adf`) a aussi été mesuré : il compte 47 commits de plus (annonces) et ajoute 2,2 Ko à chaque page de la direction (voir plus bas). Il n'est donc pas comparable au Ko près.
- **Commande** : celle de l'en-tête de `measure_screens.rb`, avec `PERF_ONLY=admin_departed_students,admin_teacher,admin_classroom`. Elle couvre les 4 écrans et 2 témoins non touchés : la page d'une classe (`admin_classroom`) et « Travail des élèves » (`admin_classrooms`). Protocole de l'ADR-0067 : 3 chauffes, 30 mesures, 3 exécutions, médiane des 3, en mode production. Pour « Anciens élèves » sur `Develop` : 10 × 3, à cause des 8 s par requête.
- **Charge** (`loadavg`, 1 min, sur 4 cœurs partagés) : 0,9 à 1,0 pendant la série Après 1, 1,0 à 4,1 pendant Avant, 3,4 à 4,8 pendant `Develop`, Après 2 et la série « seul », 0,4 à 1,0 pendant Après 3. D'autres sessions tournaient.

### Avant / après, par écran

p50 / p95 en ms, médiane des 3 exécutions ; HTML brut en Ko.

| Écran | Avant `faedcb85` | Après 1 | Après 2 | Après 3 | Annoncé (avant → après) | Ko : avant → après (annoncé) | Gain retrouvé | Budget |
|---|---|---|---|---|---|---|---|---|
| `admin_departed_students` | 8 111,9 / 8 665,9 (SQL 8 078,8) | 55,9 / 78,2 (SQL 24,5) | 44,0 / 68,3 (SQL 20,0) | 59,1 / 77,4 (SQL 24,5) | 8 276,1 / 8 821,2 → 57,7 / 136,1 (SQL 8 175,2 → 23,7) | 110,4 → **110,3** (110,4 → 110,4) · 8 requêtes | **oui** (p50 ÷ 140 à 185) | **à la limite** : 68 à 78 ms en série, **103,2 ms mesuré seul** |
| `admin_teachers` | 93,8 / 132,4 (vue 69,8 ; 72 737 alloc.) | 42,6 / 62,4 (vue 23,4) | 46,3 / 67,0 | 54,0 / 71,3 | 441,1 Ko → 141,7 Ko ; p50 91,7 → 58,8 | 441,1 → 141,7, gzip 17,3 → 9,9 : **exacts** | **oui** | **oui** (Ko et p95) |
| `admin_teacher_removal` (frame) | 404 : la confirmation était copiée dans chaque ligne | 10,7 / 39,2 | 9,3 / 35,3 | 13,6 / 44,5 | 18,4 / 30,3 | 3,6, gzip 1,4, 5 requêtes : **exacts** | sans objet | **oui** |
| `admin_teacher_removal_page` (sans JS) | 404 | 15,4 / 19,9 | 12,2 / 15,6 | 15,7 / 24,3 | 20,8 / 41,0 | 17,2, gzip 4,3, 7 requêtes : **exacts** | sans objet | **oui** |
| Témoin : page d'une classe | 34,3 / 54,1 | 29,9 / 58,5 | 30,4 / 52,6 | 37,2 / 63,6 | non touché | 41,2 → 41,1 | témoin | oui |
| Témoin : « Travail des élèves » | 137,2 / 180,2 | 139,7 / 203,8 | 130,2 / 200,7 | 151,7 / 218,3 | non touché (lot 2) | 71,4 → 71,3 | témoin | non (lot 2) |

- **Bruit** : sur du code non touché, les témoins varient de −13 % à +9 % en p50 et de −3 % à +21 % en p95, entre des séries de la même heure. Tout écart de p95 inférieur à ±20 % est donc dans le bruit de cette machine. Les gains sur « Anciens élèves » (÷ 100 et plus) et sur la vue d'« Enseignants » (÷ 2,6 à 3) en sont très loin.
- **L'écart de 0,1 Ko sur « Anciens élèves »** (114 652 → 114 588 octets) : j'ai comparé le HTML rendu sur `faedcb85` et sur la branche. Après normalisation du nonce CSP et de l'id aléatoire du toast, la seule différence est l'**indentation du menu « Mon compte »** (`components/_dropdown`, levier 3b) : 64 octets, sur toutes les pages du shell. Les témoins perdent les mêmes 64 octets (71,4 → 71,3 ; 41,2 → 41,1). Le tableau du memo (« 8 · 110,4 Ko ✅ inchangés ») date d'avant le levier 3b : après, c'est **110,3 Ko**. Ce n'est pas un défaut, mais un chiffre à corriger dans le memo.
- **Le p95 de « Anciens élèves » dépend de ce que le processus a déjà joué.** Dans mes séries, il est mesuré en dernier, après les témoins et « Enseignants » : 78,2, 68,3 et 77,4 ms, sous le budget. Mesuré seul (`PERF_ONLY=admin_departed_students`), il donne 91,4 / 107,6 / 103,2 ms, soit une médiane de **103,2 ms**, hors budget de 3 ms. Je ne retrouve pas les 136,1 ms des auteurs : mes chiffres sont meilleurs. Je retrouve en revanche l'effet qu'ils décrivent : quand le code partagé (shell, helpers) a déjà été compilé par YJIT pour d'autres écrans, la queue disparaît. Le p50 (44 à 64 ms) est nettement dans le budget dans toutes les séries. **Budget p95 : non établi au protocole.** Je confirme la porte « Cible p95 < 100 ms » non cochée, et la décision laissée au porteur (levier de rendu, ou chauffe de l'ADR-0067).

### Après fusion dans `Develop`

- `Develop` ajoute l'entrée « Annonces » à la navigation de la direction : **+2,2 Ko** sur chaque page, sans requête de plus. « Enseignants » pèse 443,3 Ko sur `Develop` (86,2 / 112,8 ms) ; « Anciens élèves » 112,6 Ko, 8 142,7 / 8 491,6 ms.
- La branche a reçu `Develop` pendant ma mesure (`73740ac8`, poussé après `11a066d9`). Hors en-tête, son code est celui de ma fusion d'essai `Develop` + `11a066d9`. Le seul conflit, signalé par `git merge-tree`, porte sur la ligne 3 de `app/helpers/components_helper.rb` (en-tête HITL) ; il est résolu en union (`… 0069, 0071 · ADR : 0009, 0049, 0067`).
- Mesure de `73740ac8` (30 × 3, charge 0,4 à 1,0) : « Enseignants » **143,9 Ko** (gzip 10,6), sous le budget avec 6,1 Ko de marge, p95 80,6 et 69,2 ms ; « Anciens élèves » 112,5 Ko, p95 80,7 et 86,5 ms ; confirmation 3,6 Ko dans le frame, 19,4 Ko en page complète.

### Rien n'a changé pour la direction

- **« Anciens élèves »**, ancienne requête (`faedcb85`) contre nouvelle, sur ma copie, comparées valeur par valeur et dans l'ordre (nom de l'établissement, `truncated`, chaque ligne : nom, classe, niveau, année, devoirs rendus, moyenne). **172 cas, 0 différence** :
  - établissement mesuré (303 anciens élèves) : 8 recherches (`""`, `kon`, `ko`, `a`, `koné`, `KONE`, `e`, `zzzz`) × 7 plafonds (1, 50, 200, 302, 303, 304, 10 000), donc au plafond, juste en dessous et juste au-dessus ;
  - 5 autres établissements, dont 4 qui ont reçu des élèves partis de l'établissement mesuré (8 recherches × 2 plafonds). Leurs listes sont vides, puisque le jeu n'a de départs que dans l'établissement mesuré ;
  - 3 autres établissements, rendus synthétiquement riches dans une transaction annulée : départs, adhésion secondaire présente ailleurs dans l'établissement, adhésion quittée au même `joined_at` (égalité départagée par l'id), classe archivée, classe d'une année passée, anciens élèves anonymisés. Avec 4 recherches × 3 plafonds, 36 cas, dont 27 non vides. La copie est revenue à son état : 303 départs et 40 153 adhésions.
  - Toutes les colonnes de la présence et de la dernière classe sont `NOT NULL` : `HAVING NOT bool_or(…)` ne peut pas diverger du `NOT EXISTS` d'origine par un `NULL`.
- **« Enseignants », dans Chrome 141 headless** (test jetable, hors dépôt) : 10 vérifications vertes sur la branche.
  - Menu ⋮, puis « Retirer » : le titre et le texte sont **exactement** les chaînes de `faedcb85` (`remove_title` et `remove_body`), avec le formulaire `DELETE` et le focus sur « Annuler ».
  - « Annuler » ferme la confirmation, vide le frame, ne retire rien et n'archive aucun devoir. Le focus revient au ⋮ de la ligne. Échap ferme aussi la confirmation, et l'entrée du menu la recharge.
  - « Retirer » retire la ligne sans recharger la page, et affiche le toast « … 2 devoirs archivés. ».
  - À 390 px et en mode sombre : la confirmation tient dans l'écran, il n'y a pas de défilement horizontal, et le retrait aboutit.
  - **Sans JavaScript** (Chrome, scripts désactivés, `typeof Turbo === "undefined"`) : l'adresse de la confirmation rend une page complète, avec le lien « ← Enseignants », la `<dialog open>` lisible et le titre d'onglet. « Retirer » envoie le `DELETE` et revient à la liste, qui affiche la notice. Le lien de retour revient à la liste sans rien retirer.
  - **Chemin d'erreur** : une direction d'un autre établissement qui force l'adresse reçoit **404**, dans le frame comme sans, et rien de l'enseignant n'apparaît. Un enseignant, même du même établissement, reçoit **403**.
- **Captures `faedcb85` contre branche**, au pixel (`compare -metric AE`), sur 24 captures : liste, menu ⋮ ouvert sur la dernière ligne et sur une ligne du milieu, entrée survolée, confirmation ouverte, en clair et en sombre, à 1 400 et à 390 px. **20 sont identiques à 0 pixel près.** Les 4 captures de la confirmation diffèrent d'environ 5 000 pixels, tous dans le titre : il était aligné à droite, hérité du `text-right` de la cellule ; il est maintenant aligné à gauche, comme toute modale. C'est la « seule différence visible » de l'[UDR-0056, amendement du 2026-10-04](../../decisions/udr/0056-gestes-de-la-direction.md#amendement-du-2026-10-04--confirmation-du-retrait-chargée-à-la-demande). Mais l'amendement la situe « au téléphone » : elle se voit **aussi au bureau**, car la modale `sm` fait passer le titre sur deux lignes dès un nom court (« Retirer Ama Zran de l'établissement ? »).

### Défauts trouvés

1. **Le menu ⋮ d'une ligne qui n'est pas la dernière ne se clique pas au bureau** : `ElementClickInterceptedError`, le clic est pris par le `div.flex.justify-end` de la ligne suivante. Le défaut est **identique sur `faedcb85`** (le `button` de la `<dialog>` de ligne) et sur la branche (le lien), à 1 400 px ; il ne se produit pas à 390 px. Ce n'est donc **pas une régression** : c'est la dette `sticky-actions` déjà consignée plus haut, que je confirme par un test qui échoue au clic d'un utilisateur, sur les deux versions.
2. **Écart de documentation** : l'amendement de l'UDR-0056 limite le changement d'alignement du titre « au téléphone », alors qu'il se voit aussi au bureau.
3. **Écart de chiffre** : le memo donne 110,4 Ko pour « Anciens élèves » après le chantier ; c'est 110,3 Ko depuis le levier 3b (64 octets du menu « Mon compte »).
4. **p95 de « Anciens élèves »** : 103,2 ms mesuré seul, 68 à 87 ms dans une série. Le budget n'est pas établi au protocole (décision du porteur, déjà ouverte).

Aucun défaut fonctionnel.

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | aucun (réécriture locale d'une query, aucun index livré, aucun cache) |
| **UDR produits** | |
