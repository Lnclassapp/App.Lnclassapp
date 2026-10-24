# PRD — MVP Lnclass Teacher & Student — pilote du 27 octobre — **élève**

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Le détail des écrans est dans les UDR (§6) : ce PRD dit **ce qui doit être vrai**, les UDR disent **comment c'est dessiné**. En cas d'écart sur un écran, l'UDR gagne ; sur un comportement, ce PRD gagne.
>
> **Élève seulement** (porteur, 2026-10-24, « option A » : l'élève d'abord, l'enseignant après). Les critères enseignant (CA-G à CA-J, CA-L, ancien CA-B5 et CA-B6, CA-K1) restent dans la version `c766532` de ce fichier ; ils reviendront dans un PRD enseignant. Les numéros gardés ne changent pas ; CA-B5 est réattribué (adhésion par code d'un élève connecté), CA-F4 et CA-B7 (ligne provisoire du code côté enseignant, porteur, 2026-10-24) sont nouveaux.

## 1. Contexte

Le pilote du mardi 27 octobre (test fermé Google Play, contacts du porteur) ouvre l'app à des élèves qui la découvrent : elle ne dit pas par où commencer, et l'accueil s'ouvre sur « Entrer en classe » plutôt que sur le travail à faire. Côté élève, le chantier construit trois choses (accueil « carte du prochain exercice », code de classe à 6 caractères, page d'accueil publique en photo), passe toute l'app à la palette froide sans gras, et retire les répétitions des écrans élève. Le reste est gardé, masqué ou reporté selon [`perimetre.md`](perimetre.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Visiteur** (non connecté) | Voir la page d'accueil publique ; ouvrir les fenêtres « Je suis élève » et « Enseignant(e) » ; vérifier un code de classe (aperçu : classe, niveau, établissement) ; s'inscrire comme élève | Voir « Espace établissement » avant le 2 novembre ; apprendre d'un code autre chose que l'aperçu ; dépasser 10 vérifications ou envois par minute et par IP |
| **Élève** | Rejoindre une classe par code, lien ou cascade ; faire ses exercices et l'exercice du jour ; lire cours, fiches à revoir, annonces de l'équipe et de la direction, son historique ; gérer son profil et son code secret | Changer de classe (masqué) ; voir une autre classe que la sienne ; lire les annonces d'un enseignant (masquées) |

Règles d'autorisation applicables, toutes existantes : `ReadClassroomPolicy`, compteur de débit `classroom/joins` (lien, code, inscription), partagé. Aucune policy nouvelle.

## 3. Parcours utilisateur

### Chemin nominal — élève

1. Il reçoit le lien de classe sur WhatsApp, l'ouvre : l'inscription s'ouvre à l'étape 2/3, « Ta classe : 3e B · <établissement> » en tête.
2. Il tape nom, prénoms, genre, numéro : il passe seul à l'étape 3 ; il choisit son code secret et touche « Créer mon compte ».
3. L'accueil s'ouvre : la carte du haut montre l'exercice le plus urgent et un seul bouton.
4. Il fait l'exercice, voit sa note sur 20, son badge et un seul bouton « Recommencer ».
5. De retour à l'accueil, l'exercice est dans l'Historique, et la carte montre le suivant.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Élève sans lien, avec le code au tableau | Étape 1/3, il tape le code : au 6ᵉ caractère, vérification, puis étape 2 avec le rappel de classe |
| Code inconnu, ou classe archivée | Même message sous le champ, sans dire laquelle des deux ; l'élève reste à l'étape 1 |
| Plus de 10 essais par minute (lien, code, envoi) | 429, « Trop de tentatives. Attends une minute, ou coche « Je n'ai pas de code ». » |
| Élève sans code ni lien | « Je n'ai pas de code » déplie la cascade DRENA → établissement → niveau → classe ; toucher une classe passe à l'étape 2 |
| Classe complète | Tuile désactivée dans la cascade ; par code ou lien, refus comme aujourd'hui |
| Lien de classe invalide, archivé ou régénéré | L'inscription s'ouvre à l'étape 1/3, jamais sur une erreur |
| Erreur serveur sur un champ à l'envoi | La page rouvre la première étape qui contient un champ en erreur, saisies gardées |
| Élève connecté sans classe | Carte « Choisis ta classe » avec le champ code ; grille, annonces et historique masqués |
| Classe sans exercice assigné | Carte « Exercice du jour » et « Ton enseignant n'est pas sur Lnclass ? Invite-le › » |
| Tout l'assigné est fait | Fiche à revoir la plus ancienne s'il y en a, sinon « Tout est fait ! » avec l'exercice du jour |
| Collégien de moins de 13 ans sans compte Google | Il passe par la version web (PWA) ; rien à construire |

## 4. Critères d'acceptation

> **Téléphone d'abord** (porteur, 2026-10-24) : les lots livrent les écrans du téléphone (390 px). Les versions ordinateur viennent ensuite, dans une phase à part (§4 bis). D'ici là, chaque lot vérifie seulement que son écran **reste utilisable** sur ordinateur, sans rien de cassé : la capture ordinateur sert à le prouver, pas à juger une mise en page.

