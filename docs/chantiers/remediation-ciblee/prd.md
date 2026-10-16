# PRD — Remédiation ciblée

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **Écrit selon les recommandations du [memo](memo.md#ce-que-le-grill-a-révélé) (Q1 à Q12), en attente de validation du porteur.**

## 1. Contexte

La lacune s'ouvre et se lève déjà à la clôture (ADR-0043), et toute session sur une fiche à revoir est déjà une remédiation. Il manque deux choses. L'élève doit être guidé vers le bon exercice, avec une règle lisible sur 20 et le verdict sur son résultat (AS-16). L'enseignant doit voir, sur ses pages de classe, quels élèves sont à revoir sur quelle fiche et lesquels l'ont levée (AS-17).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir ses fiches à revoir (accueil, fiche) ; démarrer l'exercice proposé ; lire sur son résultat l'effet de la session sur sa fiche | Voir les lacunes d'un camarade ; choisir une « remédiation » hors d'une fiche à revoir |
| Teacher (de la classe) | Voir, sur la page de sa classe, les fiches à revoir de ses élèves présents et leur nombre ; voir, sur la fiche vue depuis la classe, les noms des élèves à revoir et de ceux qui l'ont levée | Voir les lacunes d'une classe qu'il n'enseigne pas |
| Team | La même lecture, toutes matières | — (lecture seule ; aucune action sur une lacune) |
| SchoolStaff | — | Voir une lacune ou un nom (ADR-0072 §4.5) |

**Autorisation** :
- Élève : `StartSessionPolicy` existante, pour démarrer. Le résultat, sous `ReadSessionPolicy`, ne montre l'effet sur la fiche qu'à son propriétaire.
- Enseignant et équipe : `Policies::Classroom::ReadClassroomPolicy`, déjà appliquée par les deux pages de classe. La lecture nominative des lacunes n'a lieu que si `show_roster` vaut vrai.

## 3. Parcours utilisateur

### Chemin nominal — élève (AS-16)

1. Awa obtient 6/20 à l'exercice « Thalès 1 » de la fiche « Théorème de Thalès » : la fiche passe à revoir.
2. Son résultat le lui dit : « Cette fiche passe à revoir. Relis-la, puis obtiens au moins 15/20 à l'un de ses exercices. »
3. Sur son accueil, la carte « Fiches essentielles à revoir » liste la fiche ; elle l'ouvre.
4. L'encart « Fiche essentielle à revoir » propose « Refaire un exercice », avec en dessous « Exercice proposé : Thalès 2 » (fixation, différent de « Thalès 1 »).
5. Le bouton démarre la session de « Thalès 2 » ; elle est de type remédiation.
6. Awa obtient 16/20 : le résultat affiche « Fiche levée ». La fiche quitte son accueil.

### Chemin nominal — enseignant (AS-17)

1. M. Koné ouvre la page de sa 3ème B. Un bloc « Fiches à revoir » liste « Théorème de Thalès · 4 élèves », puis les autres fiches.
2. Il ouvre la fiche : la page « fiche dans la classe » montre, au-dessus des exercices, la section « Élèves à revoir » (Awa Bamba, depuis le 12 octobre, 3 essais sous la moyenne ; …) et « Fiche levée » (Yao Kouassi, le 14 octobre ; …).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| La fiche n'a qu'un exercice publié | Le bouton propose cet exercice, même si c'est celui qui a été raté |
| La fiche n'a aucun exercice publié | L'encart s'affiche, sans bouton (comportement actuel) |
| L'exercice proposé a une session commencée | Le bouton la reprend (`StartExerciseSession`, sans `restart`) |
| Remédiation entre 10/20 et 14/20 | Résultat : « Encore à revoir : vise 15/20 ». La fiche reste à revoir. Confettis et titre inchangés à 14/20 |
| Session sans effet sur une fiche (aucune lacune, ou fiche levée par une autre session) | Aucune ligne sur le résultat |
| L'enseignant ou l'équipe ouvre le résultat d'un élève | Aucune ligne sur la fiche (élève seul) |
| Aucun élève présent n'a de fiche à revoir | Pas de bloc « Fiches à revoir » sur la page de classe |
| Aucune lacune sur la fiche dans la classe | Pas de section sur la fiche vue depuis la classe |
| Élève parti de la classe ou anonymisé | Absent des deux pages |
| Lacune levée l'année scolaire précédente | Absente de « Fiche levée » |
| Enseignant d'une autre classe, direction, élève | Refus existant des pages de classe (404 / 403 actuels), inchangé |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: L'élève lève une fiche à revoir (AS-16)

  Contexte:
    Étant donné la fiche publiée « Théorème de Thalès » avec les exercices publiés
      | titre     | type       | position |
      | Thalès 1  | evaluation | 1        |
      | Thalès 2  | evaluation | 2        |
      | Thalès 3  | fixation   | 3        |
    Et l'élève Awa, de 3ème B, qui a obtenu 30 % à « Thalès 1 »

  Scénario: Le résultat annonce l'ouverture de la lacune
    Quand Awa lit le résultat de sa session sur « Thalès 1 »
    Alors elle lit « Cette fiche passe à revoir »
    Et la règle « au moins 15/20 »

  Scénario: La fiche propose un exercice de fixation différent de l'exercice raté
    Quand Awa ouvre la fiche « Théorème de Thalès »
    Alors l'encart « Fiche essentielle à revoir » dit « au moins 15/20 », jamais « 75 % »
    Et le bouton « Refaire un exercice » propose « Thalès 3 »

  Scénario: Sans fixation, un autre exercice que l'exercice raté, par position
    Étant donné que « Thalès 3 » est archivé
    Quand Awa ouvre la fiche « Théorème de Thalès »
    Alors le bouton propose « Thalès 2 »

  Scénario: Fiche à un seul exercice
    Étant donné que « Thalès 2 » et « Thalès 3 » sont archivés
    Quand Awa ouvre la fiche « Théorème de Thalès »
    Alors le bouton propose « Thalès 1 »

  Scénario: Le bouton démarre une session de remédiation
    Quand Awa touche « Refaire un exercice »
    Alors une session de « Thalès 3 » est ouverte, de type « remediation », rattachée à sa lacune
    Et Awa est sur la page de la session, sans passer par la page de l'exercice

  Scénario: Une remédiation réussie lève la fiche
    Quand Awa termine la session de remédiation avec 80 %
    Alors le résultat affiche « Fiche levée »
    Et la fiche n'est plus dans « Fiches essentielles à revoir » sur son accueil

  Scénario: Une remédiation à 14/20 ne lève pas la fiche
    Quand Awa termine la session de remédiation avec 70 %
    Alors le titre reste « Félicitations ! »
    Et le résultat affiche « Encore à revoir : vise 15/20 »
    Et la fiche reste à revoir

  Scénario: Le résultat ne parle que de la session lue
    Étant donné qu'Awa a terminé une remédiation à 60 % puis une autre à 90 %
    Quand elle relit le résultat de la session à 60 %
    Alors aucune ligne ne parle de la fiche

  Scénario: L'enseignant ne lit pas la ligne de l'élève
    Quand l'enseignant de la 3ème B ouvre le résultat de la session à 80 % d'Awa
    Alors aucune ligne ne parle de la fiche

  Scénario: L'aide donne la règle sur 20
    Quand Awa ouvre l'aide, question « Pourquoi une fiche est-elle « à revoir » ? »
    Alors la réponse dit « moins de 10/20 » et « au moins 15/20 »
```

```gherkin
Fonctionnalité: L'enseignant suit les fiches à revoir de sa classe (AS-17)

  Contexte:
    Étant donné la 3ème B de l'année 2026-2027, enseignée par M. Koné (mathématiques)
    Et la fiche publiée « Théorème de Thalès » d'un cours de mathématiques de 3ème
    Et les élèves présents Awa (fiche à revoir depuis le 12 octobre, 3 échecs), Bintou (fiche à revoir, 1 échec)
    Et Yao, dont la fiche a été levée le 14 octobre

  Scénario: Le bloc de la page de classe compte les élèves à revoir par fiche
    Quand M. Koné ouvre la page de la 3ème B
    Alors le bloc « Fiches à revoir » affiche « Théorème de Thalès » avec « 2 élèves »
    Et la ligne mène à la fiche vue depuis la 3ème B

  Scénario: Les fiches d'une autre matière n'apparaissent pas pour l'enseignant
    Étant donné qu'Awa a aussi une fiche de physique à revoir
    Quand M. Koné ouvre la page de la 3ème B
    Alors le bloc ne liste pas la fiche de physique
    Mais un membre de l'équipe la voit sur la même page

  Scénario: Trois fiches, puis « Voir plus », triées par nombre d'élèves
    Étant donné quatre fiches à revoir dans la classe, avec 1, 4, 2 et 3 élèves
    Quand M. Koné ouvre la page de la 3ème B
    Alors les fiches visibles sont celles à 4, 3 et 2 élèves, dans cet ordre
    Et « Voir plus » révèle la quatrième sans requête

  Scénario: Aucune fiche à revoir
    Étant donné qu'aucun élève présent n'a de fiche à revoir
    Quand M. Koné ouvre la page de la 3ème B
    Alors le bloc « Fiches à revoir » n'est pas affiché

  Scénario: La fiche dans la classe nomme les élèves
    Quand M. Koné ouvre « Théorème de Thalès » depuis la 3ème B
    Alors la section « Élèves à revoir » liste Awa puis Bintou, la plus ancienne lacune d'abord
    Et Awa porte « depuis le 12 octobre » et « 3 essais sous la moyenne »
    Et Bintou ne porte pas de compte d'essais
    Et la section « Fiche levée » liste Yao avec « le 14 octobre »
    Et aucune mention ne distingue une remédiation d'une correction seule

  Scénario: Élève parti ou anonymisé
    Étant donné que Bintou a quitté la 3ème B
    Quand M. Koné ouvre « Théorème de Thalès » depuis la 3ème B
    Alors Bintou n'est pas listée
    Et le bloc de la page de classe affiche « 1 élève »

  Scénario: Lacune levée l'année précédente
    Étant donné qu'une lacune de Yao a été levée en juin 2026
    Quand M. Koné ouvre la fiche depuis la 3ème B de 2026-2027
    Alors cette lacune n'apparaît pas dans « Fiche levée »

  Scénario: Lecture refusée
    Quand un enseignant d'une autre classe, la direction ou un élève demande la fiche vue depuis la 3ème B
    Alors il reçoit le refus actuel de la page, et aucun nom n'est lu
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::RemediationPick` (choix de l'exercice, pur) · `Entities::Assessment::GapOutcome` (effet d'une session sur sa fiche, pur : `:opened`, `:lifted`, `:still_pending`, `nil`). Aucun use case ni port nouveau |
| Infrastructure | `Queries::Catalog::EssentialDetailQuery` : `GapRow` gagne l'exercice proposé · `Queries::Assessment::SessionResultQuery` : `gap_outcome` · **nouveau** `Queries::Assessment::ClassroomGapsQuery` (`summary`, `detail`). Aucune migration |
| Delivery | `Classroom::ClassroomsController`, `Classroom::ClassroomEssentialsController` : appellent `ClassroomGapsQuery` si `show_roster`. Aucune route |
| UI | `catalog/essentials/show` (`#essential_gap`) · `assessment/session_results/show` + `_gap_outcome` · `classroom/classrooms/show` + `_gaps` · `classroom/classroom_essentials/show` + `_gaps` |

## 6. Décisions rattachées

- [ADR-0101](../../decisions/adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) : la remédiation se lance par `StartExerciseSession`, l'exercice proposé est choisi à la lecture, l'enseignant lit les lacunes sous `ReadClassroomPolicy`. Amende l'ADR-0043.
- [UDR-0119](../../decisions/udr/0119-fiche-a-revoir-exercice-propose-et-regle-sur-20.md) : encart de la fiche à revoir, exercice proposé, règle sur 20.
- [UDR-0120](../../decisions/udr/0120-effet-de-la-session-sur-la-fiche-dans-le-resultat.md) : effet de la session sur la fiche, dans le résultat.
- [UDR-0121](../../decisions/udr/0121-fiches-a-revoir-de-la-classe-pour-l-enseignant.md) : fiches à revoir de la classe, pour l'enseignant.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de la page de classe | 20 (enseignant, 1 ou 30 élèves à revoir) | + 1 au plus, quel que soit le nombre d'élèves | **21** à 1 et à 30 élèves (+ 1, sur `knowledge_gaps`) |
| Requêtes SQL de la fiche vue depuis la classe | 17 | + 1 au plus | **18** à 1 et à 30 élèves (+ 1) |
| Page de classe, p95, jeu de l'ADR-0067 | à mesurer (Lot C) | dans le budget de 100 ms de l'ADR-0067, ou écart noté | SQL ajouté seul, 30 lectures après 3 de chauffe : `summary` **5,5 ms** (classe mesurée de l'enseignant `0520000001`, 55 élèves, aucune fiche à revoir dans sa matière) et **6,5 ms** (classe la plus touchée, lue par l'équipe : 12 cours, 10 fiches) ; `detail` **3,8 ms** (16 à revoir). Page entière non remesurée : voir le journal |

Mesure du 2026-10-16, base de test, jeu `script/perf/dataset.rb` corrigé comme dans `remediation-comptee-faite` : 14 775 sessions passées en remédiation, une lacune levée par sa dernière remédiation à 75 % ou plus (6 417 levées, 80 563 en attente), puis `VACUUM ANALYZE`. Requêtes comptées par requête HTTP réelle, hors `SCHEMA` et `TRANSACTION`.
