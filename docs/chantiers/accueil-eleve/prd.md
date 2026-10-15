# PRD — Accueil élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'accueil de l'élève est redessiné : l'en-tête porte le logo, et un menu de l'avatar remplace la barre d'onglets du bas. Les blocs actuels (Ma classe, Mes matières, Annonces, À faire, Mes activités récentes) gardent leur ordre, en une colonne. Quand l'enseignant n'a rien donné, « À faire » propose un exercice du jour, une matière par jour à tour de rôle ; ce travail « fait seul » est compté à part chez l'enseignant et la direction, et l'élève peut inviter son enseignant par WhatsApp.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir son accueil, ouvrir le menu de l'avatar, commencer l'exercice du jour, partager l'invitation de son enseignant | Voir l'accueil ou le travail « fait seul » d'un autre élève |
| Teacher | Voir, dans la page d'une classe qu'il suit, le nombre d'exercices « faits seul » de chaque élève sur 7 jours | Voir ce chiffre pour une classe qu'il ne suit pas ; voir quels exercices précis ont été faits seul (hors périmètre) |
| Direction (SchoolStaff) | Voir, sur son accueil, le nombre d'exercices « faits seul » par niveau sur 7 jours, pour son établissement | Voir ce chiffre pour un autre établissement |

Règles d'autorisation inchangées :
- accueil élève : `allow_roles :student` (`Classroom::StudentHomesController`) ;
- démarrage de l'exercice : `Policies::Assessment::StartSessionPolicy` via `UseCases::Assessment::StartExerciseSession`, sans exigence d'assignation ;
- page de la classe : `ReadClassroomPolicy` (`show_roster`) ;
- accueil de la direction : le périmètre de `Queries::School::DirectionHomeQuery`.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève connecté ouvre `/students`. L'en-tête montre :
   - le logo Lnclass à gauche ;
   - à droite « Besoin d'aide ? » (sur tablette et ordinateur), le thème, puis l'avatar (photo, ou initiales sur une couleur stable avec un « + »).
