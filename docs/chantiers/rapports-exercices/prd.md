# PRD — Comprendre où en est la classe sur un exercice

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

> **Mission** (porteur, 2026-10-04) : Lnclass aide chaque acteur du système éducatif à progresser. Chaque lecture de ce chantier appelle un geste de l'enseignant.

L'enseignant assigne un exercice à sa classe et voit combien d'élèves l'ont fait (ADR-0072), mais pas s'ils l'ont compris, ni qui progresse. Ce chantier ajoute, à chaque exercice assigné, une **lecture de la compréhension** : chaque élève qui l'a fait est classé par son meilleur score (rouge, jaune, vert) et porte un signe de progrès ; un cercle donne la couleur dominante de la classe, au bord bas de l'exercice sur la page classe, et la page de suivi détaille les catégories, question par question. Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher (enseignant de la classe) | Voir, pour chaque exercice assigné de sa classe, les badges et le cercle ; ouvrir la section « Compréhension » de la page de suivi ; choisir une catégorie | Voir la statistique d'une classe où il n'enseigne pas |
| Team | Pareil, en lecture, sur toute classe | — |
| Student | — | Voir la statistique de sa classe, les scores ou les signes de ses camarades |
| SchoolStaff (direction) | — (inchangé : elle lit le travail des élèves dans son espace, ADR-0065) | Ouvrir la page de suivi d'un exercice assigné |
| Visiteur | — | Tout |

**Règle d'autorisation** : `Policies::Classroom::FollowAssignmentPolicy` (ADR-0072 §4.5), **inchangée**. Les badges, le cercle et la section ne se lisent qu'après elle : sur la page classe, sous son `show_follow_up` (les comptes « faits » suivent déjà cette règle) ; sur la page de suivi, avant toute lecture.

## 3. Parcours utilisateur

### Chemin nominal

1. L'enseignant ouvre la page de sa classe. Le bloc « Exercices assignés » liste ses exercices avec l'échéance et « 18 faits, dont 3 en retard · 7 pas encore faits ».
2. Au **bord bas** de chaque exercice : **à gauche**, les quatre badges avec leur nombre d'élèves ; **à droite**, isolé, le **cercle** de compréhension et « 18/25 ».
3. Le cercle est **gris** tant que moins de 5 élèves ont fait l'exercice ; ensuite il prend la couleur de la **catégorie dominante**.
4. L'enseignant touche l'exercice (ou le cercle) : la page de suivi s'ouvre. Sous les trois chiffres existants, la section **« Compréhension »** montre le grand cercle, la synthèse « 8 en progrès · 7 sans évolution · 3 en baisse », puis les trois catégories avec leur nombre d'élèves.
5. La catégorie dominante est choisie par défaut. L'enseignant en choisit une autre. La liste des **questions** affiche, pour les élèves de cette catégorie, le taux de réussite de chaque question au meilleur essai, et à côté le taux au premier essai s'ils ont recommencé. Les questions sous 50 % sont marquées « À reprendre en classe ».
6. Viennent ensuite les **élèves** de la catégorie, avec meilleur score et signe : d'abord ceux en baisse ou qui stagnent, ceux qui ont le plus besoin de lui.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun élève n'a fait l'exercice | Badges tous à zéro (atténués), cercle gris « 0/25 » ; section « Compréhension » : état vide « Personne n'a encore fait cet exercice. » |
| 1 à 4 élèves l'ont fait | Cercle gris ; la section affiche les catégories et le détail, précédés de « Moins de 5 élèves ont fait l'exercice : la tendance n'est pas encore fiable. » |
| Classe sans élève présent | Cercle gris « 0/0 », section en état vide |
| Catégorie sans élève choisie | État vide de la catégorie : « Aucun élève dans cette catégorie. » |
| Paramètre de catégorie inconnu | Ignoré : la catégorie dominante (ou « En difficulté » si personne) est choisie |
| Élève avec une seule session | Pas de signe ; « 1 session » à la place |
| Question sans réponse parmi les élèves de la catégorie | « — » au lieu d'un taux |
| Classe archivée | Tout reste lisible, rien ne change (lecture seule) |
| Tous les élèves ont fait l'exercice | La section « Pas encore faits » est absente |
| Élève, autre enseignant, direction | 403 sur la page de suivi ; sur la page classe, ni badges ni cercle (comme les comptes) |
| Assignation archivée, d'une autre classe ou inconnue | 404 (inchangé) |

## 4. Critères d'acceptation

Chacun devient un test. « Fait » = session `standard`, `completed`, rattachée à l'assignation, d'un élève présent (adhésion non quittée, compte non anonymisé) — ADR-0048, ADR-0072 §4.4.

### Règles de domaine (ADR-0079)

