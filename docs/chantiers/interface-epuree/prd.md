# PRD — Interface épurée

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'application est jugée trop chargée pour l'élève, souvent sur un Android d'entrée de gamme. Ce chantier applique à tous les écrans élève et aux trois écrans d'entrée partagés une règle de sobriété chiffrée (UDR-0057). Sur téléphone et tablette, l'accueil élève et la homepage suivent les maquettes du porteur (UDR-0058, UDR-0059) ; sur ordinateur, ils gardent leur mise en page actuelle, épurée. Rien n'est construit pour une fonction absente : échéances, paiement, annonces, audio et aide attendent `fonctions-espace-eleve`.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir son accueil épuré ; ouvrir une matière, un exercice, une fiche à revoir ; commencer, reprendre ou refaire un exercice ; copier le code de sa classe depuis « Inviter » | voir l'accueil d'un autre rôle ; voir la liste nominative de sa classe (inchangé, UDR-0011) |
| Visiteur (anonyme) | voir la homepage ; ouvrir les modales « Je suis élève » et « Enseignant(e) » ; aller à la connexion par « Espace établissement » | rester sur la homepage s'il est connecté (redirigé vers son accueil, inchangé) |
| Teacher, SchoolStaff (direction), Team | voir la homepage, la connexion et la récupération du PIN épurées (grill Q9) | voir l'accueil élève (403, inchangé) |

Aucune règle d'autorisation ne change. `allow_roles :student` reste sur l'accueil élève ; les écrans élève gardent leurs policies (ADR-0028).

## 3. Parcours utilisateur

### Chemin nominal — élève sur téléphone (390 px)

1. L'élève se connecte et arrive sur son accueil.
2. Il voit le bandeau bleu (logo, « Lnclass », « 3ème B · Collège Moderne Les Lauriers », ou le sigle si le nom ne tient pas), puis la carte « Prochain exercice ». Pas de barre basse.
3. Il touche « Commencer l'exercice » : une session démarre (UDR-0022).
4. De retour sur l'accueil, il touche une case de la grille (« SVT ») : le catalogue s'ouvre filtré sur SVT.
5. Il touche « Inviter » : une modale montre le code de sa classe ; il le copie.
6. Il touche « Voir plus » sous « Historique » : les sessions suivantes apparaissent, sans rechargement.

### Chemin nominal — visiteur sur téléphone

1. Il ouvre la homepage : photo, badge, « Forcément, tu comprends chap chap », deux boutons, « Espace établissement ».
2. Il touche « Je suis élève » : la modale de l'UDR-0012 s'ouvre (« Se connecter », « Rejoindre ma classe »).

### Chemin nominal — ordinateur (1 280 px)

1. L'élève voit l'accueil actuel : « Bonjour, <prénom> », « À faire », « Ma classe », « Cours », « Activité récente ».
2. Chaque ligne d'exercice montre titre, matière et un bouton ; seul le premier est principal. Plus de bloc d'aide.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun exercice assigné | Carte du haut : « MA CLASSE », la classe, « Tes enseignants n'ont rien assigné pour l'instant. », « Voir mes cours » ; pas de section « À faire ensuite » |
| Tous les exercices terminés | Carte du haut : « Bravo <prénom>, tout est fait ! », la barre pleine, « Voir mes cours » |
| Une session est en cours sur le prochain exercice | Bouton « Reprendre l'exercice », vers la session |
| Plus de 3 lignes dans une liste | 3 lignes visibles, puis « Voir plus » ; « N lignes de plus affichées » annoncé |
| Note sous la note de passage dans l'historique | Note neutre et bouton « Refaire » à la place de l'heure |
| Matière de la grille absente du référentiel | Sa case n'est pas rendue |
| Élève du 2nd cycle | « Philosophie » à la place d'« EDHC » |
| Élève sans classe active | Un seul saut vers l'écran de sortie (inchangé) |
| Frame de l'historique en échec | `ui_error_state` avec « Réessayer » |
| Enseignant qui ouvre l'accueil élève | 403 (inchangé) |
| Tablette (820 px) | Même écran que le téléphone, en colonne centrée de 36 rem |
| Photo de la homepage indisponible | Fond `ink`, rien ne se décale |