2. Les blocs suivent l'ordre : Ma classe (« Entrer en classe »), Mes matières (4 par ligne au téléphone, 6 au-delà), Annonces, À faire (et les fiches à revoir), Mes activités récentes.
3. L'enseignant n'a rien donné : « À faire » montre l'exercice du jour (la matière du jour, le titre, « Commencer ») et, en dessous, « Inviter mon enseignant ».
4. L'élève commence l'exercice, le termine, revient à l'accueil : la carte dit « Bravo, à demain ! » et annonce la matière de demain.
5. L'enseignant de sa classe ouvre la page de la classe : la colonne « Fait seul (7 j) » de l'élève vaut 1, et les comptes « faits / en retard / pas encore faits » des exercices donnés n'ont pas bougé.
6. La direction voit, sur son accueil, le chiffre « Faits seul (7 j) » du niveau de l'élève augmenter de 1 (au plus 5 minutes après, à cause du cache).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Un travail de l'enseignant est à rendre ou en retard | « À faire » liste ce travail (en retard d'abord, puis par date limite) ; pas d'exercice du jour, pas de « Bravo ». |
| Aucune matière de l'élève n'a d'exercice publié non fait | La carte dit qu'il n'y a rien à proposer aujourd'hui et garde « Inviter mon enseignant ». |
| La matière du jour n'a plus d'exercice à faire | On prend la matière suivante dans le tour, le même jour. |
| L'élève est dans plusieurs classes | Le tour porte sur l'union des matières de ses classes, dans l'ordre de `SUBJECT_ORDER`. |
| Exercice du jour commencé à 23 h 50, terminé à 0 h 10 | Il compte pour le jour où il a été commencé (heure d'Abidjan). Le lendemain propose la matière suivante. |
| L'élève ouvre d'autres exercices depuis Mes matières | Autorisé ; ils comptent aussi comme « faits seul » s'ils ne sont pas donnés par l'enseignant. La carte du jour ne change pas. |
| L'élève n'a pas de classe | Comportement actuel (`_no_classroom`) inchangé, avec le nouvel en-tête. |
| L'élève n'a pas de photo | Initiales sur une couleur stable, « + » sur l'avatar, « Ajouter ma photo » dans le menu. |
| Téléphone ou tablette (< 1 024 px) | Pas de barre en bas ; Accueil, Cours, Ma classe en tête du menu de l'avatar, la page en cours en surbrillance. |
| Ordinateur (≥ 1 024 px) | Menu de gauche de 288 px, colonne de 960 px au plus ; le menu de l'avatar n'a pas Accueil/Cours/Ma classe. |
| App Android (`lnclass_app?`) | Rien ne change : pas d'en-tête web, onglets natifs, `/students/menu` sert toujours le panneau du compte. |
| Enseignant, direction ou équipe sur le web | Leur barre du bas et leur en-tête restent tels quels. |
| Thème sombre | Tous les blocs et les états de la carte suivent les tokens (UDR-0065). |

## 4. Critères d'acceptation

```gherkin
# CA-1 En-tête
Étant donné un élève connecté sur un écran de 390 px
Quand il ouvre son accueil
Alors l'en-tête montre le logo Lnclass, l'interrupteur de thème et son avatar
Et l'en-tête ne montre ni son nom ni « Besoin d'aide ? »
Et la page ne contient pas de barre d'onglets en bas

# CA-2 En-tête sur ordinateur
Étant donné un élève connecté sur un écran de 1 280 px
Quand il ouvre son accueil
Alors l'en-tête montre « Besoin d'aide ? » et le menu de gauche est visible

# CA-3 Menu de l'avatar au téléphone
Étant donné un élève sans photo de profil, sur un écran de 390 px
Quand il ouvre le menu de l'avatar
Alors il voit son nom et sa classe
Et les liens Accueil, Cours, Ma classe, l'accueil en surbrillance
Et « Mon profil », « Mon historique », « Ajouter ma photo », « Besoin d'aide ? » et « Se déconnecter », dans cet ordre

# CA-4 Avatar sans photo
Étant donné un élève sans photo nommé Koné Awa
Quand il ouvre son accueil
Alors l'avatar montre « KA » avec une pastille « + »
Et la couleur de l'avatar est la même à chaque visite

# CA-5 Les autres rôles gardent leur barre
Étant donné un enseignant connecté sur un écran de 390 px
Quand il ouvre son accueil
Alors sa barre d'onglets du bas est toujours présente

# CA-6 Ordre des blocs
Étant donné un élève avec une classe
Quand il ouvre son accueil
Alors les blocs apparaissent dans l'ordre : Ma classe, Mes matières, Annonces, À faire, Mes activités récentes
Et le bouton de Ma classe s'appelle « Entrer en classe »

# CA-7 Grille des matières
Étant donné un élève dont la classe a Physique-Chimie et Histoire-Géographie
Quand il ouvre son accueil
Alors la grille affiche « PC » et « HG »
Et leur nom complet est lu par les lecteurs d'écran

# CA-8 Exercice du jour proposé
Étant donné un élève sans travail donné par l'enseignant
Et le 2026-10-20 la matière du tour est les mathématiques
Et deux exercices de mathématiques publiés pour son niveau, dont il n'a fait aucun
Quand il ouvre son accueil le 2026-10-20
Alors « À faire » propose le premier de ces exercices
Et propose « Inviter mon enseignant »

# CA-9 Proposition stable dans la journée
Étant donné l'exercice du jour proposé à 8 h
Quand l'élève rouvre son accueil à 18 h le même jour sans l'avoir fait
Alors le même exercice est proposé

# CA-10 Bravo, à demain
Étant donné que l'élève a terminé l'exercice du jour
Quand il revient à son accueil le même jour
Alors la carte dit « Bravo, à demain ! » et nomme la matière de demain
Et aucun autre exercice du jour n'est proposé

# CA-11 Priorité stricte
Étant donné un élève qui a un exercice en retard donné par son enseignant
Quand il ouvre son accueil
Alors « À faire » montre l'exercice en retard en premier
Et aucun exercice du jour n'est proposé

# CA-12 Matière sautée
Étant donné que la matière du jour n'a aucun exercice publié non fait
Quand l'élève ouvre son accueil
Alors l'exercice proposé est celui de la matière suivante dans le tour

# CA-13 Rien à proposer
Étant donné qu'aucune matière de l'élève n'a d'exercice publié non fait
Quand il ouvre son accueil
Alors la carte dit qu'il n'y a rien à proposer aujourd'hui
Et propose « Inviter mon enseignant »

# CA-14 Minuit
Étant donné un exercice du jour commencé le 2026-10-20 à 23 h 50 et terminé le 2026-10-21 à 0 h 10
Quand l'élève ouvre son accueil le 2026-10-21
Alors la matière proposée est celle du tour du 2026-10-21
Et la session compte comme « fait seul » le 2026-10-20

# CA-15 Exercice donné jamais proposé
Étant donné un exercice donné à la classe de l'élève et pas encore fait
Quand le tour tombe sur sa matière
Alors l'exercice du jour n'est pas cet exercice

# CA-16 Fait seul chez l'enseignant
Étant donné un élève qui a terminé un exercice non donné il y a 3 jours
Quand l'enseignant de sa classe ouvre la page de la classe
Alors la colonne « Fait seul (7 j) » de l'élève vaut 1
Et les comptes « faits / en retard / pas encore faits » des exercices donnés sont inchangés

# CA-17 Fait seul chez la direction
Étant donné ce même élève en 6e
Quand la direction de son établissement ouvre son accueil
Alors le chiffre « Faits seul (7 j) » de la 6e compte cette session
Et la direction d'un autre établissement ne la compte pas

# CA-18 Inviter mon enseignant
Étant donné un élève de 6e A au Lycée Classique d'Abidjan
Quand il touche « Inviter mon enseignant »
Alors un lien WhatsApp s'ouvre avec un message qui nomme la 6e A, l'établissement et le lien d'inscription enseignant

# CA-19 App Android inchangée
Étant donné un élève dans l'app Android
Quand il ouvre son accueil
Alors la page n'a ni en-tête web ni barre du bas
Et /students/menu sert toujours le panneau du compte

# CA-20 Annonces masquées en place
Étant donné une annonce sur l'accueil
Quand l'élève la masque
Alors le bloc #student_home_announcements est remplacé sans recharger la page
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::DailyRotation` (Ruby pur) : choisit la matière du jour et celle de demain à partir de la date, de la liste ordonnée des matières et de celles qui ont un candidat. Aucun port, aucune table (ADR-0089). |
| Infrastructure | `Queries::Assessment::DailyExerciseQuery` : état `:proposed` / `:done_today` / `:none`, l'exercice, la matière de demain. `StudentHomeQuery` : retrait du calcul eager de `recent_sessions`. `ClassroomOverviewQuery` : `self_practice_count` par élève (7 j). `DirectionHomeQuery` : `self_practice_count` par niveau (7 j). Pas de migration. |
| Delivery | `Classroom::StudentHomesController#show` lit en plus `DailyExerciseQuery`. Pas de nouvelle route. |
| UI | Shell : barre du bas retirée pour l'élève seulement ; en-tête et menu de l'avatar (UDR-0084). Accueil : blocs redessinés, carte de l'exercice du jour, partial `_invite_teacher`. Helpers : `ui_avatar` avec badge « + » et couleur stable ; icône du casque d'aide. Page de la classe et accueil de la direction : colonne et chiffre « fait seul ». |

## 6. Décisions rattachées

- [ADR-0089](../../decisions/adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) : exercice du jour calculé à la lecture, « fait seul » déduit d'une session sans assignation, invitation de l'enseignant.
- [UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) : en-tête, menu de l'avatar, pas de barre du bas pour l'élève, blocs de l'accueil, carte de l'exercice du jour, chiffres « fait seul ».

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de `GET /students` (élève avec classe) | à mesurer au Lot 0 | ≤ avant (le retrait de `recent_sessions` compense la query du jour) | |
| Élèves actifs sans enseignant qui font ≥ 1 exercice par semaine | 0 (rien à faire) | à suivre 4 semaines après la sortie | |
