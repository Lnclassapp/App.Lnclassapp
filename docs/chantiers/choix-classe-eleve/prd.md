# PRD — « Choisis ta classe » aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

« Choisis ta classe » prend le cadre de l'accueil et remplace ses listes déroulantes par trois étapes numérotées : l'établissement en une ligne avec « Changer » (DRENA et établissement restent des listes, derrière ce bouton), les niveaux en pastilles, les classes en grandes cases. La cascade `_class_picker` est partagée : l'inscription élève reprend la même forme. Les règles d'adhésion ne changent pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student sans classe active | Choisir une classe et la rejoindre | Rejoindre une classe complète ; contourner les refus (ADR-0085) |
| Visiteur (inscription) | Même cascade dans la rubrique 1 de l'inscription | — |

Règles inchangées : `ClassPicker`, routes publiques `drena_schools`, `school_picker_levels`, `school_picker_classrooms` (30 / min), refus d'ADR-0085.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève sans classe arrive sur « Choisis ta classe ».
2. Étape 1 « Ton établissement » : une ligne avec le nom de l'établissement de sa dernière classe et « Changer » ; sans établissement connu, les listes DRENA et établissement sont ouvertes.
3. Étape 2 « Ton niveau » : les niveaux qui ont une classe active, en pastilles.
4. Étape 3 « Ta classe » : les classes du niveau en grandes cases ; « Complète » désactivée.
5. « Rejoindre cette classe » s'active quand une case est cochée.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| « Changer » | Les listes DRENA puis établissement s'ouvrent à la place de la ligne ; les étapes 2 et 3 se vident |
| Changement de niveau | L'étape 3 se recharge (cadre `picker_classrooms`) |
| Erreur de chargement | État d'erreur actuel avec « Réessayer » |
| Classe complète | Case désactivée, badge « Complète » |
| Ta classe n'est pas sur Lnclass | Texte actuel sous l'étape 3 |
| Refus (lien plus valable, retiré, déjà inscrit) | Alertes actuelles en tête |
| Sans JavaScript | Bouton « Continuer » à chaque étape (repli actuel) ; les pastilles et cases restent des `radio` |
| ≥ 700 px | Formulaire de 640 px au plus ; classes sur une ligne de 4 cases |
| ≥ 1 024 px | Menu de gauche |

## 4. Critères d'acceptation

```gherkin
# CA-1 Établissement connu
Étant donné un élève dont la dernière classe était au Lycée Classique d'Abidjan
Quand il ouvre « Choisis ta classe »
Alors l'étape 1 montre « Lycée Classique d'Abidjan » et « Changer »
Et l'étape 2 montre les niveaux en pastilles

# CA-2 Changer
Quand il touche « Changer »
Alors les listes DRENA et établissement apparaissent
Et les étapes 2 et 3 sont vides

# CA-3 Classes en cases
Quand il choisit la pastille « 3e »
Alors les classes de 3e apparaissent en cases
Et une classe complète est désactivée avec « Complète »

# CA-4 Rejoindre
Quand il coche « 3e B » et touche « Rejoindre cette classe »
Alors il rejoint la classe (comportement actuel)
Et « Rejoindre cette classe » était désactivé avant de cocher

# CA-5 Sans JavaScript
Étant donné un navigateur sans JavaScript
Alors chaque étape s'avance par « Continuer » et l'élève peut rejoindre une classe

# CA-6 Inscription
Étant donné un visiteur sur l'inscription élève
Alors la rubrique 1 montre la même cascade en trois étapes

# CA-7 Tablette
Étant donné un écran de 820 px
Alors les classes tiennent sur une ligne de 4 cases
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | — (routes, paramètres et `ClassPicker` inchangés) |
| UI | `classroom/student_registrations/_class_picker` (étape 1 repliée avec « Changer ») ; `school/school_levels/index` (pastilles) ; `school/level_classrooms/index` (cases) ; `school/drena_schools/index` (inchangé, derrière « Changer ») ; `classroom/student_classroom_choices/new` (cadre de l'accueil) ; `classroom--class-picker` (Stimulus) gagne `change`. |

## 6. Décisions rattachées

- Pas d'ADR : interface seule.
- [UDR-0091](../../decisions/udr/0091-choix-de-classe-eleve-trois-etapes-pastilles-et-cases.md) : « Choisis ta classe » et la cascade partagée redessinés.

## 7. Mesures

*Sans objet : aucune requête ajoutée.*