```gherkin
Scénario: catégorie d'un élève par son meilleur score
  Étant donné les meilleurs scores 49, 50, 69 et 70
  Alors leurs catégories sont « En difficulté », « Fragile », « Fragile » et « Acquis »

Scénario: signe de progrès
  Étant donné un élève dont les essais, dans l'ordre, valent 30, 60 puis 90
  Alors son signe est « en progrès »

Scénario: signe de baisse
  Étant donné un élève dont les essais valent 30, 90 puis 40
  Alors son signe est « en baisse »
  Et un élève dont les essais valent 90 puis 40 est « en baisse »

Scénario: stagne sous la maîtrise, stable au-dessus
  Étant donné un élève dont les essais valent 60, 60 puis 60
  Alors son signe est « stagne »
  Et un élève dont les essais valent 100 puis 100 est « stable »

Scénario: marge de 10 points aux bornes
  Étant donné un élève dont les essais valent 50 puis 59
  Alors son signe est « stagne »
  Et un élève dont les essais valent 50 puis 60 est « en progrès »
  Et un élève dont les essais valent 80, 90 puis 81 est « en progrès »
  Et un élève dont les essais valent 80, 90 puis 80 est « en baisse »

Scénario: un seul essai
  Étant donné un élève qui n'a qu'un essai
  Alors il n'a pas de signe

Scénario: catégorie dominante et égalité
  Étant donné 3 élèves « Acquis », 3 « Fragile » et 1 « En difficulté »
  Alors la catégorie dominante est « Fragile »
  Et à égalité « En difficulté » et « Acquis », la dominante est « En difficulté »

Scénario: seuil de lecture
  Étant donné 4 élèves qui ont fait l'exercice
  Alors la lecture n'est pas fiable
  Et avec 5 élèves elle l'est
```

### Page de la classe

```gherkin
Scénario: badges et cercle au bord bas d'un exercice assigné
  Étant donné une classe de 25 élèves présents et un exercice assigné
  Et 6 élèves l'ont fait avec pour meilleurs scores 100, 85, 72, 65, 40 et 30
  Quand l'enseignant de la classe ouvre la page de la classe
  Alors le bord bas de l'exercice montre à gauche 1 Diamant, 1 Or, 1 Argent, 1 Bronze
  Et à droite un cercle « Acquis » (3 Acquis, 1 Fragile, 2 En difficulté) et « 6/25 »

Scénario: cercle gris sous 5 élèves
  Étant donné 4 élèves qui ont fait l'exercice assigné, tous à 90
  Quand l'enseignant ouvre la page de la classe
  Alors le cercle est gris, sans catégorie, avec « 4/25 »

Scénario: seules les sessions de l'assignation comptent
  Étant donné un élève présent qui a terminé l'exercice depuis une autre classe à 100
  Et une session de remédiation à 100 sur l'exercice
  Et une session commencée non terminée
  Quand l'enseignant ouvre la page de la classe
  Alors aucune de ces sessions ne compte dans le cercle ni dans les badges

Scénario: élèves partis ou anonymisés exclus
  Étant donné un élève qui a fait l'exercice puis a quitté la classe
  Et un élève anonymisé qui l'a fait
  Alors ni l'un ni l'autre ne compte, et l'effectif affiché est celui des présents

Scénario: la page classe reste lisible pour l'équipe et muette pour l'élève
  Quand un membre de l'équipe ouvre la page de la classe
  Alors il voit les badges et le cercle
  Et un élève de la classe n'y accède pas (403, inchangé)
```

### Page de suivi — section « Compréhension »

```gherkin
Scénario: synthèse et catégories
  Étant donné 6 élèves qui ont fait l'exercice assigné
  Quand l'enseignant ouvre la page de suivi
  Alors la section « Compréhension » montre le cercle de la catégorie dominante
  Et les nombres d'élèves « En difficulté », « Fragile » et « Acquis »
  Et la synthèse « N en progrès · N sans évolution · N en baisse », sans les élèves à un seul essai

Scénario: taux par question pour une catégorie
  Étant donné deux élèves « Acquis » dont le meilleur essai a la question 1 juste pour l'un et fausse pour l'autre
  Quand l'enseignant choisit la catégorie « Acquis »
  Alors la question 1 affiche 50 %
  Et les questions sont numérotées dans l'ordre de l'exercice
  Et aucun taux ne dépasse 100 %, même si les élèves ont recommencé

Scénario: progrès par question et question à reprendre
  Étant donné deux élèves « Fragile » qui ont raté la question 2 au premier essai et réussi au meilleur
  Et la question 3 réussie par aucun des deux au meilleur essai
  Quand l'enseignant choisit la catégorie « Fragile »
  Alors la question 2 affiche 100 % et « 1re session : 0 % »
  Et la question 3 affiche 0 % et « À reprendre en classe »
  Et une question à 50 % n'est pas « À reprendre en classe »
  Et sans élève à deux essais, aucun taux au premier essai n'est affiché

Scénario: les élèves qui ont besoin de l'enseignant d'abord
  Étant donné dans une catégorie un élève en progrès, un élève en baisse, un élève qui stagne et un élève à un seul essai
  Alors la liste les montre dans l'ordre : en baisse, stagne, un seul essai, en progrès

Scénario: meilleur essai à égalité
  Étant donné un élève dont deux essais valent 80
  Alors c'est le plus récent des deux qui compte pour les taux par question

Scénario: liste des élèves d'une catégorie
  Quand l'enseignant choisit la catégorie « En difficulté »
  Alors il voit ses seuls élèves, avec meilleur score et signe

Scénario: catégorie dans l'adresse
  Quand l'enseignant ouvre la page de suivi avec la catégorie « Fragile » dans l'adresse
  Alors la catégorie « Fragile » est choisie
  Et une catégorie inconnue dans l'adresse est ignorée

Scénario: élèves pas encore faits nommés
  Étant donné 25 élèves présents, dont 18 ont fait l'exercice assigné et 1 n'a qu'une session commencée
  Quand l'enseignant ouvre la page de suivi
  Alors la section « Pas encore faits · 7 » nomme les 7 autres, par nom, l'élève à session commencée compris
  Et un élève parti ou anonymisé n'y figure pas
  Et sans élève en attente la section est absente

Scénario: refus
  Quand un élève de la classe, un enseignant d'une autre classe ou la direction ouvre la page de suivi
  Alors il reçoit 403
```