## 4. Critères d'acceptation

Chacun devient un test.

```gherkin
# Accueil élève — téléphone et tablette (UDR-0058 §3.2)
Étant donné un élève de 3ème B avec 3 exercices assignés, aucun commencé
Quand il ouvre son accueil sur un écran de 390 px de large
Alors il voit « Lnclass » et « 3ème B · <établissement> » dans le bandeau
Et la carte « PROCHAIN EXERCICE » nomme le plus récemment assigné, avec « Commencer l'exercice »
Et il voit « 0 exercices faits sur 3 »
Et il ne voit ni la barre basse ni l'en-tête du shell
Et il ne voit ni « Paiement », ni annonce, ni échéance, ni durée, ni bouton d'aide

Étant donné un élève dont le prochain exercice a une session en cours
Quand il ouvre son accueil sur téléphone
Alors la carte propose « Reprendre l'exercice », vers cette session

Étant donné un élève sans exercice assigné
Quand il ouvre son accueil sur téléphone
Alors la carte dit « Tes enseignants n'ont rien assigné pour l'instant. » et propose « Voir mes cours »
Et la section « À faire ensuite » n'est pas rendue

Étant donné un élève dont tous les exercices sont terminés
Quand il ouvre son accueil sur téléphone
Alors la carte dit « Bravo <prénom>, tout est fait ! »

Étant donné un élève du 1er cycle
Quand il ouvre son accueil sur téléphone
Alors la grille montre Maths, Physique-Chimie, SVT, Français, Histoire-Géo, EDHC et Inviter, dans cet ordre
Et la case SVT mène au catalogue filtré sur la matière « svt »

Étant donné un élève du 2nd cycle
Quand il ouvre son accueil sur téléphone
Alors la grille montre « Philosophie » à la place d'« EDHC »

Étant donné un élève de 3ème B
Quand il touche « Inviter »
Alors une modale montre le code de sa classe en deux groupes de 3 caractères, avec « Copier » et « Voir ma classe »

Étant donné un élève avec 5 exercices non terminés
Quand il ouvre son accueil sur téléphone
Alors « À faire ensuite » montre 3 lignes et « Voir plus »
Et la carte du haut ne figure pas dans la liste
Quand il touche « Voir plus »
Alors la 4e ligne apparaît sans rechargement

Étant donné un élève qui a terminé une session à 40 %
Quand l'historique se charge
Alors la ligne montre « 8/20 » et « Refaire », qui démarre une nouvelle session de cet exercice

Étant donné un établissement au nom trop long pour le bandeau, avec un sigle
Quand l'élève ouvre son accueil sur un écran de 360 px
Alors le bandeau affiche le sigle, et le nom complet reste dans le title du lien

Étant donné un élève sur un écran de 820 px de large
Quand il ouvre son accueil
Alors il voit la même mise en page que sur téléphone, dans une colonne d'au plus 36 rem

# Accueil élève — ordinateur (UDR-0058 §3.3)
Étant donné un élève avec 4 exercices assignés
Quand il ouvre son accueil sur un écran de 1 280 px de large
Alors l'en-tête dit « Bonjour, <prénom> » sans sous-titre
Et aucun texte « Badges » ou « Maîtrise » n'est affiché sous « À faire »
Et chaque ligne montre le titre, la matière et un seul bouton
Et seul le premier bouton de la liste est un bouton principal
Et 3 lignes sont visibles, puis « Voir plus »

# Homepage (UDR-0059)
Étant donné un visiteur sur un écran de 390 px de large
Quand il ouvre la homepage
Alors il voit le slogan « Forcément, tu comprends chap chap », le badge « De la 6ème à la Terminale, même sans internet », « Je suis élève », « Enseignant(e) » et « Espace établissement »
Et il ne voit ni les sections de présentation ni l'invitation aux applications
Quand il touche « Je suis élève »
Alors la modale élève s'ouvre avec « Se connecter » et « Rejoindre ma classe »

Étant donné un visiteur sur un écran de 1 280 px de large
Quand il ouvre la homepage
Alors il voit la landing de l'UDR-0012, sans la section « Rejoindre » ni le lien d'en-tête « Commencer »

# Règle de sobriété (UDR-0057), sur chaque écran élève et chaque écran d'entrée
Étant donné un écran élève rendu à 390 × 844
Alors il a au plus un bouton ou lien principal
Et au plus 5 blocs de premier niveau commencent avant le premier défilement
Et chaque liste montre au plus 3 lignes avant « Voir plus »

# Garde-fous
Étant donné un enseignant connecté
Quand il ouvre l'accueil élève
Alors il reçoit 403

Étant donné les vues du chantier
Alors aucune ne contient de #hex, d'attribut style, de valeur entre crochets ni de variante dark: (test des tokens)
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun changement (lecture seule ; seuils lus dans `Entities::Assessment::Grading`) |
| Infrastructure | `Queries::Classroom::StudentHomeQuery` : champs `school_sigle`, `level_cycle`, `material_slug`, `material_name`, `exercise_public_id` (§3.1 de l'UDR-0058). Aucune migration |
| Delivery | aucun nouveau contrôleur ni route ; `StudentHomesController` et `HomepageController` inchangés |
| UI | `@theme` (teintes, `hero`, `radius-hero`, `radius-sheet`, `container-phone`) ; partial `shared/_subject_symbols` ; `StudentHomeHelper::SUBJECT_TILES` ; contrôleurs Stimulus `reveal` et `fit-text` ; option `content_for :mobile_chrome` du shell ; vues de l'accueil élève et de la homepage ; épuration des autres écrans élève et d'entrée, écran par écran, avec l'amendement de leur UDR ; ressources `logo/lnclass-mark.png` et `homepage/eleves.jpg` |

## 6. Décisions rattachées

- [UDR-0057](../../decisions/udr/0057-ecrans-eleve-epures.md) — Écrans élève épurés : règle de sobriété et deux familles d'écrans
- [UDR-0058](../../decisions/udr/0058-accueil-eleve.md) — Accueil élève (remplace l'UDR-0010)
- [UDR-0059](../../decisions/udr/0059-homepage-telephone-et-tablette.md) — Homepage sur téléphone et tablette (amende l'UDR-0012)
- Amendements à venir, un par lot d'épuration : UDR-0009, 0011, 0013, 0015, 0021, 0022, 0023, et les UDR de la connexion et de la récupération du PIN
- **Aucun ADR** : ni port, ni table, ni dépendance, ni contrat nouveaux. La query gagne des colonnes lues sur des tables existantes.

## 7. Mesures

> Colonne « Avant » mesurée au Lot 0, le 2026-10-02, sur `feature/interface-epuree` : Chrome à 390 px de large, élève de 3ème B, 5 exercices assignés dont 1 terminé.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Informations par ligne d'exercice (accueil élève) | 7 et un bouton | 3 (titre, matière, une donnée) | |
| Boutons principaux sur l'accueil élève | autant que d'exercices (4 visibles avec 5 exercices, dont 1 terminé) | 1 | |
| Blocs de premier niveau avant défilement, accueil élève à 390 × 844 | 7 (en-tête, titre « À faire », aide, 4 lignes d'exercice) | ≤ 5 | |
| Poids HTML de l'accueil élève (ADR-0067 : < 150 Ko) | 39 Ko (5 exercices, historique chargé) | < 150 Ko | |
| Poids de la homepage sur téléphone, photo comprise (ADR-0051) | photo `homepage/student.png` : 1 307 Ko, chargée aussi sur téléphone | photo ≤ 150 Ko | |
