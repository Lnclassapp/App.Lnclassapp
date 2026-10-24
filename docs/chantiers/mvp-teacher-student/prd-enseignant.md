# PRD — MVP Lnclass Teacher & Student — pilote du 27 octobre — **enseignant**

> Suite du [PRD élève](prd.md), même chantier. Mêmes règles : specs figées ici, le détail des écrans est dans l'[UDR enseignant](../../decisions/udr/XXXX-ecrans-enseignant-sans-repetition.md) (accepté le 2026-10-23, versions ordinateur ajoutées le 2026-10-24). Sur un écran, l'UDR gagne ; sur un comportement, ce PRD gagne.
>
> Repris des critères enseignant de la version `c766532` du PRD, recalés sur ce qui est déjà livré sur la branche de chantier. Numéros conservés ; l'ancien CA-B5 (code sur la carte de l'accueil) devient **CA-B8**, le numéro CA-B5 étant pris par le PRD élève.

## 1. Contexte

Le pilote du 27 octobre accueille aussi des enseignants. Côté enseignant, le chantier ne construit rien de neuf : il réordonne l'existant autour de « ce que mes élèves ont fait », applique la règle de l'élève (« une information, une place »), range les élèves par badge, met la couleur jaune du rôle, et simplifie l'inscription et le premier parcours (déclarer ses classes, assigner, jours de séance). Le périmètre est dans [`perimetre.md`](perimetre.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Enseignant** | Déclarer ses classes ; montrer et copier le code et le lien de ses classes, les changer ; assigner un exercice ; lire le rapport d'un exercice, la liste et la fiche de ses élèves ; retirer un élève ; ajouter ou retirer une matière (1 à 3) et un établissement (1 à 3) ; inviter un collègue | Voir le code ou les élèves d'une classe qui n'est pas la sienne ; retirer sa dernière matière ou son dernier établissement ; écrire une annonce (fermé pendant le pilote) |
| **Direction, Équipe** | Inchangés, hors recette ; voient le même rapport d'exercice | — |

Règles d'autorisation applicables, toutes existantes : `ReadClassroomPolicy` (page de classe, liste, fiche, rapport), `ManageClassroomMembersPolicy` (changer le lien et le code, retirer un élève), `ManageOwnMaterialsPolicy` (matières), `LeaveSchoolPolicy` et `JoinSchoolWithCodePolicy` (établissements). Aucune policy nouvelle.

## 3. Parcours utilisateur

### Chemin nominal — enseignant

1. Il ouvre le lien d'invitation : l'inscription s'ouvre à l'étape 2/3, établissement prérempli ; il donne nom, genre, numéro, une matière, puis son code secret.
2. Sur l'accueil, il touche « + Ajouter une classe » et déclare ses classes.
3. La carte de la classe montre son code : il le copie ou le dicte ; ou il partage le lien sur WhatsApp depuis la page de classe.
4. Il touche le rond de son niveau, ouvre une fiche, touche « Assigner » ; la première fois, il coche les jours où il voit la classe, et l'exercice est à rendre à la prochaine séance.
5. Dans « Cette semaine », il suit « 20 / 27 faits » ; il ouvre le rapport, voit les élèves rangés par badge et le prochain geste.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| L'enseignant change le lien | Le code change avec lui (un seul geste) ; l'ancien lien et l'ancien code ne mènent plus à la classe |
| Enseignant à 3 matières ou 3 établissements | L'entrée du menu passe en gris et ouvre l'écran de retrait ; la dernière matière et le dernier établissement n'ont pas de bouton « Retirer » |
| Classe sans jours de séance | La fenêtre des jours s'ouvre au premier « Assigner », sans « Plus tard » |
| Enseignant sans classe | L'accueil ne montre que la carte « Ajoutez vos classes » |
| Enseignant de plusieurs établissements | L'accueil et les classes ne montrent que l'établissement courant (UDR-0098) |

## 4. Critères d'acceptation

### Déjà livrés (branche de chantier, PR #295)

| Critère | Livré par | Preuve |
|---|---|---|
| CA-B6 — « Changer le lien et le code » change les deux, journalisé, l'ancien code répond comme inconnu | ancien Lot A (`d100921f`) | `test/domain/use_cases/classroom/change_classroom_link_test.rb` |
| CA-G3 — badge de classe d'un élève (Diamant, Or, Argent, Bronze, Pas encore), chaque élève une fois | Lot 0 (`2cff88eb`, `Grading.class_badge_for`) | `test/domain/entities/assessment/grading_test.rb` ; l'affichage est dans G, I, K |
| CA-K1 — aucun écran ne propose à l'enseignant d'écrire une annonce | `cabe5e7f` (drapeau `TEACHER_ANNOUNCEMENTS_ENABLED`, éteint) | `test/config/pilot_flags_test.rb` |

### B. Code de classe, côté enseignant

```gherkin
# CA-B8
Étant donné un enseignant de la classe sur son accueil
Alors la carte de la classe montre son code et un bouton « Copier »
Et un enseignant d'une autre classe ne voit pas ce code
Et la ligne provisoire du code sur la page de classe (CA-B7) a disparu
```