Chaque critère devient au moins un test ; le plan ([`plan.md`](plan.md)) dit lequel. Les numéros servent de référence dans les tests et les lots. **Les lettres des critères ne sont pas celles des lots** : le plan donne la correspondance.

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
Étant donné un élève connecté sans classe, sur la carte « Choisis ta classe »
Quand il tape le code d'une classe active et confirme
Alors il rejoint cette classe, avec `joined_via` à « code »
Et un code inconnu le laisse sur la carte avec le même message qu'à l'inscription

# CA-B7 (provisoire, jusqu'aux lots enseignant)
Étant donné l'enseignant d'une classe sur la page de cette classe
Alors il voit « Code de la classe » avec le code et un bouton « Copier »
Et un enseignant d'une autre classe ne voit pas ce code
Et après « Changer le lien », le code affiché est le nouveau
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
Étant donné une note sur 20 affichée à un élève
Alors elle est verte à 14/20 et plus, en couleur d'encre sinon, jamais rouge

# CA-F4
Étant donné un écran enseignant, direction ou équipe
Alors il prend le fond blanc et les gris froids, sans autre retouche
Et seules les captures élève et enseignant (390 px et ordinateur) sont montrées au porteur avant la fusion du lot des jetons
```

### K. Masquages du pilote (élève)

```gherkin
# CA-K2
Étant donné un élève
Alors aucun écran ne lui propose de changer de classe

# CA-K3
Étant donné un élève
Alors aucun écran ne mentionne un paiement ou un abonnement
```

## 4 bis. Phase ordinateur (après les lots téléphone)

Les écrans élève sont décidés, sauf Cours (à redessiner) (porteur, 2026-10-24, maquettes à 1440 et 1024 px, en gris puis en palette froide). Détail : UDR accueil §3.1, UDR inscription §3.5 bis, UDR écrans élève §3.1 et §3.6 bis ; page publique : chantier `page-d-accueil-photo` (texte à gauche, photo à droite), sans nouveau dessin. Lots : [`plan.md`](plan.md), « Phase ordinateur — élève ».

> **Rien ne change sur téléphone** (porteur, 2026-10-24) : les critères du §4, issus des écrans téléphone validés le 2026-10-23, font foi. « Mon établissement », le profil à carte bleue et Cours par leçons sont décidés **pour l'ordinateur seulement** (porteur, 2026-10-24 : « uniquement sur ordinateur, mes choix d'hier pour le téléphone ») : CA-E8, CA-E9, CA-E10, CA-E14 et CA-E15 ci-dessous. Chacun vérifie aussi qu'à 390 px l'écran reste celui du §4.

Sauf mention, « sur ordinateur » veut dire une fenêtre de 1024 px de large ou plus (≥ lg), vérifiée à 1024 et à 1440 px.

### A′. Page d'accueil publique (ordinateur)

```gherkin
# CA-A3
Étant donné un visiteur sur ordinateur
Quand il ouvre /
Alors le texte est à gauche et la photo à droite, sur un seul écran, sans en-tête ni pied de page
Et la feuille de gauche mord sur la photo par son bord arrondi
```

### C′. Inscription (ordinateur)

```gherkin
# CA-C8
Étant donné un élève sur ordinateur à l'étape 1, 2 ou 3 de l'inscription
Alors il voit à gauche un panneau bleu foncé (brand-strong, texte blanc) avec « Bienvenue sur Lnclass », la liste des trois étapes et « Déjà un compte ? Se connecter »
Et à droite le formulaire de l'étape, avec « Étape N sur 3 », sans la barre en trois segments
Et le panneau est le même aux trois étapes, l'étape en cours portant aria-current="step"

# CA-C9
Étant donné un élève sur ordinateur dont la classe est trouvée (code ou lien)
Alors « 3e B · <établissement> » et « Ce n'est pas ta classe ? › » sont dans le panneau, sous l'étape 1 cochée
Et le rappel de classe n'est pas répété au-dessus du formulaire
```

### D′. Accueil élève (ordinateur)

```gherkin
# CA-D10
Étant donné un élève connecté avec une classe, sur ordinateur
Alors le contenu tient dans 912 px à côté de la barre latérale Accueil · Cours · Ma classe, sans carte de profil
Et la carte du prochain exercice (2/3) et l'annonce (1/3) sont côte à côte, à cheval sur le bandeau
Et la grille des matières tient sur une ligne de 7 cases, l'Historique sur deux colonnes de jours
```

### E′. Écrans élève sur ordinateur

```gherkin
# CA-E7
Étant donné un élève sur ordinateur qui clique sur son avatar
Alors « Mon compte » s'ouvre en panneau latéral droit de 400 px sur un voile
Et Échap, la croix ou un clic sur le voile le ferment, le focus revenant sur l'avatar

