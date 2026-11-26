# PRD — Accueil enseignant tourné vers l'action

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'accueil de l'enseignant cache la classe en retard dans un carrousel, des ronds muets et une section vide ; ses pages intérieures répètent la barre du haut ; la liste d'une classe répète la même ligne quarante fois ; le suivi d'un devoir demande une relance sans moyen de la faire. Le chantier met en tête ce qui est à suivre, nomme les ronds, retire le vide et la barre en double, résume la liste par l'état de chaque élève et ajoute « Relancer sur WhatsApp » ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher | voir « À suivre » de ses classes de l'établissement courant ; copier le code depuis la page de la classe ; ouvrir WhatsApp avec un message prérempli de relance | voir les classes d'un autre établissement ou d'un autre enseignant (inchangé) |
| Team | page de la classe et suivi comme avant ; voit le code de la classe dans le bloc du lien, comme l'enseignant | relancer (le bouton est réservé à l'enseignant) ; rien d'autre ne change pour lui, barre du haut comprise |
| Student, SchoolStaff, Parent | rien ne change | — |

Règles d'autorisation inchangées : `allow_roles :teacher` de l'accueil, `ReadClassroomPolicy` (page de la classe et liste nominative), `FollowAssignmentPolicy` (suivi), `link_shown_to?` pour le bloc du lien (le code suit la même condition).

## 3. Parcours utilisateur

### Chemin nominal

1. L'enseignant ouvre l'accueil : la barre du haut (sur ordinateur) ou le bandeau (téléphone), puis « À suivre » : « Tle D · 38 élèves en retard sur 1 exercice ›, 1ère D · 4 exercices en cours › », puis « Voir mes 12 autres classes ».
2. Plus bas, « Fiches de cours · Mathématiques », une rangée de ronds colorés « 6e », « 2de A », « Tle D », puis « Inviter ».
3. Il touche « Tle D » : la page de la classe, sans barre du haut, avec « ‹ Accueil » en tête ; le bloc « Inscrire vos élèves » porte le code et « Copier ».
4. La liste des élèves dit « 38 en retard · 2 à jour », puis dix lignes, les élèves en retard d'abord, « Voir plus (30) ».
5. Il ouvre le devoir : « Prochain geste » « Relancez les 38 élèves… » et le bouton « Relancer sur WhatsApp », qui ouvre WhatsApp avec « Tle D : pensez au devoir « … », à rendre le … Ouvrez-le ici : <lien> ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucune classe | La carte « Ajoutez vos classes » (inchangée), pas de liste |
| Des classes, aucune à suivre | Liste « Mes classes » : les classes, trois puis « Voir mes N autres classes » |
| Toutes à suivre | Pas de « Voir mes autres classes » |
| Classe sans élève | Jamais « à suivre » |
| Aucun exercice cette semaine | Section « Cette semaine » absente |
| Sans matière | L'invitation « Choisissez vos matières » (inchangée) |
| Page intérieure enseignant | Ni barre du haut ni bas ; « ‹ Accueil » ou un retour en tête |
| Plus personne à relancer | Pas de bouton « Relancer sur WhatsApp » |
| Personne n'a encore fait le devoir | Le bouton est dans l'état vide du rapport |
| Recherche ou filtre de médaille sans résultat | États existants (inchangés) ; les deux chiffres restent ceux de la classe |

## 4. Critères d'acceptation

