# PRD — Corriger une copie comme en classe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Après sa copie rendue, l'élève voit sa note, son verdict question par question et l'explication, mais jamais la bonne réponse,
ni une appréciation qui lui dise ce qu'il doit revoir ([memo](memo.md)). Le porteur a décidé le 2026-10-28 de lui montrer la
correction complète et de lui donner une appréciation de professeur. La meilleure note continue de compter, et « Recommencer »
se met en pause après 3 copies rendues d'affilée (D2 révisée au grill, validée par le porteur le même jour).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student (auteur de la copie) | Après sa copie rendue : lire sa réponse, la bonne réponse et l'explication de chaque question, l'appréciation et la phrase d'encouragement. Recommencer, sauf pendant la pause | Voir une bonne réponse avant d'avoir rendu sa copie, ni dans une copie abandonnée. Lire la copie d'un autre élève. Démarrer une copie pendant la pause, d'où qu'il parte |
| Teacher (enseigne à l'élève) | Lire le résultat de l'élève, bonnes réponses comprises (déjà le cas), et la même appréciation | Lire la phrase d'encouragement (adressée à l'élève seul). Recommencer à la place de l'élève |
| Team | Comme l'enseignant | Comme l'enseignant |
| SchoolAdmin | Rien de nouveau : ce chantier ne change pas ce qu'il lit | — |
| Parent | Ce rôle n'existe pas dans l'application | — |

Règles d'autorisation :

- **Lire un résultat** : `ReadSessionPolicy`, inchangée.
- **Voir les bonnes réponses dans un résultat** : une nouvelle `RevealCorrectionPolicy`. L'équipe et l'enseignant les voient comme aujourd'hui ; l'élève auteur les voit seulement sur une copie rendue (`completed`). `RevealAnswersPolicy` reste celle de la page de l'exercice, où l'élève ne voit jamais les bonnes réponses.
- **Démarrer une copie** : `StartSessionPolicy`, inchangée, puis la pause, vérifiée par le use case `StartExerciseSession`.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève fait l'exercice d'un seul tenant et clique sur « Rendre ma copie » (inchangé, D4).
2. La page du résultat s'ouvre. En titre, l'**appréciation**, selon la note sur 20 affichée :
   - « Très bien » dès 16/20 ;
   - « Bien » dès 12 ;
   - « Assez bien » dès 10 ;
   - « À retravailler » en dessous.

   Sous le titre, la phrase d'encouragement tirée au hasard (inchangée), puis **ce qu'il faut revoir** :
   - pour un exercice de notion : la notion et les questions en cause, par exemple « À revoir : « Calculer une longueur », questions 2 et 4 » ;
   - pour un exercice de toute la leçon : les questions en cause et un renvoi à la leçon, par exemple « À revoir dans la leçon : questions 2 et 4 ».

   Une question est **en cause** quand elle est fausse ou sans réponse. Une copie sans question en cause n'affiche rien à revoir.
3. Dans la correction, pour chaque question, l'élève voit :
   - le verdict (« Juste », « Faux » ou « Sans réponse ») ;
   - son choix ;
   - la bonne réponse, selon le type de question : propositions correctes, réponses acceptées, valeur attendue, bon ordre ou bonnes paires ;
   - l'explication.
4. L'élève clique sur « Refaire l'exercice » : une nouvelle copie s'ouvre. La meilleure note continue de compter partout, comme aujourd'hui.
5. Après sa 3e copie rendue d'affilée, la page du résultat ne propose plus « Refaire l'exercice » ; elle dit « Tu pourras recommencer à 21 h 14. ». La page de l'exercice dit la même chose, à la place de son bouton.

**« D'affilée »** : moins de 30 minutes entre la fin d'une copie rendue et la fin de la suivante. La pause dure **30 minutes à partir de la fin de la 3e copie** de la série. Ensuite, une nouvelle série de 3 copies est possible.

Règle exacte : on prend les 3 dernières copies rendues de l'élève sur cet exercice (toutes sortes confondues : libre, devoir, remédiation). Il est en pause si :
- elles sont 3 ;
- moins de 30 minutes séparent la fin de la 1re de la fin de la 2e, et la fin de la 2e de la fin de la 3e ;
- moins de 30 minutes se sont écoulées depuis la fin de la 3e.