# CA-E8 (ordinateur seulement)
Étant donné un élève sur ordinateur qui ouvre « Mon compte »
Alors il voit, dans l'ordre : l'en-tête (avatar, nom, classe · établissement), Mon profil, Mon établissement, Modifier mon code secret, Mode sombre, Se déconnecter
Et Ma classe n'y figure pas
Et à 390 px, la liste reste celle de CA-E1

# CA-E9 (ordinateur seulement)
Étant donné la page Mon profil d'un élève sur ordinateur
Alors elle commence par une carte bleue avec l'avatar et le nom seul
Et « Mes informations » a quatre lignes : Photo, Nom, Numéro, Inscrit·e le
Et à 390 px, la page reste celle de CA-E2

# CA-E10 (ordinateur seulement)
Étant donné un élève avec une classe, sur ordinateur, qui choisit « Mon établissement »
Alors un écran montre, en lecture seule : Nom, Sigle, DRENA, Type
Et la ligne Sigle est absente si l'établissement n'en a pas
Et un élève ne voit que l'établissement de sa classe

# CA-E11
Étant donné Ma classe sur ordinateur
Alors « Exercices assignés » puis « Fiches à revoir » sont dans la colonne de gauche (2/3), « Exercices traités » dans celle de droite (1/3)

# CA-E12
Étant donné un élève sur ordinateur qui lit une fiche de révision
Alors la carte « Exercices » est dans une colonne de droite de 300 px qui reste visible quand il fait défiler la fiche
Et l'enseignant voit la même fiche avec la mise en page actuelle

# CA-E13
Étant donné le résultat d'une session sur ordinateur
Alors le badge, la note, la maîtrise et « Recommencer » sont dans une colonne de gauche de 340 px qui reste visible quand on fait défiler la correction

# CA-E14 (ordinateur seulement)
Étant donné un élève sur ordinateur qui ouvre Cours pour une matière
Alors il ne voit que les leçons de cette matière, une carte par leçon sur deux colonnes, dans l'ordre du programme
Et chaque carte montre « LEÇON N », le titre, « En cours » s'il y a lieu, puis ses fiches en lignes cliquables d'au moins 44 px
Et une leçon de plus de 3 fiches montre les 3 premières et « Voir les N fiches »
Et une fiche à revoir porte l'étiquette « À revoir »
Et à 390 px, la page reste celle de CA-E6

# CA-E15 (ordinateur seulement)
Étant donné un élève sur ordinateur sur la page Cours
Alors les 6 matières sont en pastilles en haut, celle affichée pleine et marquée aria-current="page"
Et « Cours » de la barre latérale ouvre la matière de la dernière case touchée, sinon la première de la grille
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::JoinCode` (calqué sur `School::SchoolCode`) ; attribut `join_code` de la classe ; `RegisterStudent` et l'adhésion d'un élève connecté acceptent un code |
| Infrastructure | Migration `classrooms.join_code` (ajout, remplissage, contraintes) ; `JoinCodePreviewQuery` ; `StudentHomeQuery` (état de la carte, 6 règles) |
| Delivery | `GET /classroom-codes/:code` (Turbo Frame, débit partagé `classroom/joins`) ; drapeau `school_space_enabled` |
| UI | Jetons `@theme`, DM Sans seule, balayage des graisses ; `signup_steps_controller.js` ; accueil élève (bandeau, carte et ses 6 états, grille, historique) ; panneau « Mon compte » ; écrans élève élagués ; page d'accueil publique |

## 6. Décisions rattachées

- ADR-XXXX — [Code de classe à six caractères, vérifié à débit limité](../../decisions/adr/XXXX-code-de-classe-a-six-caracteres.md) *(Accepté le 2026-10-23)*
- UDR-XXXX — [Palette froide et texte sans gras](../../decisions/udr/XXXX-palette-froide-et-texte-sans-gras.md)
- UDR-XXXX — [Accueil élève, carte du prochain exercice](../../decisions/udr/XXXX-accueil-eleve-carte-du-prochain-exercice.md)
- UDR-XXXX — [Inscription élève en trois étapes](../../decisions/udr/XXXX-inscription-eleve-en-trois-etapes.md)
- UDR-XXXX — [Écrans élève sans répétition](../../decisions/udr/XXXX-ecrans-eleve-sans-repetition.md)
- UDR-0059 et chantier [`page-d-accueil-photo`](../page-d-accueil-photo/memo.md) — page d'accueil publique

## 7. Mesures

Mesurées pendant le pilote (27 octobre → 10 novembre), lues dans les tables existantes et le journal d'audit.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves inscrits qui finissent un premier exercice dans les 24 h | non mesuré | ≥ 60 % | |
| Inscriptions élève abandonnées entre l'étape 1 et la création du compte | non mesuré | ≤ 30 % | |
| Part des inscriptions élève par code / lien / cascade | — | à observer | |
| Testeurs actifs pendant 14 jours (exigence du test fermé Play Store) | — | ≥ 12 | |
