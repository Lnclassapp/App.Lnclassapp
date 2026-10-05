# Journal — Comprendre où en est la classe sur un exercice

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Le porteur délègue la suite du cadrage (« prends des décisions alignées ») après avoir validé couleurs, meilleur score, signe et seuil de 5 | Avancer jusqu'au plan sans lui poser chaque question | — |
| 2026-10-04 | La statistique est celle d'un **exercice assigné**, sur les sessions de l'assignation, et non celle d'un exercice sur toutes les sessions | Le « 18/25 » doit être le « 18 faits » de la même page (ADR-0048, ADR-0072) | ADR-0079 §4.1 |
| 2026-10-04 | Le détail va dans la **page de suivi** existante, sous `FollowAssignmentPolicy` : ni écran, ni route, ni policy nouveaux | La page nomme déjà des élèves sous la bonne policy | UDR-0072 §2 |
| 2026-10-04 | Badges déduits du meilleur score de l'assignation, pas de la table des badges | Couleur et badge ne se contredisent jamais | ADR-0079 §4.2 |
| 2026-10-04 | **Une session de remédiation, c'est faire l'exercice** : « fait », scores et taux l'incluent | Le challenger de `progres-eleve` l'a trouvé en navigateur réel : après un échec, `StartExerciseSession` ouvre des remédiations ; l'enseignant ne voyait pas ces progrès, et « Pas encore faits » nommait à tort des élèves qui avaient fait l'exercice | ADR-0079 §4.1, ADR-0072 (complément bis) ; pages de la direction : chantier `remediation-comptee-faite` (#169) |
| 2026-10-04 | **Autonomie totale** accordée par le porteur : décisions prises sans question, au service du progrès des utilisateurs | Consigne du porteur | — |
| 2026-10-04 | « Essai » remplacé par « session » dans les libellés (Lot 0) | L'UDR-0007, acceptée, interdit « Essai » pour une session, et `locale_files_test` le vérifie : une règle de vocabulaire unique sert l'utilisateur, une exception non | UDR-0072 §3.7 corrigée |
| 2026-10-04 | Relecture par la mission (« aider chaque acteur à progresser ») : taux au premier essai par question, « À reprendre en classe » sous 50 %, élèves en baisse ou qui stagnent en tête | Chaque lecture doit appeler un geste de l'enseignant | ADR-0079 §2, §4.5, §4.7 |
| 2026-10-04 | Rouge et jaune deviennent des tokens propres à la compréhension (`struggling`, `fragile`), distincts de l'ambre d'urgence | La charte (§5) réserve l'ambre à l'urgence, et la même ligne affiche une échéance en retard en ambre | UDR-0072 §3.1 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche ouverte sur un `Develop` local périmé de 394 commits** (clone du conteneur figé au 2026-10-01). Le premier cadrage s'appuyait sur un code disparu : page classe sans « Exercices assignés », pas d'échéance, pas de page de suivi. Découvert au moment de numéroter l'ADR. Rebasé sur `origin/Develop`, puis memo corrigé. **À refaire autrement : `git fetch origin Develop` avant `git switch -c`, toujours.**
- Les captures envoyées comme « états » étaient celles de la jauge de contexte de Claude Code, pas des maquettes : l'UDR propose une mise en page sans maquette du porteur.
- **Les tests de requête fabriquaient une deuxième session `standard` après un échec, ce que l'application ne fait jamais** (elle ouvre une remédiation). Seul le parcours rejoué dans l'interface l'a révélé. À retenir : une fabrique doit reproduire les transitions réelles du domaine, sinon les tests prouvent un monde qui n'existe pas.
- La CI ne tourne pas sur une PR en brouillon (ADR-0069) : les « verts » de la PR n'ont rien prouvé tant qu'elle était en brouillon. Preuve locale (`COVERAGE=0 bin/rails test`, suite complète) à chaque lot, puis PR passée en « prête » une fois les lots mergés pour obtenir le verdict de la CI.
- L'exploration déléguée à un agent a été perdue lors d'un redémarrage du conteneur ; refaite à la main.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Grading.mastery_for` donne déjà les trois catégories (« Acquis », « Fragile », « En difficulté ») ; aucun seuil n'est à créer.
- Deux définitions de « réussite » coexistent : la fiche essentielle dans la classe (UDR-0029) lit toutes les sessions des élèves présents ; le suivi d'un exercice assigné (ADR-0072) ne lit que les sessions de l'assignation. Elles ne sont jamais sur la même page.
- `AssignmentFollowUpQuery.present_students` est la définition partagée de l'élève « présent » (adhésion non quittée, compte non anonymisé).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| **Page classe hors budget** (ADR-0067) : déjà 143,7 ms et 197,5 Ko avant ce chantier ; 211,7 Ko après lui (D3 corrigé : trophée en `<symbol>`). La liste des élèves pèse 147,7 Ko à elle seule | Le dépassement précède ce chantier ; le réduire touche la liste des élèves (UDR-0027, UDR-0054), hors périmètre. L'ADR-0067 impose un chantier `optimize` | `optimize page-classe-legere` (à ouvrir) |
| **`script/perf/dataset.rb` incomplet** (D4) : il assignait des `Essential` et des `Course`, refusés depuis l'ADR-0072 (**réparé dans `Develop` par 3a893a86**, chantier `dettes-reorganisation`, intégré ici) ; il ne sème toujours **aucune `question_attempts`**, donc les taux par question de la page de suivi ne se mesurent pas au volume réel | Hors périmètre ; mesure faite ici avec une enveloppe jetable qui sème 1 453 574 tentatives (rapport du challenger) | `optimize page-classe-legere` : semer les tentatives avant de mesurer |
| À 320 px, la page classe défile en largeur à cause des boutons de la liste des élèves | Préexistant, hors du pied ajouté ici | `optimize page-classe-legere` ou `finitions-ux` |

## Rapport du challenger

> Lot C, 2026-10-04. Rôle distinct des auteurs des lots 0, A et B : il n'a pas relu le code, il l'a exécuté.

### Navigateur

Chromium 141 (`/opt/pw-browsers/chromium-1194`). Le chromedriver du `PATH` (`/opt/node22/bin/chromedriver`) est en version 147. Avec `CHROME_BIN` seul, selenium-manager le prend quand même, et la session échoue : `SessionNotCreatedError: session not created: This version of ChromeDriver only supports Chrome version 147`. Un chromedriver 141.0.7390.37, téléchargé depuis chrome-for-testing et passé par `CHROMEDRIVER_PATH`, lance le navigateur. Tous les tests ci-dessous tournent dans ce **navigateur réel**.

### Test système

`test/system/classroom/comprehension_test.rb` contient 3 tests : le parcours nominal, le 403 d'un élève et le téléphone.

- **Rouge d'abord** : avec une valeur attendue faussée (« Pas encore faits · 4 »), le test échoue sur cette ligne. Tout ce qui la précède passe : badges, cercle, catégorie, rechargement.
- **Vert** sur 3 exécutions de suite : 3 tests et 56 assertions à chaque fois, aucun échec.
- La classe est préparée avec les séries du PRD (30-60-90, 100-100, 80-90-81, 50-60, 60-60-60) et une égalité de meilleur score. Elle compte 10 faits, 3 pas encore faits, dont un élève qui n'a qu'une session commencée.

### Vérifications

Elles sont faites dans le navigateur réel, sur des données préparées, avec des captures. Le statut HTTP est lu par un `fetch` de même origine, avec le cookie de l'acteur connecté.

| Vérification | Résultat | Preuve |
|---|---|---|
| Seuil de 5 | OK | 4 faits : `bg-line`, `rgb(230, 225, 216)`, « Pas encore lisible · 4/6 ». Le suivi affiche l'avertissement, et le détail reste visible. 5 faits : `bg-success`, `rgb(24, 114, 63)`, « Acquis · 5/6 » |
| Taux plafonné | OK | 5 élèves, 2 ou 3 sessions chacun, Q1 juste à chaque session : Q1 « 100 % ». Le plus grand pourcentage du HTML vaut 100 |
| Sessions de l'assignation seulement | OK | Ne comptent pas : une remédiation à 100, une session hors assignation, une session d'une autre classe, une session commencée, un élève parti, un élève anonymisé. Résultat : « 5 faits · 1 pas encore fait », « 5/6 ». Les noms des élèves partis ou anonymisés sont absents du HTML |
| Meilleur essai à égalité | OK | 60-60-60 avec Q3 juste aux deux premières sessions et fausse à la dernière : Q3 « 0 % » chez les Fragile. C'est la session la plus récente qui compte |
| Refus | OK | 403 pour l'élève de la classe, pour un enseignant d'une autre classe et pour la direction : page « accès refusé », aucun nom. 200 pour l'enseignant et pour l'équipe (TOTP compris) |
| Catégorie inconnue | OK | `bogus`, `FRAGILE`, `Fragile`, `fragile%20`, `%20fragile`, `__send__`, `struggling%00`, une valeur vide et `category[]=fragile` donnent tous 200, avec la dominante choisie (Acquis) |
| Catégorie dans l'adresse | OK | Le clic sur « Fragile » ne recharge pas la page (le marqueur `window` est gardé). L'adresse prend `?category=fragile`, la catégorie reste choisie au rechargement, et le retour arrière revient à la dominante |
| Mode sombre | OK | Avec `data-theme="dark"`, puis avec l'émulation `prefers-color-scheme: dark`, les couleurs sont les mêmes dans les deux cas. Cercle « Acquis » : `rgb(24,114,63)` devient `rgb(111,214,154)`. Pastilles : `#c8322b` devient `#ff7b72`, `#e0a800` devient `#facc15`. Barres : fond `rgb(242,238,231)` devenu `rgb(34,42,53)`, remplissage devenu `rgb(111,214,154)`. Contraste du texte en sombre : libellé de la catégorie choisie 11,3:1, autres libellés et taux 15,1:1, titre 16,6:1 |
| Lecteur d'écran | OK | Aucun « essai » dans le HTML brut, ni de la page classe, ni du suivi. Les `sr-only` sont « 1 Bronze », « 0 Argent », « 0 Or », « 4 Diamant » : le Bronze et les zéros sont présents. Un seul `aria-current="true"`, sur la catégorie choisie. Les barres sont `aria-hidden`. Les `aria-label` des questions sont complets. Aucun `public_id` d'élève dans le HTML du suivi |
| États vides | OK | 0 fait : « Personne n'a encore fait cet exercice. », badges en `text-line`, « Pas encore lisible · 0/0 ». Catégorie vide : « Aucun élève dans cette catégorie. ». Tous faits : pas de section « Pas encore faits » |
| Téléphone 390 px, sans défilement horizontal | OK | Ni la page classe ni le suivi ne défilent en largeur (test système). Même chose à 360 et 375 px |
| Pied « sur une ligne » au téléphone (UDR-0072 §3.4) | **KO** | Voir le défaut D2 |
| 320 px, page classe | KO, hors chantier | `scrollWidth` 316 pour 305. Ce sont les boutons du registre des élèves (`form.shrink-0`, 276 px) qui débordent, pas le pied |
| Budget de la page classe | **KO** | Voir ci-dessous |
| Budget de la page de suivi | OK | Voir ci-dessous |

### Budget (ADR-0067)

Mesure faite avec `script/perf/measure_screens.rb`, en mode production, avec la méthode de l'ADR : 3 requêtes de chauffe, 30 mesurées, 3 exécutions, médiane des 3. La classe mesurée est celle de l'enseignant `0520000001` : 55 élèves présents et 7 exercices assignés actifs. Le suivi mesuré est celui de l'assignation active la plus faite.

**Le jeu de référence ne se sème plus.** `bin/rails runner script/perf/seed_dataset.rb` échoue sur une base neuve :

```
PG::CheckViolation: new row for relation "classroom_assignments" violates check constraint "classroom_assignments_type_values"
```

`dataset.rb` assigne encore des fiches et des cours, alors que seul `Exercise` est admis (ADR-0072). La mesure a donc été faite avec une enveloppe hors dépôt, qui charge `dataset.rb` tel quel avec deux écarts :

- 10 exercices assignés par classe au lieu de 7 exercices, 2 fiches et 1 cours ;
- une tentative par question répondue, cohérente avec `correct_count`, soit 1 453 574 tentatives. Le jeu n'en sème aucune, alors que le suivi les lit.

Les volumes restent ceux de l'ADR : 34 531 classes, 40 000 élèves, 54 316 devoirs, 312 283 sessions. Le semis a pris 4 min 25.

Les mêmes mesures ont été prises sur le même jeu, avec le commit d'avant le Lot A (`39322d56`, ni pied ni section), dans un worktree temporaire. Les deux versions ont été mesurées en alternance.

| Écran | Avant A et B : p95 / p50 / Ko / requêtes | Après : p95 / p50 / Ko / requêtes | Budget |
|---|---|---|---|
| Page classe | 143,7 / 91,9 / 197,5 / 19 | **153,4** / 99,2 / **231,6** / 20 | KO avant comme après |
| Page de suivi | 62,8 / 33,6 / 17,3 / 12 | 78,9 / 53,5 / 39,0 / 18 | OK |
| Cadre d'une catégorie (`Turbo-Frame`) | 37,8 / 25,1 / 3,6 / 9 | 48,8 / 38,9 / 25,4 / 15 | OK |

Les p95 des trois exécutions, après les lots :
- page classe : 153,4, 154,8 et 137,4 ;
- page de suivi : 78,9, 93,6 et 76,7.

Sur la page classe, les 231,6 Ko se répartissent ainsi :
- 147,7 Ko pour le registre des élèves (déjà là) ;
- 49,0 Ko pour les exercices assignés, dont 34,1 Ko pour les 7 pieds ;
- dans ces pieds, 26,7 Ko pour les 28 icônes trophée en SVG en ligne, environ 950 octets chacune.

Le nombre de requêtes ne dépend pas du nombre d'exercices : 20 requêtes à 10 exercices assignés comme à 1 (test d'intégration, hors dépôt).

