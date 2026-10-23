# PRD — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Le détail des écrans est dans les UDR (§6) : ce PRD dit **ce qui doit être vrai**, les UDR disent **comment c'est dessiné**. En cas d'écart sur un écran, l'UDR gagne ; sur un comportement, ce PRD gagne.

## 1. Contexte

Le pilote du mardi 27 octobre (test fermé Google Play, contacts du porteur) ouvre l'app à des élèves et des enseignants qui la découvrent : elle compte plus de cent fonctionnalités et ne dit pas par où commencer. Le chantier choisit ce qu'on garde, masque ou reporte ([`perimetre.md`](perimetre.md)), construit trois choses (accueil élève « carte du prochain exercice », code de classe à 6 caractères, page d'accueil publique en photo), et retire les répétitions de chaque écran élève et enseignant. Aucune autre nouveauté n'entre avant le 27.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Visiteur** (non connecté) | Voir la page d'accueil publique ; ouvrir les fenêtres « Je suis élève » et « Enseignant(e) » ; vérifier un code de classe (aperçu : classe, niveau, établissement) ; s'inscrire | Voir « Espace établissement » avant le 2 novembre ; apprendre d'un code autre chose que l'aperçu ; dépasser 10 vérifications ou envois par minute et par IP |
| **Élève** | Rejoindre une classe par code, lien ou cascade ; faire ses exercices et l'exercice du jour ; lire cours, fiches à revoir, annonces de l'équipe et de la direction, son historique ; gérer son profil et son code secret | Changer de classe (masqué) ; voir une autre classe que la sienne ; lire les annonces d'un enseignant (masquées) |
| **Enseignant** | Déclarer ses classes ; montrer et copier le code et le lien de ses classes, les changer ; assigner un exercice ; lire le rapport d'un exercice, la liste et la fiche de ses élèves ; retirer un élève ; ajouter ou retirer une matière (1 à 3) et un établissement (1 à 3) ; inviter un collègue | Voir le code ou les élèves d'une classe qui n'est pas la sienne ; retirer sa dernière matière ou son dernier établissement ; écrire une annonce (masqué) |
| **Direction, Équipe** | Inchangés, hors recette | — |

Règles d'autorisation applicables, toutes existantes : `ReadClassroomPolicy` (page de classe, liste, fiche, rapport), `ManageClassroomMembersPolicy` (changer le lien et le code, retirer un élève), `ManageOwnMaterialsPolicy` (matières), `LeaveSchoolPolicy` et `JoinSchoolWithCodePolicy` (établissements), compteur de débit `classroom/joins` (lien, code, inscription). Aucune policy nouvelle.

## 3. Parcours utilisateur

### Chemin nominal — élève

1. Il reçoit le lien de classe sur WhatsApp, l'ouvre : l'inscription s'ouvre à l'étape 2/3, « Ta classe : 3e B · <établissement> » en tête.
2. Il tape nom, prénoms, genre, numéro : il passe seul à l'étape 3 ; il choisit son code secret et touche « Créer mon compte ».
3. L'accueil s'ouvre : la carte du haut montre l'exercice le plus urgent et un seul bouton.
4. Il fait l'exercice, voit sa note sur 20, son badge et un seul bouton « Recommencer ».
5. De retour à l'accueil, l'exercice est dans l'Historique, et la carte montre le suivant.

### Chemin nominal — enseignant

1. Il ouvre le lien d'invitation : l'inscription s'ouvre à l'étape 2/3, établissement prérempli ; il donne nom, genre, numéro, une matière, puis son code secret.
2. Sur l'accueil, il touche « + Ajouter une classe » et déclare ses classes.
3. La carte de la classe montre son code : il le copie ou le dicte ; ou il partage le lien sur WhatsApp depuis la page de classe.
4. Il touche le rond de son niveau, ouvre une fiche, touche « Assigner » ; la première fois, il coche les jours où il voit la classe, et l'exercice est à rendre à la prochaine séance.
5. Dans « Cette semaine », il suit « 20 / 27 faits » ; il ouvre le rapport, voit les élèves rangés par badge et le prochain geste.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Élève sans lien, avec le code au tableau | Étape 1/3, il tape le code : au 6ᵉ caractère, vérification, puis étape 2 avec le rappel de classe |
| Code inconnu, ou classe archivée | Même message sous le champ, sans dire laquelle des deux ; l'élève reste à l'étape 1 |
| Plus de 10 essais par minute (lien, code, envoi) | 429, « Trop d'essais. Attends une minute, ou coche « Je n'ai pas de code ». » |
| Élève sans code ni lien | « Je n'ai pas de code » déplie la cascade DRENA → établissement → niveau → classe ; toucher une classe passe à l'étape 2 |
| Classe complète | Tuile désactivée dans la cascade ; par code ou lien, refus comme aujourd'hui |
| Lien de classe invalide, archivé ou régénéré | L'inscription s'ouvre à l'étape 1/3, jamais sur une erreur |
| Erreur serveur sur un champ à l'envoi | La page rouvre la première étape qui contient un champ en erreur, saisies gardées |
| Élève connecté sans classe | Carte « Choisis ta classe » avec le champ code ; grille, annonces et historique masqués |
| Classe sans exercice assigné | Carte « Exercice du jour » et « Ton enseignant n'est pas sur Lnclass ? Invite-le › » |
| Tout l'assigné est fait | Fiche à revoir la plus ancienne s'il y en a, sinon « Tout est fait ! » avec l'exercice du jour |
| L'enseignant change le lien | Le code change avec lui (un seul geste) ; l'ancien lien et l'ancien code ne mènent plus à la classe |
| Enseignant à 3 matières ou 3 établissements | L'entrée du menu passe en gris et ouvre l'écran de retrait ; la dernière matière et le dernier établissement n'ont pas de bouton « Retirer » |
| Collégien de moins de 13 ans sans compte Google | Il passe par la version web (PWA) ; rien à construire |

## 4. Critères d'acceptation

Chaque critère devient au moins un test ; le plan (`plan.md`) dit lequel. Les numéros servent de référence dans les tests et les lots.

### A. Page d'accueil publique

```gherkin
# CA-A1
Étant donné un visiteur sur un téléphone de 390 px
Quand il ouvre /
Alors il voit la photo plein écran, la feuille « Tu comprends chap chap » et les entrées « Je suis élève » et « Enseignant(e) »
Et la page tient sur un écran, sans défilement, y compris à 320 × 568

# CA-A2
Étant donné que le drapeau de configuration de l'espace établissement est éteint (jusqu'au 2 novembre)
Quand un visiteur ouvre /
Alors aucun lien ni aucune fenêtre « Espace établissement » n'apparaît
Et quand le drapeau est allumé, le lien et sa fenêtre reviennent sans autre changement de code
```

Les autres critères de la page sont ceux du chantier [`page-d-accueil-photo`](../page-d-accueil-photo/memo.md) ; sa règle de palette est l'exception écrite à l'UDR palette (titre gras, vague jaune).

### B. Code de classe

```gherkin
# CA-B1
Étant donné une classe créée ou existante avant la migration
Alors elle a un code de 6 caractères pris dans l'alphabet sans i, l, o, 0, 1, unique en base

# CA-B2
Étant donné un visiteur qui tape le code « k7m 4q2 » d'une classe active
Quand la vérification répond
Alors il voit le nom de la classe, son niveau et son établissement
Et la réponse ne contient aucun nom d'élève ni d'enseignant, aucun identifiant interne

# CA-B3
Étant donné un code inexistant et le code d'une classe archivée
Quand on vérifie l'un puis l'autre
Alors les deux réponses sont identiques

# CA-B4
Étant donné 10 requêtes dans la minute depuis une IP, réparties entre /c/<jeton>, la vérification de code et l'envoi de l'inscription
Quand la 11ᵉ arrive
Alors elle reçoit 429

# CA-B5
Étant donné un enseignant de la classe sur son accueil
Alors la carte de la classe montre son code et un bouton « Copier »
Et un enseignant d'une autre classe ne voit pas ce code

# CA-B6
Étant donné un enseignant qui touche « Changer le lien et le code » et confirme
Alors le lien et le code changent ensemble, l'action est journalisée
Et l'ancien code répond comme un code inconnu
```

### C. Inscription élève en trois étapes

```gherkin
# CA-C1
Étant donné un élève qui ouvre l'inscription sans lien
Alors il voit l'étape « Étape 1 sur 3 », la carte de bienvenue et le champ du code
Et il n'y a aucun bouton « Continuer »

# CA-C2
Étant donné un code reconnu à l'étape 1
Alors l'élève passe à l'étape 2, qui commence par « Ta classe : 3e B · <établissement> » et « Ce n'est pas ta classe ? › »
Et « Ce n'est pas ta classe ? » le ramène à l'étape 1, code vidé

# CA-C3
Étant donné un élève qui ouvre un lien de classe valide
Alors il arrive à l'étape 2 avec le rappel de classe, la carte de bienvenue, sans « ‹ Retour »

# CA-C4
Étant donné nom, prénoms, genre et un numéro de 10 chiffres valides
Quand l'élève cesse de taper pendant environ 1 seconde
Alors il passe à l'étape 3, et le changement est annoncé dans une région aria-live
Et « ‹ Retour » rend l'étape 2 avec les champs intacts

# CA-C5
Étant donné un élève à l'étape 3 qui touche « Créer mon compte » avec un code secret confirmé
Alors son compte est créé dans la classe, avec `joined_via` à « code », « link » ou « standard » (cascade) selon sa voie
Et il arrive sur l'accueil

# CA-C6
Étant donné une erreur serveur sur le numéro (déjà inscrit)
Alors la page s'ouvre à l'étape 2 avec l'erreur sous le champ

# CA-C7
Étant donné un navigateur sans JavaScript
Alors les trois étapes sont visibles l'une sous l'autre et l'inscription aboutit
```

### D. Accueil élève — carte du prochain exercice

```gherkin
# CA-D1
Étant donné un élève connecté avec une classe
Alors l'accueil montre, dans l'ordre : le bandeau, la carte, la grille de 7 cases (6 matières + Inviter), les annonces, l'Historique
Et il n'y a ni barre basse, ni liste « À faire ensuite », ni case « Paiement »

# CA-D2
Étant donné un élève avec deux exercices en retard et un à rendre samedi
Alors la carte montre le plus ancien en retard, la pastille « En retard · <date> », « Et 1 autre en retard › » vers Ma classe, et « Le faire maintenant »

# CA-D3
Étant donné un élève sans retard avec deux exercices à rendre
Alors la carte montre celui dont l'échéance est la plus proche et « Commencer l'exercice », ou « Reprendre » si une session est en cours

# CA-D4
Étant donné un élève dont tout l'assigné est fait et qui a une fiche à revoir
Alors la carte montre la plus ancienne fiche à revoir, sa note et « Revoir la fiche »

# CA-D5
Étant donné un élève dont tout l'assigné est fait, sans fiche à revoir
Alors la carte dit « Tout est fait ! » et propose l'exercice du jour
Et si l'exercice du jour est déjà fait aujourd'hui, elle dit « Exercice du jour fait. Reviens demain ! » sans bouton

# CA-D6
Étant donné un élève dont aucune classe n'a d'exercice assigné
Alors la carte propose l'exercice du jour et « Ton enseignant n'est pas sur Lnclass ? Invite-le › »

# CA-D7
Étant donné un élève sans classe
Alors la carte « Choisis ta classe » montre le champ code et « Je n'ai pas de code »
Et la grille, les annonces et l'historique sont masqués

# CA-D8
Étant donné une matière avec un exercice en retard
Alors sa case porte un point de retard et son nom accessible se termine par « , exercice en retard »

# CA-D9
Étant donné l'en-tête de la carte « 3E B · CM1T › »
Quand l'élève le touche
Alors Ma classe s'ouvre
```

### E. Écrans élève sans répétition

```gherkin
# CA-E1
Étant donné un élève qui touche son avatar
Alors un panneau plein écran « Mon compte » s'ouvre avec, dans l'ordre : Mon profil, Modifier mon code secret, Mode sombre, Se déconnecter
Et ni Accueil, ni Cours, ni Ma classe, ni Mon historique, ni Besoin d'aide n'y figurent

# CA-E2
Étant donné la page Mon profil d'un élève
Alors elle montre six lignes (Photo, Nom, Numéro, Classe, Établissement, Inscrit·e le), sans grande carte en tête
Et la ligne Classe n'a pas d'action ; ni code secret, ni mode sombre, ni « Se déconnecter » sur la page

# CA-E3
Étant donné un élève qui a des fiches à revoir
Alors Ma classe montre la section « Fiches à revoir » juste après « Exercices assignés »

# CA-E4
Étant donné une fiche de révision à revoir
Alors elle porte l'étiquette « À revoir depuis le <date> » sous le titre
Et la carte « Fiche à revoir · Refaire un exercice » n'existe plus

# CA-E5
Étant donné le résultat d'une session
Alors il y a un seul bouton, « Recommencer », et ni l'encadré « Tu restes autour de… » ni « Revoir l'exercice »

# CA-E6
Étant donné la page Cours d'un élève
Alors « Progression DPFC 2026-2027 » n'est écrit qu'une fois
Et chaque fiche est une ligne entière cliquable d'au moins 44 px, sans « Commencer la fiche de cours »
```

### F. Palette froide et texte sans gras

```gherkin
# CA-F1
Étant donné les jetons de @theme
Alors paper vaut #ffffff, ink #1f2128, mute #5f6470, line #e3eef7, et la police des titres est DM Sans
Et le fichier Bricolage Grotesque n'est plus chargé

# CA-F2
Étant donné les fichiers de app/views et app/helpers
Alors aucun ne contient font-semibold, font-bold, font-extrabold ni font-black (hors page d'accueil publique, exception écrite)
Et le test des jetons le vérifie

# CA-F3
Étant donné une note sur 20 affichée à un élève ou un enseignant
Alors elle est verte à 14/20 et plus, en couleur d'encre sinon, jamais rouge
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
```

### H. Menu « Mon compte » enseignant

```gherkin
# CA-H1
Étant donné un enseignant qui touche son avatar
Alors un panneau plein écran montre son nom, « Math · PC · <sigle> », puis Mon profil, Modifier mon code secret, Ajouter une matière (« 2 sur 3 »), Ajouter un établissement (« N sur 3 »), Mode sombre, Se déconnecter
Et « Inviter un collègue » n'y figure pas

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
Et ni le code de classe, ni « Vos jours de séance »

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

### K. Masquages du pilote

```gherkin
# CA-K1
Étant donné un enseignant
Alors aucun écran ne lui propose d'écrire une annonce (entrée masquée ; la route et le code restent, perimetre.md)

# CA-K2
Étant donné un élève
Alors aucun écran ne lui propose de changer de classe

# CA-K3
Étant donné un élève ou un enseignant
Alors aucun écran ne mentionne un paiement ou un abonnement
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
| Domaine | `Entities::Classroom::JoinCode` (calqué sur `SchoolCode`) ; badge de classe d'un élève (méthode pure de `Grading`) ; `RegisterStudent` accepte un code ; `RegisterTeacher` perd `second_material_slug` ; adhésion d'un élève connecté par code |
| Infrastructure | Migration `classrooms.join_code` (ajout, remplissage, contraintes) ; `JoinCodePreviewQuery` ; query de l'accueil élève (état de la carte, 6 règles) ; query de l'accueil enseignant (sigle, code, compteurs de badges) ; `TeacherFollowUpsQuery` partagée en « cette semaine » et « historique » ; badge par élève et filtre `badge=` dans la liste de classe et le rapport |
| Delivery | `GET /classroom-codes/:code` (débit limité) ; « Changer le lien et le code » ; écrans de retrait (matières, établissements) ; drapeau de configuration de l'espace établissement |
| UI | Jetons `@theme` et balayage des graisses ; `signup_steps_controller.js` (élève et enseignant) ; accueil élève (bandeau, carte et ses 6 états, grille, historique) ; panneau « Mon compte » plein écran (deux rôles) ; écrans élève élagués ; accueil, classe, fiche, Cours, rapport et inscription enseignant ; page d'accueil publique |

## 6. Décisions rattachées

- ADR-XXXX — [Code de classe à six caractères, vérifié à débit limité](../../decisions/adr/XXXX-code-de-classe-a-six-caracteres.md) *(Proposé : à accepter avant le lot du code)*
- ADR-0103 — amendé par l'UDR enseignant (une seule matière à l'inscription)
- UDR-XXXX — [Palette froide et texte sans gras](../../decisions/udr/XXXX-palette-froide-et-texte-sans-gras.md)
- UDR-XXXX — [Accueil élève, carte du prochain exercice](../../decisions/udr/XXXX-accueil-eleve-carte-du-prochain-exercice.md)
- UDR-XXXX — [Inscription élève en trois étapes](../../decisions/udr/XXXX-inscription-eleve-en-trois-etapes.md)
- UDR-XXXX — [Écrans élève sans répétition](../../decisions/udr/XXXX-ecrans-eleve-sans-repetition.md)
- UDR-XXXX — [Écrans enseignant sans répétition](../../decisions/udr/XXXX-ecrans-enseignant-sans-repetition.md)
- Chantier [`page-d-accueil-photo`](../page-d-accueil-photo/memo.md) — page d'accueil publique

## 7. Mesures

Mesurées pendant le pilote (27 octobre → 10 novembre), lues dans les tables existantes et le journal d'audit.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves inscrits qui finissent un premier exercice dans les 24 h | non mesuré | ≥ 60 % | |
| Inscriptions élève abandonnées entre l'étape 1 et la création du compte | non mesuré | ≤ 30 % | |
| Part des inscriptions élève par code / lien / cascade | — | à observer | |
| Enseignants inscrits qui assignent un exercice dans les 48 h | non mesuré | ≥ 50 % | |
| Testeurs actifs pendant 14 jours (exigence du test fermé Play Store) | — | ≥ 12 | |
