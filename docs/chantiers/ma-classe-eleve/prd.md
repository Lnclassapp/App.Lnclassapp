# PRD — Page Ma classe de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

« Ma classe » (`/students/classroom`) prend la langue visuelle de l'accueil et de « Cours » : même en-tête et menu de l'avatar, carte de la classe en dégradé bleu, listes dans des cartes blanches. Le contenu ne change pas (cours assignés, exercices assignés, exercices traités), sauf une carte « Aucun enseignant sur Lnclass pour l'instant » avec « Inviter mon enseignant » quand la classe n'a aucun enseignant. Sur ordinateur, les deux listes d'exercices passent côte à côte.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir sa classe principale active, ses cours et exercices assignés, ses exercices traités ; inviter son enseignant si la classe n'en a aucun | Voir la liste, le nombre ou le travail des autres élèves (UDR-0011) ; voir la liste des enseignants |

Règles inchangées : `allow_roles :student`, `Policies::Classroom::ReadClassroomPolicy` ; sans classe principale active, redirection vers l'accueil.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Ma classe » depuis le menu de l'avatar (téléphone, tablette) ou le menu de gauche (ordinateur).
2. Il voit la carte de la classe : nom, niveau et série, établissement, année scolaire.
3. Puis « Cours assignés » (bande qui défile), « Exercices assignés » (ordre de « À faire », échéances en orange), « Exercices traités » (meilleur score, vert à partir de 14/20), chacune 3 lignes puis « Voir plus ».
4. Il ouvre un cours ou un exercice : les pages existantes s'ouvrent.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| La classe n'a aucun enseignant (`teacher_classrooms` vide) | Une carte « Aucun enseignant sur Lnclass pour l'instant » avec « Inviter mon enseignant » (même message WhatsApp que l'accueil, ADR-0089 §4.3), sous la carte de la classe. |
| La classe a au moins un enseignant | Pas de carte, aucune action sur la page. |
| Aucun cours ou exercice assigné | États vides actuels de chaque liste. |
| Plus de 3 lignes | « Voir plus » (`ui_reveal_more`). |
| Pas de classe principale active | Redirection vers l'accueil (inchangé). |
| ≥ 700 px | Colonne de 720 px ; la bande montre 2 cartes et demie. |
| ≥ 1 024 px | Menu de gauche ; la bande montre 4 cartes ; « Exercices assignés » et « Exercices traités » côte à côte. |
| Thème sombre | Tokens seulement. |
| App Android | Même page dans la coque. |

## 4. Critères d'acceptation

```gherkin
# CA-1 Navigation
Étant donné un élève sur un écran de 390 px
Quand il ouvre « Ma classe »
Alors la page n'a pas de lien « Accueil » au-dessus du titre ni de barre du bas
Et « Ma classe » est en surbrillance dans le menu de l'avatar

# CA-2 Carte de la classe
Alors la carte de la classe montre le nom, le niveau et la série, l'établissement et l'année scolaire
Et ne montre ni nombre ni liste d'élèves

# CA-3 Classe sans enseignant
Étant donné une classe sans enseignant sur Lnclass
Quand l'élève ouvre « Ma classe »
Alors il voit « Aucun enseignant sur Lnclass pour l'instant » et « Inviter mon enseignant »
Et le lien WhatsApp nomme sa classe, son établissement et le lien d'inscription enseignant

# CA-4 Classe avec enseignant
Étant donné une classe qui a un enseignant
Quand l'élève ouvre « Ma classe »
Alors la page n'a ni carte d'invitation ni aucune action
Et la liste des enseignants n'apparaît pas

# CA-5 Listes inchangées
Étant donné 5 exercices assignés non faits et 4 traités
Alors chaque liste en montre 3 puis « Voir plus »
Et l'ordre des exercices assignés est celui de « À faire » sur l'accueil

# CA-6 Couleurs des notes et échéances
Étant donné un exercice traité à 15/20 et un autre à 9/20
Alors 15/20 est en vert et 9/20 n'est ni vert ni rouge
Et une échéance en retard, aujourd'hui ou demain est en orange

# CA-7 Ordinateur
Étant donné un élève sur un écran de 1 280 px
Alors « Exercices assignés » et « Exercices traités » sont côte à côte
Et le menu de gauche montre « Ma classe » actif
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | `StudentClassroomQuery::Row` gagne `has_teacher` (un `EXISTS` sur `teacher_classrooms`). |
| Delivery | `Classroom::StudentClassroomsController` : inchangé. |
| UI | `classroom/student_classrooms/show` et ses partials redessinés ; `_no_teacher` (nouveau) qui rend `classroom/student_homes/_invite_teacher` (chantier `accueil-eleve`). |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni dépendance. `has_teacher` est un champ de lecture ajouté à une query, sur une table existante.
- [UDR-0086](../../decisions/udr/0086-page-ma-classe-eleve-redessinee-et-invitation-de-l-enseignant.md) : page Ma classe redessinée, carte « Aucun enseignant ».
- Dépend de [UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) et [ADR-0089](../../decisions/adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) §4.3 (message d'invitation), livrés par `accueil-eleve`.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de `GET /students/classroom` | 19 (Lot 0, hors SCHEMA ; 5 assignés, 4 traités) | ≤ avant + 1 | |