Les copies abandonnées ne comptent pas.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Question laissée vide | Verdict « Sans réponse », pas de « Ton choix » ; la bonne réponse et l'explication s'affichent ; la question est en cause |
| Copie entièrement vide | 0/20, « À retravailler », toutes les questions en cause |
| Copie sans faute | « Très bien », rien à revoir, pas de « Refaire l'exercice » (inchangé : sans-faute) |
| Copie abandonnée (« Recommencer » pendant la copie, ou depuis un autre onglet) | Jamais corrigée : son résultat n'existe pas, aucune bonne réponse n'est montrée ; elle ne compte pas dans la série |
| Copie en cours | La feuille ne montre aucune bonne réponse (inchangé) |
| Exercice assigné par l'enseignant | Même correction et même appréciation. La copie de devoir compte dans la série. La note du devoir reste la meilleure (inchangé) |
| Exercice de toute la leçon | L'appréciation nomme les questions en cause et renvoie à la leçon (`#toute-la-lecon`), jamais une notion |
| Copie de remédiation (lacune ouverte) | Même correction. Elle compte dans la série. La lacune s'ouvre ou se referme comme aujourd'hui |
| Leçon réimportée entre deux copies | Le réimport crée un nouvel exercice en brouillon : l'ancienne copie garde sa correction (les questions d'un exercice ayant des copies sont verrouillées). La série se compte par exercice : les copies de l'ancien ne comptent pas pour le nouveau |
| Pendant la pause, l'élève poste « Faire l'exercice » ou « Refaire l'exercice » depuis l'accueil, l'historique ou un autre onglet | Aucune copie n'est créée ; retour à la page de l'exercice, avec l'alerte « Tu as rendu 3 copies d'affilée. Tu pourras recommencer à 21 h 14. » |
| Pendant la pause, une copie de cet exercice est déjà en cours | Impossible : la pause suit la fin d'une copie, et une seule copie est ouverte par exercice |
| L'enseignant ou l'équipe lit le résultat | Même appréciation, sans la phrase d'encouragement ; les bonnes réponses comme aujourd'hui |
| Un autre élève ouvre l'adresse du résultat | 403 (inchangé, `ReadSessionPolicy`) |

## 4. Critères d'acceptation

```gherkin
# CA-01 — La correction complète après la copie rendue
Étant donné un élève qui a rendu sa copie d'un exercice à choix
Quand il ouvre son résultat
Alors chaque question montre sa proposition cochée marquée « Ton choix »
Et la proposition correcte marquée « Proposition correcte »
Et l'explication

# CA-02 — La bonne réponse pour chaque type de question
Étant donné un élève qui a rendu une copie avec une question à trou, une numérique, une d'ordre et une d'association
Quand il ouvre son résultat
Alors il voit les réponses acceptées, la valeur attendue, le bon ordre et les bonnes paires

# CA-03 — Question laissée vide
Étant donné une copie rendue avec la question 2 sans réponse
Quand l'élève ouvre son résultat
Alors la question 2 porte « Sans réponse », sans « Ton choix »
Et sa bonne réponse et son explication s'affichent

# CA-04 — Jamais avant la copie rendue
Étant donné un élève qui a une copie en cours
Quand il ouvre sa feuille
Alors aucune bonne réponse n'apparaît dans la page

# CA-05 — Jamais sur une copie abandonnée
Étant donné une copie abandonnée
Quand son élève demande l'adresse de son résultat
Alors aucune correction n'est rendue

# CA-06 — La règle de révélation
Étant donné RevealCorrectionPolicy
Alors elle accepte l'équipe, l'enseignant qui lit l'exercice et l'élève auteur d'une copie rendue
Et elle refuse l'élève auteur d'une copie en cours ou abandonnée, et tout autre élève

# CA-07 — Les seuils de l'appréciation, sur la note affichée
Étant donné des copies notées 20, 16, 15, 12, 11, 10, 9 et 0 sur 20
Alors leurs appréciations sont « Très bien », « Très bien », « Bien », « Bien », « Assez bien », « Assez bien », « À retravailler », « À retravailler »
Et un score de 79 %, affiché 16/20, donne « Très bien »

# CA-08 — Ce qu'il faut revoir, exercice de notion
Étant donné une copie d'un exercice de la notion « Calculer une longueur », fausse aux questions 2 et 4
Quand l'élève ouvre son résultat
Alors il lit « À revoir : « Calculer une longueur », questions 2 et 4 »

# CA-09 — Ce qu'il faut revoir, exercice de toute la leçon
Étant donné une copie d'un exercice de toute la leçon, fausse à la question 3
Quand l'élève ouvre son résultat
Alors il lit « À revoir dans la leçon : question 3 » avec un lien vers la section « Toute la leçon »
Et aucune notion n'est nommée

# CA-10 — Rien à revoir
Étant donné une copie sans faute
Quand l'élève ouvre son résultat
Alors il lit « Très bien » et aucune ligne « À revoir »

# CA-11 — Le titre remplace « Félicitations ! » et « Courage ! »
Étant donné une copie notée 13/20
Quand l'élève ouvre son résultat
Alors le titre est « Bien »
Et la page ne contient ni « Félicitations ! » ni « Courage ! »
Et une phrase d'encouragement suit le titre

# CA-12 — L'enseignant lit la même appréciation
Étant donné une copie d'un élève notée 9/20, fausse aux questions 1 et 3
Quand son enseignant ouvre le résultat
Alors il lit « À retravailler » et les questions 1 et 3
Et aucune phrase d'encouragement

# CA-13 — La pause après 3 copies d'affilée
Étant donné un élève qui a rendu 3 copies du même exercice à 10 h 00, 10 h 10 et 10 h 20
Quand il demande une nouvelle copie à 10 h 49
Alors aucune copie n'est créée
Et il revient sur la page de l'exercice avec « Tu pourras recommencer à 10 h 50. »

# CA-14 — La fin de la pause
Étant donné les mêmes 3 copies
Quand il demande une nouvelle copie à 10 h 50
Alors une copie s'ouvre

# CA-15 — Pas d'affilée, pas de pause
Étant donné 3 copies rendues à 10 h 00, 10 h 40 et 10 h 50
Quand l'élève demande une nouvelle copie à 10 h 55
Alors une copie s'ouvre

# CA-16 — Les copies abandonnées ne comptent pas
Étant donné 2 copies rendues à 10 h 00 et 10 h 10, puis une copie abandonnée à 10 h 15
Quand l'élève demande une nouvelle copie à 10 h 16
Alors une copie s'ouvre

# CA-17 — Toutes les sortes de copies comptent, exercice par exercice
Étant donné une copie libre, une copie de devoir et une copie de remédiation du même exercice, rendues à 10 minutes d'intervalle
Alors l'élève est en pause sur cet exercice
Et il peut démarrer un autre exercice

# CA-18 — La pause se voit sur le résultat et sur l'exercice
Étant donné un élève en pause jusqu'à 10 h 50
Quand il ouvre le résultat de sa 3e copie, puis la page de l'exercice
Alors aucune des deux ne propose « Refaire l'exercice »
Et chacune dit « Tu pourras recommencer à 10 h 50. »

# CA-19 — Une copie recommencée garde la meilleure note
Étant donné un élève qui rend une copie de devoir à 8/20, puis une à 19/20
Quand son enseignant ouvre le suivi du devoir
Alors il lit 19/20 comme meilleure note (règle inchangée)
```