### Non-régression et budget

```gherkin
Scénario: les comptes existants ne bougent pas
  Alors « faits », « en retard » et « pas encore faits » restent identiques sur la page classe et la page de suivi

Scénario: budget de l'écran
  Étant donné le jeu de mesure de l'ADR-0067
  Alors la page classe et la page de suivi restent sous 100 ms p95 serveur et 150 Ko de HTML
  Et le nombre de requêtes de la page classe ne dépend pas du nombre d'exercices assignés
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::Comprehension` (module de règles pures, à côté de `Grading`) : `PROGRESS_MARGIN = 10`, `MIN_DONE_FOR_READING = 5`, `category_for(best)` (= `Grading.mastery_for`), `trend_for(scores)`, `dominant(counts)`, `readable?(done)`. Aucun port, aucun use case : lecture seule (CQRS, ADR-0026) |
| Infrastructure | `Queries::Assessment::AssignmentScores` (socle : par élève présent, scores chronologiques des sessions faites d'une ou plusieurs assignations, et l'identifiant du meilleur essai) ; `Queries::Assessment::ComprehensionSummaryQuery` (cercle et badges de plusieurs assignations, nombre de requêtes constant) ; `Queries::Assessment::ComprehensionDetailQuery` (catégories, synthèse, taux par question, élèves d'une catégorie). **Aucune migration** : l'index `index_exercise_sessions_handed_in` et l'index unique `(exercise_session_id, question_id)` des tentatives suffisent ; à vérifier au budget |
| Delivery | `ClassroomOverviewQuery::AssignmentRow` gagne `comprehension` (nil sans `show_follow_up`) ; `AssignmentFollowUpsController#show` lit `params[:category]` (liste blanche) et charge le détail après la policy. **Aucune route nouvelle** |
| UI | `assessment/comprehension/_circle`, `_badge_counts`, `_section` ; `Assessment::ComprehensionHelper` ; amendement de `_assigned_exercises` (bord bas) et de `assignment_follow_ups/show` (section) ; locales `assessment.comprehension.*` |

## 6. Décisions rattachées

- [ADR-0079](../../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) — règles de lecture : catégorie au meilleur score, signe à trois essais et marge de 10 points, seuil de 5 élèves, dominante à égalité vers la plus fragile, sessions de l'assignation seulement, badges déduits du meilleur score, lecture en direct sans cache.
- Élèves pas encore faits nommés sur la page de suivi : décision du porteur (2026-10-04), ADR-0079 §4.8, UDR-0072 §3.5 bis.
- [UDR-0072](../../decisions/udr/0072-comprehension-d-un-exercice-assigne.md) — bord bas de l'exercice sur la page classe (badges à gauche, cercle à droite) et section « Compréhension » de la page de suivi ; **amende l'UDR-0062 §3.4 et §3.5**.
- Inchangés et suivis : ADR-0033 (seuils), ADR-0048 et ADR-0072 (« fait », policy de suivi), ADR-0067 (budgets).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| p95 serveur, page classe (jeu ADR-0067) | à mesurer au Lot 0 | < 100 ms | **153,4 ms, 231,6 Ko : hors budget** (p50 99,2 ms ; 20 requêtes). Déjà hors budget avant le Lot A sur le même jeu : 143,7 ms, 197,5 Ko. Le pied ajoute 34,1 Ko, dont 26,7 Ko pour les 28 trophées SVG en ligne. Voir le [journal](journal.md#rapport-du-challenger) |
| p95 serveur, page de suivi | à mesurer au Lot 0 | < 100 ms | **78,9 ms, 39,0 Ko** (p50 53,5 ms ; 18 requêtes). Cadre d'une catégorie : 48,8 ms, 25,4 Ko. Avant les lots A et B, même jeu : 62,8 ms, 17,3 Ko |
| Requêtes SQL, page classe à 10 exercices assignés | à mesurer | même nombre qu'à 1 exercice | **20 à 10 exercices, 20 à 1** (test d'intégration) ; 20 en production avec les 7 exercices de la classe mesurée |
