# PRD — Organisation des écrans élève : accueil, « Ma classe » et rythme d'une session

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'accueil de l'élève suit désormais l'ordre classe, matières, annonces, à faire, activités récentes. « Ma classe » montre les cours de son travail en carrousel, ses exercices assignés et ses exercices traités avec son meilleur score. Une session d'exercice ne coûte plus qu'un aller-retour par question, sans aucun cache (ADR-0076).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir son accueil et « Ma classe » (sa classe principale active) ; jouer ses sessions | voir le travail, le score ou le nom d'un autre élève |
| Teacher, Team, SchoolStaff | — | ouvrir `/students`, `/students/classroom` (403) ou jouer une session (403) |
| Parent | — (rôle absent de l'application) | — |

Règles inchangées : `allow_roles :student`, `ReadClassroomPolicy` pour « Ma classe », `SubmitAttemptPolicy` et `ReadSessionPolicy` pour la session. Tout ce que l'élève voit est filtré sur son niveau (UDR-0013, amendement du 2026-10-01).

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre l'accueil : « Ma classe », « Mes matières », les annonces, « À faire » (et les fiches à revoir), « Mes activités récentes ».
2. Il touche une matière : le catalogue s'ouvre, filtré sur cette matière (et sur son niveau).
3. Il ouvre « Ma classe » : la classe et son code, les cours de son travail en carrousel, 3 exercices assignés puis « Voir plus », 3 exercices traités avec son meilleur score puis « Voir plus ».
4. Il joue une session : il répond, voit le verdict ; « Question suivante » affiche la question suivante tout de suite, sans requête.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucune matière au niveau de l'élève | « Mes matières » montre un état vide et « Tous les cours » |
| Aucune annonce lisible | pas de carrousel (UDR-0071 §3.5, inchangé) |
| Aucun cours dans le travail de la classe | état vide dans la section « Cours assignés » |
| Aucun exercice assigné restant | état vide « Rien à faire pour l'instant » |
| Aucun exercice traité | état vide |
| Sans JavaScript | « Question suivante » est un lien vers la session, comme avant |
| Question déjà répondue ailleurs | refus sans écriture, toast et retour à l'état réel (inchangé) |
| Élève sans classe principale active | redirection unique vers l'écran de sortie (inchangé) |

## 4. Critères d'acceptation

```gherkin
# CA-1 — ordre de l'accueil
Étant donné un élève avec une classe, une matière, une annonce, un exercice assigné
Quand il ouvre /students
Alors les sections se suivent : « Ma classe », « Mes matières », annonces, « À faire », « Mes activités récentes »
Et la carte « Cours » n'existe plus

# CA-2 — matières
Étant donné des cours publiés de SVT et de Maths au niveau de l'élève, et de Français à un autre niveau
Quand il ouvre /students
Alors « Mes matières » montre une bulle Maths puis une bulle SVT, chacune vers le catalogue filtré sur sa matière
Et aucune bulle Français

# CA-3 — retard
Étant donné un exercice de SVT assigné, non fait, dont l'échéance est passée
Quand l'élève ouvre /students
Alors la bulle SVT porte une pastille et son nom accessible dit « exercice en retard »
Et la bulle Maths n'en porte pas

# CA-4 — cours assignés en carrousel
Étant donné deux exercices assignés à la classe, dans deux cours publiés du niveau
Quand l'élève ouvre /students/classroom
Alors « Cours assignés » montre une bande défilante de deux cartes, chacune vers la page du cours
Et un cours sans exercice assigné n'y est pas

# CA-5 — exercices assignés
Étant donné quatre exercices assignés non faits et un exercice assigné déjà fait
Quand l'élève ouvre /students/classroom
Alors « Exercices assignés » montre 3 lignes visibles, une masquée et « Voir plus »
Et l'exercice déjà fait n'y est pas

# CA-6 — exercices traités
Étant donné quatre exercices terminés, l'un deux fois (40 % puis 80 %)
Quand l'élève ouvre /students/classroom
Alors « Exercices traités » montre 3 lignes visibles puis « Voir plus », la plus récente d'abord
Et la ligne de l'exercice refait dit 16/20 et ouvre le résultat de sa dernière session
Et aucun score d'un autre élève n'apparaît

# CA-7 — un aller-retour par question
Étant donné une session de deux questions
Quand l'élève répond à la première
Alors la réponse du serveur contient le verdict et la deuxième question, sans aucune proposition correcte
Et « Question suivante » affiche la deuxième question sans requête au serveur
Et sans JavaScript, « Question suivante » reste un lien vers la session

# CA-8 — politique de cache
Étant donné les pages /students, /students/classroom, /sessions/:id et le stream d'une réponse
Alors aucune ne pose d'ETag ni de Cache-Control public, et aucune vue ne contient de cache de fragment
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien : aucune règle nouvelle, aucun port |
| Infrastructure | `StudentHomeQuery` : `subjects` (matières du niveau) et `assigned_exercises` public ; `StudentClassroomQuery` : `courses`, `assigned_exercises`, `treated_exercises` |
| Delivery | aucune route ; `StudentHomesController` et `StudentClassroomsController` inchangés dans leur forme |
| UI | `student_homes/show` (ordre), `_subjects` (nouveau) ; `student_classrooms/show`, `_course_card`, `_assigned_exercise`, `_treated_exercise` (nouveaux) ; `assessment/question_attempts/create`, `_feedback_card` ; Stimulus `assessment/next_question` |

## 6. Décisions rattachées

- Pas d'ADR : aucun port, aucune table, aucun contrat, aucun cache. Le chantier applique l'[ADR-0076](../../decisions/adr/0076-politique-de-cache-reglee-sur-les-allers-retours.md) (moins de requêtes en série, jamais de HTML en cache) et l'[ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) (nombre fixe de requêtes).
- [UDR-0076](../../decisions/udr/0076-organisation-des-ecrans-eleve.md) — ordre de l'accueil, « Ma classe », question suivante sans requête. Amende UDR-0058 §3.3, UDR-0011, UDR-0022 §2.1.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes en série par question d'une session (réponse → question suivante) | 2 | 1 | voir journal |
| Requêtes SQL de `/students` | voir journal | +1 au plus (matières), constant | voir journal |
| Requêtes SQL de `/students/classroom` | voir journal | nombre fixe, quel que soit le volume | voir journal |
| Requêtes en série pour ouvrir `/students/classroom` | 1 | 1 (aucun frame différé) | voir journal |
