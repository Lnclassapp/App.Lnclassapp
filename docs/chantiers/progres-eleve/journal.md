# Journal — L’élève voit son propre progrès

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

## Rapport du challenger

> Phase 5, 2026-10-04. Ce rôle n'a écrit aucun code du chantier. Il n'a pas relu le code : il a exécuté le parcours dans Chromium 141 (`/opt/pw-browsers/chromium-1194`), avec le chromedriver 141 passé par `CHROMEDRIVER_PATH`.

### Test système

`test/system/assessment/student_progress_test.rb` contient 2 tests. Chaque session y est jouée dans l'interface : « Commencer l'exercice » ou « Recommencer », une réponse cochée par question, « Valider », « Question suivante », puis « Voir mon résultat ».

- **Le parcours du PRD** : 1 bonne réponse sur 3, puis 3 sur 3. Le test est **rouge**, à cause du défaut D1. Tout passe jusqu'à la ligne 42 : 7/20 au premier résultat, sans phrase ; 20/20 au second. La ligne 42 attend « Tu progresses : 7/20 à ta première session, 20/20 aujourd'hui. », et aucune phrase n'est affichée.
- **Le parcours sans lacune** : une première session à 50 %, créée par la fabrique, puis une session à 2 sur 3, jouée dans l'interface. Ce test est **vert** sur 4 exécutions de suite.
- **Rouge d'abord** : avec `best: 14` au lieu de 13, le test échoue sur cette ligne (56). Il a trouvé « … reste 13/20 … ».
- **Durée enregistrée** : 17,7 s, dont 2 s d'attente de l'assertion rouge.

### Vérifications

| # | Vérification | Résultat | Preuve |
|---|---|---|---|
| 1 | L'élève fait l'exercice deux fois dans l'interface : peu de bonnes réponses, puis beaucoup | OK | 1 sur 3 donne 7/20, puis 3 sur 3 donne 20/20, sans aucun appui de la fabrique |
| 2 | « Tu progresses : X/20 à ta première session, Y/20 aujourd'hui. » sur le 2e résultat | **KO** (D1) | Parcours du PRD : aucune phrase, `#session_progress` est absent. En base : `[standard 25, remediation 75 (lacune 13)]`. Sans lacune (10/20 puis 13/20) : « Tu progresses : 10/20 à ta première session, 13/20 aujourd'hui. » |
| 3 | Refait mal : « Ton meilleur résultat reste Y/20. … » | **KO** (D2) | Parcours du PRD, joué dans l'interface : le 3e résultat dit « Tu restes autour de 5/20. Relis la correction ci-dessous avant de recommencer. », alors que la session d'avant valait 15/20. Sans lacune : « Ton meilleur résultat reste 13/20. Relis la correction, tu peux le retrouver. », icône `text-mute` |
| 4 | Le 2e résultat rouvert dit encore « Tu progresses » | OK | Sans lacune : même phrase, rouverte après la session ratée. Icône `text-success` |
| 5 | Premier essai d'un autre exercice : aucune phrase | OK | Pas de `#session_progress`, ni aucun des 4 débuts de phrase. Même constat au premier résultat du parcours du PRD |
| 6 | L'enseignant de la classe ouvre le 2e résultat : aucune phrase | OK | La page affiche « Élève : Awa Koné » et 13/20, sans `#session_progress` |
| 7 | Jamais « stagne », « baisse » ni « essai » | OK | 7 résultats ouverts. Absents du texte visible, du texte caché et du titre (assertions). Absents aussi du HTML brut (sonde) |
| 8 | Mode sombre (`data-theme="dark"`) : phrase lisible | OK | Fond de page `rgb(15, 18, 24)`, texte `rgb(238, 241, 245)` : contraste **15,09:1** (AA : 4,5). L'icône du progrès est `rgb(111, 214, 154)` |
| 9 | Téléphone, sans défilement horizontal | OK | À 390 px : `scrollWidth` 375 pour `clientWidth` 375. Aussi bon à 360 px (345/345) et à 320 px (305/305) |

### Défauts

**D1 — bloquant : la phrase du PRD n'apparaît jamais dans l'application réelle.** Le parcours nominal du PRD est « 30 %, puis 90 % ». Or une session sous `PASS_THRESHOLD` (50 %) ouvre une lacune en attente sur la fiche (ADR-0043). Tant que cette lacune est en attente, `StartExerciseSession` démarre chaque session suivante en `kind: "remediation"`. C'est vrai pour tous les exercices de la fiche, que l'élève passe par « Recommencer » ou par « Commencer l'exercice ».

Or l'UDR-0073 §3 retire les remédiations de l'historique, et elle ne rend aucune phrase sur leur résultat (commit `f30e60b4`). L'élève qui échoue puis réussit ne lit donc jamais « Tu progresses ». C'est pourtant l'élève que le chantier vise.

Les tests de contrôleur et de query ne voient pas le défaut : leurs fabriques créent des sessions `standard` après une session sous 50 %, ce que l'application ne fait jamais. Si la remédiation finit entre 50 et 74 % (sous `REMEDIATION_THRESHOLD`), la lacune reste en attente : toutes les sessions suivantes de la fiche sont des remédiations, et aucune phrase n'apparaît.

**D2 — majeur, conséquence de D1 : les phrases mentent après une remédiation.** La sonde a joué, dans l'interface, 4 questions par session :

| Session | Note | Type | Phrase affichée |
|---|---|---|---|
| 1 | 25 % | standard | aucune |
| 2 | 75 % | remédiation | aucune (lacune résolue) |
| 3 | 25 % | standard | « Tu restes autour de 5/20… » au lieu de « Ton meilleur résultat reste 15/20… » |
| 4 | 75 % | remédiation | aucune |
| 5 | 50 % | standard | « Tu progresses : 5/20 à ta première session, 10/20 aujourd'hui. » |

À la 5e session, son meilleur résultat, 15/20, a été obtenu deux fois, et la phrase l'ignore. La règle « historique = sessions standard » efface ses meilleures notes, celles qu'il a obtenues en remédiation sur le même exercice.

**Ce que le challenger ne tranche pas.** Le porteur doit décider :

- soit compter dans l'historique les remédiations faites sur le même exercice, et rendre la phrase sur leur résultat (UDR-0073 §3 à amender) ;
- soit écrire dans le PRD que la phrase ne concerne que les élèves sans lacune en attente.

Le premier test du fichier attend la première option. Si le porteur choisit la seconde, il faut réécrire ce test.

**D3 — garde du budget système.** `test/guards/system_budget_test.rb` échoue : la suite grandit de 25,7 s pour un budget de 15 s. Ces 25,7 s se répartissent ainsi :

- 17,7 s pour ce fichier ;
- 7,9 s pour `comprehension_test.rb`, héritées de `rapports-exercices`, fusionné dans cette branche mais pas encore dans `origin/Develop` ;
- 0,1 s pour `classroom_page_test.rb`.

Une fois D1 corrigé, le premier test ne paiera plus son attente de 2 s, et le fichier devrait tenir autour de 15,5 s. C'est encore au-dessus du budget : il faudra rendre la session jouée du second test à la fabrique, ou obtenir une rallonge du porteur.

**Rappel.** `script/ci/record_timings` perd encore le premier test d'un fichier lancé seul : la bannière « Capybara starting Puma... » coupe sa ligne. La bannière a été retirée du journal d'exécution avant l'enregistrement (déjà signalé dans `inscription-direction`).

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