### Défauts trouvés (non corrigés : hors du champ du Lot C)

- **D1 — Test système existant rouge.** `test/system/classroom/classroom_page_test.rb:120` vérifie `assert_no_text "Awa Bamba"` sur le suivi. Depuis le Lot B, la section « Pas encore faits · 1 » nomme Awa Bamba (ADR-0079 §4.8), donc le test échoue. Le comportement est voulu : c'est le test qui est périmé. Il faut le limiter à `#late_students`. Hors du champ du Lot B, qui ne l'a pas mis à jour.
- **D2 — Le pied ne tient pas sur une ligne au téléphone.** Fichiers : `_circle.html.erb` (`flex-wrap`) et le pied de `_assigned_exercises.html.erb`. À 390 px, le cas courant (« Pas encore lisible · 4/25 », badges à un chiffre) fait passer le cercle sur trois lignes : la pastille au-dessus, puis le libellé coupé, puis le ratio. Le bloc fait 64 px de haut au lieu de 20. À 360 px, avec « En difficulté · 35/45 », il fait quatre lignes et 84 px. L'UDR-0072 §3.4 demande une ligne, et ne permet au ratio de passer sous la pastille que sous 360 px.
- **D3 — La page classe est hors budget, et le chantier l'alourdit.** Elle était déjà hors budget avant le chantier : 143,7 ms et 197,5 Ko. Le pied ajoute 34,1 Ko, soit +17 %, et environ 10 ms de p95. Le levier est visible : les 28 trophées SVG identiques, à mettre en `<symbol>` ou en `<use>`. Le reste vient du registre des élèves. L'ADR-0067 demande d'ouvrir un chantier `optimize`.
- **D4 — Le jeu de mesure de l'ADR-0067 est cassé.** `script/perf/dataset.rb` ne se sème plus depuis la contrainte `classroom_assignments_type_values` (voir plus haut), et il ne sème aucune tentative de question. Toute mesure future du suivi demande de le réparer.
- **D5 — La durée du nouveau test système n'est pas enregistrée.** Avec `test/system/classroom/comprehension_test.rb`, la suite complète passe à 3 665 tests, avec 1 échec : `test/guards/system_budget_test.rb:15`, « durée non enregistrée ». La durée mesurée est de 9,6 s (4,0, 4,0 et 1,6 s), sous le budget de 15 s du chantier (ADR-0069 §9). Il faut l'enregistrer avec `bin/rails test test/system/classroom/comprehension_test.rb -v 2>&1 | script/ci/record_timings`. Le fichier écrit, `script/ci/test_timings.yml`, est hors du champ du Lot C.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-05 (fusion dans `Develop`) |
| **PR** | [#164](https://github.com/Lnclassapp/App.Lnclassapp/pull/164) |
| **ADR produits** | [ADR-0079](../../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) ; compléments datés de l'ADR-0072 (2026-10-04, bis) |
| **UDR produits** | [UDR-0072](../../decisions/udr/0072-comprehension-d-un-exercice-assigne.md) (amende l'UDR-0062 §3.4 et §3.5) |
| **Preuve** | Suite complète, couverture 100 % lignes et branches ; tests système du chantier dans Chromium 141 ; challenger empirique (phase 5) : défauts D1 à D4 corrigés ou portés en dette ; rubocop, brakeman, pureté du domaine au vert |
| **Chantiers de suivi** | `optimize page-classe-legere` (page classe hors budget, préexistant) ; `script/perf/dataset.rb` sans `question_attempts` ; `progres-eleve` (fusionné, #168) |