```gherkin
# CA-1 À suivre
Étant donné un enseignant dont la Tle D a 2 élèves sur 3 en retard sur 1 devoir échu, la 1ère D 2 devoirs à venir et la 6e 1 aucun devoir
Quand il ouvre l'accueil
Alors « À suivre » montre la Tle D puis la 1ère D, chacune un lien vers sa classe
Et la Tle D dit « 2 élèves en retard sur 1 exercice », la 1ère D « 2 exercices en cours »
Et la 6e 1 n'y est pas, mais « Voir mon autre classe » la montre
Et le carrousel des classes n'existe plus

# CA-2 Rien à suivre
Étant donné un enseignant dont aucune classe n'a de devoir
Quand il ouvre l'accueil
Alors la liste s'intitule « Mes classes » et montre ses classes

# CA-3 Aucune classe
Étant donné un enseignant sans classe
Quand il ouvre l'accueil
Alors il voit « Ajoutez vos classes » et aucune liste

# CA-4 Ronds nommés
Étant donné un enseignant de mathématiques de 6e et de Tle D
Quand il ouvre l'accueil
Alors le titre « Fiches de cours · Mathématiques » est visible au-dessus des ronds
Et le rond de la 6e affiche « 6e », celui de la Tle D « Tle D », de deux teintes différentes, sans illustration de matière
Et le rond « Inviter » garde son illustration

# CA-5 Pas de section vide
Étant donné un enseignant sans devoir cette semaine
Quand il ouvre l'accueil
Alors la section « Cette semaine » n'est pas rendue

# CA-6 Barre du haut sur l'accueil seulement
Étant donné un enseignant connecté
Quand il ouvre la page d'une classe, le suivi d'un devoir, la fiche d'un élève, « Cours », « Mes classes », « Reçues », « Mes annonces » ou son profil
Alors l'en-tête du site n'est pas rendu et un lien de retour est en tête de page
Et sur l'accueil l'en-tête est rendu
Et pour la direction, l'équipe et l'élève, l'en-tête ne change pas

# CA-7 Code de la classe sur la page de la classe
Étant donné un enseignant de la Tle D
Quand il ouvre la page de la classe
Alors le bloc « Inscrire vos élèves » montre le code de la classe et le bouton « Copier »

# CA-8 Liste par état
Étant donné une classe de 12 élèves dont 11 en retard
Quand l'enseignant ouvre la page de la classe
Alors la liste dit « 11 en retard » et « 1 à jour »
Et les élèves en retard viennent d'abord, chaque ligne dit « En retard » ou « À jour », sans « faits sur » ni médaille
Et dix lignes sont rendues, puis « Voir plus (2) »
Et la recherche et les filtres par médaille restent

# CA-9 Relancer sur WhatsApp
Étant donné un devoir échu de la Tle D que 2 élèves sur 3 n'ont pas fait
Quand l'enseignant ouvre son suivi
Alors « Relancer sur WhatsApp » ouvre wa.me avec un message qui nomme la classe, le devoir, son échéance et le lien de l'exercice, sans nom d'élève
Et quand tous l'ont fait, le bouton n'est pas rendu
Et l'équipe ne voit pas le bouton
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::LevelShortName` (nom court d'un niveau) ; `Entities::Classroom::FollowUpPriority` (classe à suivre ? rang d'urgence) |
| Infrastructure | `TeacherHomeQuery` : `late_students_count`, `late_assignments_count` par classe ; `ClassroomOverviewQuery` : retard d'abord, `late_total` / `up_to_date_total`, `PER_PAGE` 10 |
| Delivery | aucune route nouvelle ; `TeacherHomesController` inchangé |
| UI | accueil (`_to_follow`, ronds texte, sans section vide), shell (en-tête enseignant sur l'accueil seulement), `_link` (code), `_roster`, `_section` (relance), retours manquants |

## 6. Décisions rattachées

- Pas d'ADR : aucun port, aucune table, aucun contrat nouveau ; deux lectures existantes gagnent des champs.
- UDR-XXXX-accueil-enseignant-actions — accueil « À suivre », ronds nommés, barre du haut sur l'accueil seulement (amende UDR-0006, UDR-0082 §3.1, UDR-0134 §3.3, §3.5, §3.8, §3.14), liste des élèves par état, relance WhatsApp.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Gestes pour voir la classe en retard (jeu standard, 14 classes) | jusqu'à 13 glissements | 0 | |
| Lignes de la liste au premier écran (Tle D, 40 élèves) | 30 | 10 | |
