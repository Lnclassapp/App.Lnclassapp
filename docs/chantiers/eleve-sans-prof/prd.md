# PRD — L'élève sans enseignant a quelque chose à faire dès l'accueil

## 1. Objectif

L'élève sans classe active voit, sur son accueil, les matières et l'exercice du jour de son dernier niveau, et peut ouvrir une leçon ou faire un exercice corrigé sans attendre un enseignant.

## 2. Acteur

Élève connecté, sans classe principale active de l'année en cours.

## 3. Règle

Le niveau de l'élève vient de ses classes actives de l'année. S'il n'en a aucune, c'est le niveau et la série de sa dernière classe principale. S'il n'en a jamais eu, il n'a pas de niveau. La même règle sert à l'accueil, à l'exercice du jour et aux cinq portes du catalogue (catalogue, cours, fiche, exercice, session).

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 — sans classe active, la grille et l'exercice du jour de son dernier niveau
  Étant donné un élève retiré de sa classe de Tle, niveau qui a un cours de SVT publié
  Quand il ouvre son accueil
  Alors la carte dit « Choisis ta classe » avec « Rejoindre » en bouton principal
  Et sous le code, un bloc « Exercice du jour » avec son titre, sa matière et « Faire l'exercice du jour » en bouton secondaire
  Et sous la carte, la grille « Mes matières » montre SVT, sans case « Inviter »
  Et ni annonces ni historique

Scénario: CA-2 — la matière et l'exercice du jour s'ouvrent ; un autre niveau reste fermé
  Étant donné le même élève
  Quand il ouvre le catalogue de SVT, puis le cours
  Alors le cours s'affiche
  Et le cours d'un autre niveau répond « introuvable »
  Et « Faire l'exercice du jour » démarre une session corrigée

Scénario: CA-3 — aucun niveau connu : rien ne change
  Étant donné un élève qui n'a jamais eu de classe, ou dont le dernier niveau n'a aucun cours publié
  Quand il ouvre son accueil
  Alors il ne voit que « Choisis ta classe », sans grille ni exercice du jour

Scénario: CA-4 — niveau sans leçon publiée : un message honnête
  Étant donné un élève d'une classe dont le niveau n'a aucun cours publié
  Quand il ouvre son accueil
  Alors la grille dit « Les cours de ton niveau arrivent bientôt. »
```

| Critère | Test |
|---|---|
| CA-1 | `student_homes_controller_test` « eleve-sans-prof CA-1 » ; `archived_classroom_reads_test` |
| CA-2 | `student_homes_controller_test` « eleve-sans-prof CA-2 » ; `student_audience_query_test` ; `daily_exercise_query_test` |
| CA-3 | `student_homes_controller_test` « eleve-sans-prof CA-3 » et « CA-D7 » ; `daily_exercise_query_test` « never had a classroom » |
| CA-4 | `student_homes_controller_test` « no published course at the student's level » |

## 5. Hors périmètre

Voir le memo.

## 6. Décisions

- [ADR-0035](../../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md), amendement du 2026-11-12 : le repli sur le dernier niveau connu. Aucun port, aucune table : une query existante change de règle.
- [UDR-0132](../../decisions/udr/0132-accueil-eleve-carte-du-prochain-exercice.md), amendement du 2026-11-12 : §3.3 état 6 et §3.4.