### G. Accueil enseignant

```gherkin
# CA-G1
Étant donné un enseignant connecté sur un téléphone
Alors l'accueil montre, dans l'ordre : le bandeau jaune, le carrousel de ses classes, les ronds de niveau puis « Inviter », les annonces, « Cette semaine », l'Historique
Et il n'y a ni barre basse, ni « Bonjour, <prénom> », ni titre de section visible

# CA-G2
Étant donné une classe de 20 élèves (6 Bronze, 5 Argent, 3 Or, 1 Diamant, 5 Pas encore) et 2 exercices actifs
Alors sa carte montre « TLE D 1 · <sigle> › », « 20 élèves », « 2 exercices en cours », les pastilles Bronze 6, Argent 5, Or 3, Diamant 1, le code et « Copier »
Et aucune pastille « Pas encore » ni badge à zéro

# CA-G3
Étant donné le badge d'un élève dans une classe
Alors il vaut Diamant si tous ses exercices faits sont sans faute, sinon Or, Argent ou Bronze selon sa moyenne et les seuils de Grading, sinon « Pas encore »
Et chaque élève compte une seule fois

# CA-G4
Étant donné le carrousel des classes
Alors sa dernière carte est « + Ajouter une classe », qui mène à la déclaration des classes
Et un enseignant sans classe ne voit que cette carte

# CA-G5
Étant donné un rond de niveau « Tle D »
Quand l'enseignant le touche
Alors Cours s'ouvre filtré sur Tle D, titré « Cours de Tle D », sans menus Niveau ni Série

# CA-G6
Étant donné une assignation à rendre dans 3 jours, faite par 20 élèves sur 27
Alors elle est dans « Cette semaine » avec « 20 / 27 faits » et la pastille « 7 pas encore »
Et la même assignation échue depuis 2 jours porte « 7 en retard »

# CA-G7
Étant donné une assignation échue faite par tous, et une autre échue depuis plus de 14 jours
Alors les deux sont dans l'Historique, groupées par jour d'échéance, avec la moyenne de la classe
Et aucune assignation n'apparaît à la fois dans « Cette semaine » et dans l'Historique

# CA-G8
Étant donné plus de 3 lignes dans « Cette semaine » ou dans l'Historique
Alors 3 lignes s'affichent, puis le lien discret « Voir plus » qui révèle les suivantes

# CA-G9
Étant donné un écran enseignant
Alors le bandeau, les barres de progression et les segments d'étape sont jaune enseignant, les boutons et les liens bleus
Et aucune vue n'écrit bg-teacher en dur : la couleur vient du helper de rôle

# CA-G10
Étant donné un enseignant sur ordinateur (≥ lg)
Alors l'accueil est en page large, à côté de la barre latérale Accueil · Mes classes · Cours, selon la version ordinateur de l'UDR enseignant §3.3
Et rien n'est ajouté ni retiré par rapport au téléphone
```

### H. Menu « Mon compte » enseignant

```gherkin
# CA-H1
Étant donné un enseignant qui touche son avatar
Alors un panneau plein écran montre son nom, « Math · PC · <sigle> », puis Mon profil, Modifier mon code secret, Ajouter une matière (« 2 sur 3 »), Ajouter un établissement (« N sur 3 »), Mode sombre, Se déconnecter
Et « Inviter un collègue » n'y figure pas
Et sur ordinateur (≥ lg), le même contenu s'ouvre en panneau latéral droit de 400 px

# CA-H2
Étant donné un enseignant de deux établissements
Alors le panneau montre « Établissement en cours » avec les deux, et en toucher un change l'établissement courant

# CA-H3
Étant donné un enseignant qui a 3 matières
Alors « Ajouter une matière » est grisé avec « 3 sur 3 · retire-en un pour en ajouter »
Et il ouvre l'écran « Mes matières », où « Retirer » retire la matière sans toucher aux exercices déjà assignés

# CA-H4
Étant donné un enseignant à 3 établissements qui retire l'un d'eux et confirme
Alors ses classes et devoirs actifs de cet établissement sont archivés, et le compteur passe à « 2 sur 3 »

# CA-H5
Étant donné un enseignant qui n'a qu'une matière, ou qu'un établissement
Alors l'écran de retrait ne montre aucun bouton « Retirer » pour lui
Et une requête de retrait forgée est refusée par le serveur

# CA-H6
Étant donné le profil d'un enseignant
Alors la ligne Matières n'a plus d'action « Modifier »
```

### I. Classe, fiche d'un élève, rapport