CA-19 est le test de non-régression de la règle de note : la révision de D2 ne change aucun calcul.

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::Appreciation` (niveau selon la note sur 20 affichée, questions en cause, portée notion ou leçon) ; `Entities::Assessment::RestartPause` (règle de la série de 3 et des 30 minutes, à partir des fins de copies) ; `Policies::Assessment::RevealCorrectionPolicy` ; `UseCases::Assessment::StartExerciseSession` refuse pendant la pause (`:conflict`, `base: [:paused]`) ; méthode de port `ExerciseSessionRepositoryPort#recent_completions` |
| Infrastructure | `Repositories::Assessment::ExerciseSessionRepository#recent_completions` (index `student_id, completed_at` existant, pas de migration) ; `Queries::Assessment::ExerciseProgressQuery` donne la fin de la pause |
| Delivery | `SessionResultsController#show` (révélation, appréciation, pause) ; `ExerciseSessionsController#create` (pause : 303 vers l'exercice, avec alerte) ; `ExercisesController#show` (pause) ; aucune route nouvelle |
| UI | `session_results/show`, `_question_review`, `kinds/_choice_review` (« Ton choix » pour l'élève), `exercises/show` (pied d'actions) ; locales `session_results.fr.yml`, `exercises.fr.yml`, `exercise_sessions.fr.yml` |

## 6. Décisions rattachées

- [ADR-XXXX-correction-complete-et-pause-de-recommencer](../../decisions/adr/XXXX-correction-complete-et-pause-de-recommencer.md) : la révélation après la copie rendue (nouvelle policy) et la pause (nouvelle méthode de port).
- [UDR-XXXX-resultat-corrige-comme-en-classe](../../decisions/udr/XXXX-resultat-corrige-comme-en-classe.md) : la page du résultat (titre, « À revoir », correction complète) et le pied d'actions de la page de l'exercice pendant la pause. Elle remplace UDR-0023 sur le point « jamais les bonnes réponses à l'élève ».

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes de la page du résultat (élève) | à mesurer au Lot 0 | + 1 au plus (fins de copies) | |