```gherkin
# CA-I1
Étant donné la page d'une classe vue par son enseignant
Alors elle montre « Inscrire vos élèves » avec « Partager sur WhatsApp » et « Copier le lien », les exercices assignés au format « Cette semaine », les fiches à revoir, « 20 élèves » sans « sur 80 »
Et ni la ligne provisoire du code (CA-B7, retirée quand l'accueil porte le code), ni « Vos jours de séance »
Et sur ordinateur (≥ lg), la page est en deux colonnes égales (UDR enseignant §3.5)

# CA-I2
Étant donné le filtre « Or » de la liste des élèves
Alors seuls les élèves dont le badge de classe est Or s'affichent
Et le filtre « Pas encore » montre ceux sans badge

# CA-I3
Étant donné la fiche d'un élève
Alors elle montre son numéro masqué, « Arrivé·e le <date> », « 9 faits sur 18 », la pastille « Moyenne 14/20 · Or » et ses badges nommés
Et ni « Fragile » ni « Acquis »

# CA-I4
Étant donné le rapport d'un exercice fait par 20 élèves sur 27
Alors il montre « 20 / 27 faits », « 7 en retard » si échu, et cinq cases Pas encore · Bronze · Argent · Or · Diamant
Et toucher une case filtre la liste des élèves sur ce badge
Et sur ordinateur (≥ lg), le rapport est en deux colonnes égales (UDR enseignant §3.8)

# CA-I5
Étant donné le prochain geste du rapport
Alors son texte parle en badges, jamais en « En difficulté », « Fragile » ou « Acquis »
```

### J. Inscription enseignant

```gherkin
# CA-J1
Étant donné un enseignant qui ouvre l'inscription sans lien
Alors il voit « Étape 1 sur 3 » (Votre établissement), puis passe seul à l'étape 2 quand l'établissement est choisi

# CA-J2
Étant donné un lien d'invitation valide
Alors l'inscription s'ouvre à l'étape 2 avec « Votre établissement : <nom> » et « Ce n'est pas votre établissement ? › »

# CA-J3
Étant donné l'étape 2
Alors elle demande une seule matière, avec l'aide « Vous pourrez ajouter d'autres matières dans Mon compte. »
Et le champ « Autre matière (facultatif) » n'existe plus, ni dans le formulaire ni dans le DTO

# CA-J4
Étant donné l'étape 3 remplie
Quand l'enseignant touche « Créer mon compte »
Alors son compte est créé avec une matière dans l'établissement choisi, et il arrive sur l'accueil
```

### L. Premier parcours enseignant : déclarer, assigner, jours de séance

```gherkin
# CA-L1
Étant donné un enseignant sans classe
Alors la carte du haut de l'accueil dit « Ajoutez vos classes » avec le bouton « + Ajouter une classe »
Et le bouton mène à « Quelles classes enseignez-vous ? », où cocher une classe l'ajoute et met le compteur à jour

# CA-L2
Étant donné une fiche avec trois exercices et deux classes enseignées du niveau
Alors chaque exercice montre une ligne par classe, « Assigner » ou « ✓ Assigné » avec la date de rendu
Et seul le premier « Assigner » de la page est un bouton plein

# CA-L3
Étant donné une classe sans jours de séance
Quand l'enseignant touche « Assigner »
Alors la fenêtre « Quels jours voyez-vous la <classe> ? » s'ouvre, sans « Plus tard »
Et sans jour coché, « Assigner » est refusé avec l'erreur sous les jours
Et avec lundi coché, l'exercice est assigné, à rendre à la prochaine séance

# CA-L4
Étant donné une classe qui a déjà des jours de séance et un exercice assigné
Quand l'enseignant touche « Modifier les jours de la <classe> » sur la fiche
Alors la fenêtre des jours s'ouvre avec ses jours cochés, et « Enregistrer » les remplace
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `RegisterTeacher` et `TeacherRegistrationInput` perdent `second_material_slug` ; `AssignmentInput` perd `later` |
| Infrastructure | `TeacherHomeQuery` (sigle, code, compteurs de badges) ; `TeacherFollowUpsQuery` partagée en « cette semaine » et « historique » ; badge par élève et filtre `badge=` dans la liste de classe, la fiche et le rapport |
| Delivery | écrans de retrait (matières, établissements) ; compteurs « N sur 3 » du menu ; `Cours` filtré par `level` et `series` |
| UI | accueil (carrousel, niveaux, Cette semaine, Historique) ; « Mon compte » plein écran ; classe, fiche, rapport en badges ; Cours de l'enseignant ; inscription en 3 étapes (`signup_steps_controller.js` de l'élève, réutilisé) ; premier parcours |

## 6. Décisions rattachées

- UDR-XXXX — [Écrans enseignant sans répétition](../../decisions/udr/XXXX-ecrans-enseignant-sans-repetition.md)
- UDR-XXXX — [Palette froide et texte sans gras](../../decisions/udr/XXXX-palette-froide-et-texte-sans-gras.md) (exception de rôle : jaune enseignant)
- ADR-XXXX — [Code de classe à six caractères](../../decisions/adr/XXXX-code-de-classe-a-six-caracteres.md)
- ADR-0103 — amendé par l'UDR enseignant (une seule matière à l'inscription)
- ADR-0072 — échéance par les jours de séance

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Enseignants inscrits qui assignent un exercice dans les 48 h | non mesuré | ≥ 50 % | |
| Enseignants qui ouvrent un rapport après une assignation | non mesuré | à observer | |
