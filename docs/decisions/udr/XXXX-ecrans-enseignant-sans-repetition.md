# UDR-XXXX : Écrans enseignant sans répétition — accueil, menu « Mon compte », classe, fiche d'un élève, Cours, rapport, inscription
<!-- index
titre: Écrans enseignant sans répétition, en jaune enseignant
statut: Accepté *(porteur, 2026-10-23)*
adr-lie: [0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md)
problematique: Les écrans enseignant répètent leurs informations (liste des classes sur l'accueil et dans l'onglet Classes, établissement dans l'en-tête et sur chaque carte, « Inviter » dans le menu, sur l'accueil et dans la barre latérale) et rangent les élèves de trois façons (groupes de notes, catégories de compréhension, moyenne). Une information garde une seule place, les élèves se rangent par badge, la barre basse disparaît et le jaune du logo enseignant remplace le bleu vif.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : écrans en gris validés « option A », couleurs « C », UDR demandée « oui, écris l'UDR enseignant » ; premier parcours et jours de séance « A », §3.13) |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | [ADR-0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md), amendé ici (§4) · ADR-XXXX-code-de-classe-a-six-caracteres (code affiché sur la carte de classe) |
| **Amende** | [UDR-0077](0077-organisation-des-ecrans-enseignant.md) (accueil, barre basse) · [UDR-0080](0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) (panneau du compte enseignant) · [UDR-0072](0072-comprehension-d-un-exercice-assigne.md) §3.5 (catégories du rapport) · [UDR-0108](0108-liste-des-eleves-en-liens-et-par-trente.md) (groupes de notes de la liste) · [UDR-0125](0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md) (« Autre matière » à l'inscription, action de la ligne Matières du profil) · [UDR-0062](0062-echeances.md) §3.4 (« Plus tard » retiré de la fenêtre des jours) · [UDR-0025](0025-declaration-des-classes.md) (déclaration des classes) |
| **S'appuie sur** | UDR-XXXX-palette-froide-et-texte-sans-gras · UDR-XXXX-accueil-eleve-carte-du-prochain-exercice · UDR-XXXX-ecrans-eleve-sans-repetition · UDR-XXXX-inscription-eleve-en-trois-etapes · [UDR-0098](0098-etablissement-courant-de-l-enseignant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant du pilote ouvre l'app sur son téléphone pour deux gestes : donner un exercice à une classe, puis voir qui l'a fait. L'accueil actuel commence par « Bonjour, Ibrahim », répète l'établissement, garde une barre basse à quatre onglets, et propose « Inviter un collègue » à trois endroits. Les élèves sont rangés par groupes de notes sur la page de classe, par catégories de compréhension sur le rapport, et par moyenne sur la carte de classe : trois vocabulaires pour une même question, « qui va bien ? ».

## 2. Décision

1. **Même plan que l'accueil élève** : bandeau, carte à cheval, grille de ronds, annonces, liste. **Pas de barre basse.** Aucun titre de section affiché sur l'accueil (titres gardés pour les lecteurs d'écran).
2. **Une information, une place.** La liste des classes vit sur l'accueil seul ; « Inviter » dans la grille seule ; l'établissement dans le sigle de la carte de classe ; le code de classe sur la carte de classe seule.
3. **Un seul rangement des élèves : le badge** (Bronze, Argent, Or, Diamant, Pas encore). Il remplace les groupes de notes (page de classe), « En difficulté · Fragile · Acquis » (rapport) et la moyenne seule (carte de classe).
4. **Le jaune enseignant remplace le bleu vif** (`brand` → `teacher`) sur tous les écrans enseignant : bandeau, barres de progression, segments d'étape. C'est le choix C du porteur, contre la recommandation de garder les barres en bleu. Boutons, liens, ronds d'icône et carte de bienvenue restent bleus.
5. **Le menu « Mon compte » est plein écran**, comme celui de l'élève, et porte les plafonds (3 matières, 3 établissements) avec leur écran de retrait.
6. **L'inscription passe en trois étapes**, avec le contrôleur de l'élève, et ne demande plus qu'une matière.

Pourquoi le badge plutôt que la moyenne : l'élève voit des badges, pas des moyennes ; l'enseignant et l'élève parlent la même langue (« elle est passée Or »). Pourquoi pas de barre basse : ses quatre destinations ont chacune une entrée sur l'accueil (classes, niveaux, annonces, suivi), et l'élève n'en a pas non plus.

## 3. Règles d'implémentation

### 3.1 Couleur du rôle (exception de rôle à l'UDR palette)

| Élément | Élève | Enseignant |
|---|---|---|
| Bandeau de l'accueil | `bg-brand` | **`bg-teacher`** (#ff8a00 ; sombre #9a5000) |
| Remplissage des barres de progression | `bg-brand` | **`bg-teacher`** (piste `bg-line` inchangée) |
| Segments d'étape de l'inscription | `bg-brand` | **`bg-teacher`** |
| Panneau gauche de l'inscription, sur ordinateur (§3.9) | — | **`bg-teacher`** (porteur, 2026-10-24) |
| Texte et icônes sur le bandeau | `text-band-ink` | `text-band-ink` (6,2:1 sur #ff8a00 ; blanc sur #9a5000 en sombre, 6,0:1) |
| Boutons, liens, ronds d'icône, pastilles d'état, carte de bienvenue | bleus | **bleus, inchangés** |
| Filet `ROLE_ACCENTS` en haut de l'écran | — | **retiré** (doublon du bandeau) |

- La couleur se choisit par le rôle, à un seul endroit : un helper `role_fill_class(role)` dans `NavigationHelper`, à côté de `ROLE_ACCENTS`, rend `bg-brand` ou `bg-teacher`. Les partiels de bandeau, de barre de progression et de segments le reçoivent ; aucune vue n'écrit `bg-teacher` en dur.
- Risque assumé par le porteur : une barre jaune peut voisiner la pastille ambre « en retard ». La pastille garde son point `bg-warning-dot` et son libellé, qui la distinguent d'une barre.
- **Logo** : baobab sur orange (`BrandHelper::LOGOS[:teacher]`) sur tous les écrans enseignant, expéditeur des annonces de l'équipe compris (`brand_logo(teacher: true)`).
- Trophées des badges : couleurs actuelles de `Assessment::ComprehensionHelper::BADGE_ICON_CLASSES`, sur l'icône seulement, jamais sur un texte. La pastille qui les porte est neutre : `bg-mist border border-line text-ink`.

### 3.2 Badge d'un élève dans une classe

Une seule règle, méthode pure du domaine (`Entities::Assessment::Grading.class_badge_for(scores:, all_perfect:)` ou équivalent), testée seule :

| Badge | Condition, sur les exercices assignés de la classe que l'élève a faits |
|---|---|
| **Diamant** | Au moins un exercice fait, et chacun sans faute |
| **Or** | Moyenne ≥ `GOLD_THRESHOLD` |
| **Argent** | Moyenne ≥ `MASTERY_THRESHOLD` |
| **Bronze** | Moyenne ≥ `PASS_THRESHOLD` |
| **Pas encore** | Aucun exercice fait, ou moyenne sous `PASS_THRESHOLD` |

- Moyenne = moyenne des notes retenues par `Grading` pour chaque exercice assigné fait. Chaque élève compte **une fois** dans les compteurs (option A du porteur).
- Calcul en lecture, une requête par écran, jamais une par élève.

### 3.3 Accueil (`classroom/teacher_homes/show.html.erb`)

```
#teacher_home
├── header.teacher-band        bg-teacher, ≈ 132 px ; avatar (ouvre « Mon compte ») à gauche, « Besoin d'aide ? » text-band-ink à droite
├── section#teacher_home_classrooms   carrousel de cartes de classe, à cheval sur le bandeau (débord ≈ 40 %)
├── nav#teacher_home_courses          un rond par niveau-série enseigné, puis « Inviter »
├── section#teacher_home_announcements   carrousel d'annonces existant
├── section#teacher_home_week         « Cette semaine » (titre sr-only)
├── section#teacher_home_history      « Historique » (titre sr-only)
└── pending_colleagues                inchangé, s'il y en a
```

- **Retirés** : `ui_page_header` (« Bonjour, Ibrahim », ligne établissement et matières, « Changer »), les `ui_card` qui enveloppent les sections, le menu ⋮ « Modifier mes classes », le bouton « Tous les cours », la carte `identity/referrals/invite` sous lg, la barre basse `shared/navigation/_bottom_bar` pour l'enseignant (`BOTTOM_TABS[:teacher]` vidé ; les routes restent).
- Ordre figé : classes → niveaux → annonces → cette semaine → historique. `HOME_SECTIONS[:teacher]` suit cet ordre (avec `:history`).
- **Sur ordinateur (≥ lg), page large** (maquettes envoyées le 2026-10-23, page large confirmée le 2026-10-24) : contenu centré de 57 rem au plus, à côté de la barre latérale **Accueil · Mes classes · Cours** (sans carte de profil, sans Annonces) ; le bandeau prend la largeur du contenu, sans avatar ni aide. Les cartes de classe passent du carrousel à une **grille de 3 colonnes** (la carte « + Ajouter une classe » en dernier), à cheval sur le bandeau ; les ronds de niveau en une ligne ; l'annonce en pleine largeur ; puis **« Cette semaine » et « Historique » côte à côte**, titres visibles sur ordinateur.

**Carte de classe** (`_classroom_card.html.erb`, réécrit). `bg-white border-line rounded-card shadow-card`, padding 18 px, largeur ≈ 82 % de l'écran pour laisser voir la suivante :

| Ordre | Contenu | Style |
|---|---|---|
| 1 | « TLE D 1 · CSMT › » : classe · sigle de l'établissement (nom abrégé sans sigle), lien vers la page de la classe | 12 px majuscules `text-brand-strong`, zone ≥ 44 px |
| 2 | « 20 élèves » | 18 px, 500 |
| 3 | « 2 exercices en cours » (assignations actives) ; « Aucun exercice en cours » à zéro | 13 px `text-mute` |
| 4 | Pastilles de badges (§3.2), ordre Bronze · Argent · Or · Diamant, « Or 3 » ; **un badge à zéro est caché** ; « Pas encore » ne figure pas ici | §3.1, 12 px |
| 5 | Encadré du code : « Code de la classe », code en police mono espacée, bouton `secondary` `sm` « Copier » (`clipboard_controller`, annonce « Code copié ») | bordure pointillée `border-line-strong`, `rounded-ln` |
| — | Logo enseignant 18 px, coin haut droit | |

- **Classe vide** : la ligne 2 devient « Aucun élève », la ligne 3 « Donnez-leur le code, ou partagez le lien sur WhatsApp. », la ligne 4 disparaît ; le code reste (§3.13).
- **Dernière carte** : « + Ajouter une classe », bordure `border-dashed border-line-strong`, texte `text-brand-strong`, vers `teacher_classrooms_path`. **Aucune classe** : la carte du haut devient l'état vide du §3.13.
- Points du carrousel : ceux de `communication--carousel`, inchangés.

**Niveaux** (`_course_levels.html.erb`) : 4 colonnes, rond 56 px `bg-brand-soft`, icône `images/levels/<niveau>.svg`, libellé 13 px « Tle D », « 1re D », « 2nde C ». Chaque rond mène à `courses_path(level:, series:)`. Dernier rond : « Inviter » (comportement actuel, partage WhatsApp `/i/<jeton>`). Sans matière dans l'établissement : `_choose_materials` à la place (inchangé).

**Annonces** : `communication/messages/_carousel`, `dismissible: false`, carte `bg-brand-soft` sur bande `bg-mist`, expéditeur Lnclass avec le logo enseignant. Section absente sans annonce. Les annonces rédigées par l'enseignant restent masquées pour le pilote.

**Cette semaine** (`_follow_ups.html.erb`, réécrit) : les assignations dont l'échéance tombe dans les 7 prochains jours, **ou** est passée depuis 14 jours au plus avec au moins un élève qui ne l'a pas fait (fenêtre actuelle de `TeacherFollowUpsQuery`). Ligne :
- rond 40 px `bg-brand-soft` + icône de matière ; titre 14 px (lien vers le suivi) ; « Tle D 1 · à rendre ven. 30 oct. » 13 px `text-mute` ;
- barre (piste `bg-line`, remplissage §3.1) + « 20 / 27 faits » 12 px `text-ink` ;
- pastille « 7 en retard » (`bg-warning-soft text-warning`, point) si l'échéance est passée, sinon « 7 pas encore » (`bg-brand-soft text-brand-strong`) ; cachée à zéro.
- 3 lignes, puis « Voir plus » en **lien discret** (14 px `text-brand-strong`, centré, sans cadre, `ui_reveal_more`). Vide : « Aucun exercice à suivre cette semaine. » (13 px `text-mute`).

**Historique** (nouveau partiel `_history.html.erb`) : les assignations échues des 30 derniers jours qui ne sont pas dans « Cette semaine » (tous les élèves l'ont fait, ou échéance passée depuis plus de 14 jours). Une assignation n'est jamais dans les deux listes.
- Sous-titres de jour (date d'échéance) 12 px majuscules `text-mute` : « AUJOURD'HUI », « HIER », puis la date.
- Ligne : rond 40 px + titre 14 px + « Tle D 1 · 27 / 27 faits » 13 px + **moyenne de la classe** à droite (« 14,5/20 », `text-success` à 14/20 et plus, sinon `text-ink`, jamais de rouge).
- 3 lignes puis « Voir plus » (même lien discret). Vide : section absente.

### 3.4 Menu « Mon compte » (`shared/navigation/_account_panel.html.erb`, `classroom/teacher_menus/show`, `NavigationHelper::ACCOUNT_PANELS[:teacher]`)

- **Plein écran, 100 % de la largeur** sur téléphone et dans la coque Android : en haut « Mon compte » (16 px, 500) et la croix de fermeture (44 px). **Sur ordinateur (≥ lg) : panneau latéral droit de 400 px** (porteur, 2026-10-24), pleine hauteur, voile `bg-ink/40`, même contenu.
- En-tête : avatar 56 px, nom (18 px, 500), dessous « Math · PC · CSMT » : noms courts des matières puis sigle de l'établissement courant (13 px `text-mute`). Noms courts : clé partagée `shared.subjects.short` (déplacée depuis `classroom.student_homes.subjects.short`), sinon le nom entier ; sans sigle, le nom de l'établissement.
- **Établissement en cours** (dès deux établissements) : libellé 12 px majuscules, puis une ligne par établissement (sigle 14 px, nom 13 px `text-mute`, bouton radio) ; l'établissement courant est `border-brand-strong bg-brand-soft`. Toucher une ligne change l'établissement courant (action actuelle, UDR-0098).
- Entrées, dans cet ordre, ligne ≥ 56 px, rond 40 px `bg-brand-soft` avec icône au trait `text-brand-strong`, chevron :
  1. **Mon profil**
  2. **Modifier mon code secret**
  3. **Ajouter une matière** — dessous « 2 sur 3 »
  4. **Ajouter un établissement** — dessous « 2 sur 3 »
  5. **Mode sombre** — interrupteur `role="switch"`
  6. **Se déconnecter** — `text-brand-strong`, sans chevron
- **Retiré** : « Inviter un collègue » (il est dans la grille de l'accueil).
- **À 3 sur 3**, l'entrée passe en gris : rond `bg-mist`, icône et libellé `text-mute`, dessous « 3 sur 3 · retire-en un pour en ajouter ». Elle reste active et ouvre l'**écran de retrait** correspondant.
- Sous 3 : « Ajouter une matière » ouvre la modale « Mes matières » existante (`identity/profile_materials/edit`) ; « Ajouter un établissement » ouvre l'ajout par code existant (`school/teacher_schools`).

**Écrans de retrait** (une vue nouvelle sous `identity/profile_materials` et sous `school/teacher_schools`) : « ‹ Mon compte », titre « Mes matières » / « Mes établissements » (18 px), dessous « 3 sur 3. Retirez-en une pour en ajouter une autre. » ; une ligne par élément avec un bouton `secondary` `sm` « Retirer » ; l'établissement courant porte la pastille « En cours ». Note en bas, `bg-mist rounded-ln`, 13 px `text-mute` :
- matières : « Les exercices déjà assignés restent visibles par vos élèves. » « Retirer » appelle `UpdateTeacherMaterials` avec la liste sans cette matière ; **la dernière matière n'a pas de bouton** (`TeacherMaterials::MIN`).
- établissements : « Vos classes et devoirs en cours dans l'établissement retiré sont archivés. » « Retirer » appelle `LeaveSchool` après confirmation (`ui_confirm`) ; **le dernier établissement n'a pas de bouton**.

**Profil enseignant** : la ligne Matières perd son action « Modifier » (une seule place : le menu).

#### Écrans de retrait sur ordinateur (≥ lg)

Option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : « Mes matières » et « Mes établissements » **s'ouvrent dans le panneau latéral de 400 px**, à la place du menu, sans fermer le panneau ni quitter la page en dessous. « ‹ Mon compte » ramène au menu dans le même panneau ; Échap, la croix ou un clic sur le voile ferment le panneau. Contenu, note et confirmation (`ui_confirm`) identiques au téléphone. Après un retrait, le panneau reste ouvert sur l'écran de retrait, ligne retirée et compteur à jour (Turbo Stream).

### 3.5 Page de classe (`classroom/classrooms/show.html.erb` et partiels)

- Haut : « ‹ Accueil » ; titre « Tle D 1 » (18 px), « CSMT · 2026-2027 » (13 px `text-mute`) ; logo enseignant 24 px à droite.
- `_link` : carte « Inscrire vos élèves » + ⋮ (changer le lien, inchangé), phrase 13 px « Ils s'inscrivent avec le lien, classe déjà choisie. », boutons « Partager sur WhatsApp » (`primary`) et « Copier le lien » (`secondary`). **Aucune ligne de code de classe** sur cette page.
- `_session_days` (« Vos jours de séance ») : **masqué** pour le pilote (le partiel n'est plus rendu ; routes et données gardées).
- `_assigned_exercises` : lignes au format de « Cette semaine » (§3.3 : barre, « N / M faits », pastille retard ou pas encore).
- `_gaps` (Fiches à revoir) : inchangé, après les exercices.
- `_roster_title` : « 20 élèves », **sans « sur 80 »** ni plafond expliqué.
- **Sur ordinateur (≥ lg)** : deux colonnes égales — à gauche « Inscrire vos élèves », exercices assignés, Fiches à revoir ; à droite « 20 élèves », recherche, filtres et liste. « Mes classes » est actif dans la barre latérale.
- `_roster` : recherche inchangée ; **filtres par badge** à la place des groupes de notes : puces « Tous · Bronze · Argent · Or · Diamant · Pas encore » (34 px de haut, zone tactile 44 px, défilement horizontal, puce active `bg-brand-strong text-white`), paramètre `badge=` dans le frame `classroom_roster_list`. Ligne : initiales 36 px, nom 14 px, « 9 faits sur 18 » 13 px (+ « · 1 en retard » `text-warning`), pastille du badge à droite « Or · 15/20 » (§3.1) ou « Pas encore » `text-mute`.

### 3.6 Fiche d'un élève (`classroom/classroom_students/show.html.erb`)

- « ‹ Tle D 1 » ; avatar 56 px, nom 18 px ; dessous « Numéro 07 •• •• •• 56 · Arrivée le 12 oct. » (numéro masqué comme aujourd'hui, jamais complet ; « Arrivé » ou « Arrivée » selon le genre). La classe n'est pas répétée : elle est dans le lien de retour.
- `_summary` : « 9 faits sur 18 » + pastille « 1 en retard » ; puis la pastille **« Moyenne 14/20 · Or »** (`bg-brand-soft text-brand-strong`, le badge qui range l'élève, §3.2), puis les badges obtenus par exercice, nommés et comptés (« Or 4 »), zéro caché. « Fragile » et « Acquis » disparaissent de la fiche.
- `_assignments` (Exercices de la classe), `_self_practice` (Fait seul · 30 derniers jours), code de récupération et « Retirer de la classe » (`_manage`) : gardés. Note d'un exercice en pastille neutre avec trophée ; non fait et échu : pastille « En retard ».

#### Sur ordinateur (≥ lg)

Option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : « Mes classes » actif dans la barre latérale ; « ‹ Tle D 1 », avatar, nom et ligne du numéro en pleine largeur, puis **deux colonnes égales** (contenu de 57 rem au plus, comme la page de classe) :
- à gauche : `_summary` (faits, retard, « Moyenne 14/20 · Or », badges obtenus), puis `_manage` (code de récupération, « Retirer de la classe ») ;
- à droite : `_assignments`, puis `_self_practice`.
Même contenu qu'au téléphone, rien de répété ; seul l'ordre change (le bloc de gestion monte dans la colonne de gauche).

### 3.7 Cours (`catalog/courses/index.html.erb`, enseignant)

- S'ouvre depuis un rond de niveau (`level`, `series` dans l'URL). « ‹ Accueil » en haut ; titre **« Cours de Tle D »** (18 px) ; sans niveau dans l'URL, « Cours ».
- **Retirés** pour l'enseignant : les menus Niveau et Série, « Tle D » sur chaque ligne.
- Gardés : recherche ; « 3 fiches de cours · Mathématiques · Progression DPFC 2026-2027 » (13 px, une seule fois) ; pastille « En cours ». Les fiches de cours sont des cartes qui portent leurs fiches de révision (amendement du 2026-10-24, ci-dessous).
- Bivalent : puces de matière (« Math · PC », noms courts) sous la recherche, la première active. Monovalent : pas de puces.
- **Amendé le 2026-10-24** (porteur, en dessinant l'ordinateur, réponse « A » : valable aussi sur téléphone) : les trois règles ci-dessous (puces limitées à l'établissement courant, une matière à la fois, fiches de révision dans la carte) s'appliquent **au téléphone comme à l'ordinateur** ; elles remplacent les « lignes compactes » de l'élève pour l'enseignant. Seule la largeur change d'un appareil à l'autre.

#### Sur ordinateur (≥ lg)

Option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px), avec trois précisions (valables aussi sur téléphone, voir ci-dessus) :
- **Une colonne** de 40 rem au plus, centrée ; « Cours » actif dans la barre latérale ; les fiches de cours dans l'ordre de la progression, de haut en bas (pas de grille).
- **Puces de matière : seulement les matières que l'enseignant enseigne dans l'établissement courant** (`teacher_scope.materials`), jamais toutes celles du catalogue ; une seule matière, pas de puces.
- **Une seule matière à la fois** : la page ne montre que les fiches de cours de la matière de la puce active, sans en-tête de matière ni regroupement.
- **Une carte par fiche de cours, qui porte ses fiches de révision** : en tête « LEÇON 2 » (12 px majuscules `text-mute`), titre 14 px `font-medium`, pastille « En cours » s'il y a lieu et chevron, le tout lien vers la fiche de cours ; dessous « Révisions de la leçon » (13 px `text-mute`, UDR-0130 exception 2), puis une ligne de 44 px par fiche de révision (titre 14 px, chevron), lien vers la fiche de révision, où se trouve « Assigner » (§3.13). Fiche de cours sans fiche de révision : la carte n'a que son en-tête.

### 3.8 Rapport d'un exercice (`classroom/assignment_follow_ups/show.html.erb`, `assessment/comprehension/_section`)

- « ‹ Tle D 1 » ; rond 56 px + titre 18 px + « Math · 10 questions · à rendre ven. 30 oct. » ; « Voir l'exercice » `secondary` pleine largeur.
- Barre « 20 / 27 faits » (§3.1) + pastille « 7 en retard » (ou « pas encore »), cachée à zéro. Les trois chiffres en `dl` actuels sont remplacés par cette ligne.
- **Cinq cases par badge**, pour les élèves qui ont fait l'exercice : Pas encore · Bronze · Argent · Or · Diamant. Case : trophée 18 px (espace vide pour « Pas encore »), nombre 18 px, libellé 12 px, bordure `border-line`. Chaque case est un lien du Turbo Frame (`?badge=`), comme les catégories d'aujourd'hui.
- Correspondance avec UDR-0072 : En difficulté → Pas encore ; Fragile → Bronze ; Acquis → Argent, Or ou Diamant. Le grand cercle disparaît.
- **Prochain geste** : carte `bg-brand-soft`, libellé « PROCHAIN GESTE » 12 px `text-brand-strong`, texte 14 px qui parle en badges (« 4 élèves n'ont pas encore de badge. Reprenez la question 3 en classe, puis relancez-les. »). Les clés i18n du prochain geste sont réécrites dans ce vocabulaire.
- **Sur ordinateur (≥ lg)** : « Voir l'exercice » à droite du titre ; deux colonnes égales — à gauche progression, cases par badge, prochain geste et questions ; à droite la liste des élèves.
- Questions (barre de réussite, « 18 / 20 justes ») et élèves (lien vers la fiche, pastille de note avec trophée, « En retard » si non fait et échu) : gardés.

### 3.9 Inscription (`identity/teacher_registrations/new.html.erb`, `_form`)

- **Trois étapes avec `classroom/signup_steps_controller.js`**, celui de l'élève : 1. Votre établissement → 2. Vous → 3. Votre code secret. Règles de l'UDR inscription élève §3.1, §3.5 et §3.8 : un seul formulaire, envoi à l'étape 3, une erreur serveur rouvre l'étape du champ fautif, sans JavaScript les trois blocs restent visibles.
- Haut : logo enseignant 32 px à gauche, « Besoin d'aide ? » à droite ; « ‹ Retour » (étapes 2 et 3) et « Étape N sur 3 » ; trois segments (remplissage §3.1).
- Étape 1 (premier écran) : carte « Bienvenue sur Lnclass » (`bg-brand-strong`, texte blanc) « Assignez un exercice, voyez ce que vos élèves ont compris. » ; titre « Créer votre compte enseignant » ; « Votre établissement », « Vous passez à la suite dès que l'établissement est choisi. » ; DRENA et Établissement (`_school_fields`, inchangés) ; passage automatique dès l'établissement choisi ; « Déjà un compte ? Se connecter ».
- **Lien d'invitation** (DRENA et établissement préremplis) : ouverture directe à l'étape 2, avec la carte de rappel « VOTRE ÉTABLISSEMENT · Collège Saint-Michel de Treichville · Ce n'est pas votre établissement ? › » (retour à l'étape 1). Carte de bienvenue et « Déjà un compte ? » sur cet écran.
- Étape 2 : « Vous », « Vous passez à la suite dès que tout est rempli. » ; Nom, Prénom(s), Genre (boutons « M. » / « Mme »), Numéro, **Matière** (une seule) avec l'aide « Vous pourrez ajouter d'autres matières dans Mon compte. ». **« Autre matière (facultatif) » est retiré.** Passage automatique ≈ 1 s après la dernière frappe, comme l'élève.
- Étape 3 : « Votre code secret », « 4 chiffres, pour vous connecter. », Code secret et confirmation, « Créer mon compte » (`primary`, pleine largeur).
- Vouvoiement partout (l'élève est tutoyé).

#### Sur ordinateur (≥ lg)

Option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : **deux colonnes égales**, la mise en page actuelle de l'inscription enseignant.
- À gauche, panneau **`bg-teacher`** pleine hauteur (choix B du porteur en couleurs, 2026-10-24, contre la recommandation d'un panneau `bg-mist`) : textes en `text-band-ink` (blanc en sombre, §3.1), logo enseignant 64 px cerné d'un anneau blanc de 3 px pour se détacher du jaune, « Bienvenue sur Lnclass », « Assignez un exercice, voyez ce que vos élèves ont compris. », centrés. **La carte de bienvenue du téléphone n'est pas rendue à droite** : elle ne vit qu'à un endroit.
- À droite, les trois étapes, largeur 28 rem au plus, centrées : « Besoin d'aide ? » en haut à droite, « ‹ Retour », « Étape N sur 3 », segments, puis le contenu de l'étape, inchangé. Le logo de l'en-tête du téléphone n'est pas répété (il est à gauche).

### 3.10 Jetons

Uniquement les jetons de l'UDR palette, plus `teacher` pour les trois usages de §3.1. Graisse 500 au plus, minimum 12 px, rien en dur (`test/design/design_tokens_test.rb`).

### 3.11 États obligatoires

- **Vide** : aucune classe (carte « + Ajouter une classe » seule) ; classe sans élève ; aucun exercice cette semaine ; pas d'historique ni d'annonce (sections absentes) ; sans matière (`_choose_materials`).
- **Chargement** : frames existants (liste de la classe, cases du rapport) avec squelette `bg-mist`.
- **Erreur** : retrait impossible (dernière matière, dernier établissement : pas de bouton ; refus serveur : message sous la ligne) ; « Copier » sans presse-papiers : le code reste sélectionnable ; inscription : §3.9.
- **Succès** : code copié (annonce `aria-live`) ; matière ou établissement retiré (ligne retirée en Turbo Stream, compteur « 2 sur 3 » à jour).

### 3.12 Accessibilité

- Cibles ≥ 44 px : en-tête de carte de classe, « Copier », ronds, puces de filtre, cases du rapport, « Voir plus », entrées du menu.
- Titres de section de l'accueil en `h2 sr-only` ; carrousel de classes `ul aria-label="Mes classes"` ; grille `nav aria-label="Cours par niveau"`.
- Chaque pastille de badge se lit « 3 élèves Or » (clé `assessment.comprehension.badge_count`).
- Menu : `role="dialog"` plein écran, focus sur son titre à l'ouverture, retour du focus sur l'avatar à la fermeture ; interrupteur `role="switch" aria-checked`.
- Contrastes : `band-ink` sur `teacher` 6,2:1 ; blanc sur `teacher` sombre 6,0:1 ; les autres, ceux de l'UDR palette.

### 3.13 Premier parcours : accueil vide, déclarer ses classes, assigner, jours de séance

Validé par le porteur le 2026-10-23 sur maquettes ; option A pour les jours de séance.

**Accueil sans classe** (`classroom/teacher_homes/_classroom_card` ou partiel `_no_classroom`, Lot G) : la carte du haut, à cheval sur le bandeau, porte l'en-tête « CSMT » (sigle seul), le titre « Ajoutez vos classes », la phrase « Cochez les classes où vous enseignez : chacune reçoit un code à donner à vos élèves. » et un bouton **`primary` pleine largeur** « + Ajouter une classe » vers `teacher_classrooms_path`. Grille : le rond « Inviter » seul (les ronds de niveau viennent des classes). « Cette semaine » : « Aucun exercice à suivre cette semaine. ». Historique absent.

**Déclarer ses classes** (`classroom/teaching_selections/index`, `_level_group`) : « ‹ Accueil » ; titre « Quelles classes enseignez-vous ? » (18 px) ; « Cochez vos classes au CSMT. Vous pourrez en ajouter plus tard. » ; pastille compteur « 3 classes cochées » (`bg-brand-soft text-brand-strong`) ; une carte par niveau (rond 40 px avec l'icône du niveau, nom 16 px, « 4 classes » 12 px), une ligne de 52 px par classe avec une **case à cocher** à droite (cochée : `bg-brand-strong`, coche blanche) ; bouton `primary` pleine largeur « Terminer » (fin de l'onboarding, comportement actuel), qui mène à l'accueil. La bascule par Turbo Stream et le compteur actuels sont gardés.
- **Sur ordinateur (≥ lg)** — option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : « Accueil » actif dans la barre latérale ; contenu de 57 rem au plus ; titre, phrase et compteur en pleine largeur, puis les cartes de niveau en **deux colonnes** (`columns-2`, une carte ne se coupe jamais entre deux colonnes, ordre des niveaux de haut en bas puis colonne suivante) ; « Terminer » `primary` de 15 rem, aligné à droite sous les cartes.

**Fiche de cours et « Assigner »** (`catalog/essentials/_exercise_progress`, `classroom/assignments/_toggle` compact) : sous chaque exercice (titre 14 px, « QCM · 10 questions » 13 px), une ligne par classe enseignée du niveau, 52 px, séparée par `border-line` :
- non assignée : nom de la classe à gauche, bouton « Assigner » à droite ; **le premier bouton « Assigner » de la page est `primary`, les suivants `secondary`** ;
- assignée : nom de la classe, dessous « À rendre jeu. 29 oct. » (12 px `text-mute`, `due_for_teacher`), à droite la pastille « ✓ Assigné » (`bg-brand-soft text-brand-strong`) et ✕ (retirer, 44 px, comportement actuel) ;
- sous la dernière ligne assignée d'une classe qui a des jours de séance, le lien discret « Modifier les jours de la Tle D 1 » (13 px `text-brand-strong`), qui ouvre la fenêtre des jours (`edit_classroom_session_days_path`, frame `modal`).
- **Sur ordinateur (≥ lg)** — option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : « Cours » actif dans la barre latérale ; **deux colonnes** — à gauche la fiche de révision (titre, méta, contenu), largeur libre ; à droite une colonne de 380 px, carte `border-line rounded-card`, titre « Exercices », qui **reste visible au défilement** (`lg:sticky lg:top-8`) et porte les exercices et leurs lignes par classe, inchangées (premier « Assigner » `primary`, « ✓ Assigné », ✕, « Modifier les jours de la … »). Plus haute que l'écran, la colonne défile seule (`overflow-y-auto`, hauteur maximale en jeton, aucune valeur arbitraire). Sur téléphone, les exercices restent sous la fiche.

**Fenêtre des jours de séance** (`classroom/assignments/new`, `classroom/session_days/edit`) : feuille du bas (`rounded-t-sheet`, poignée), titre « Quels jours voyez-vous la Tle D 2 ? » (18 px), « L'exercice sera à rendre à votre prochaine séance. Vous ne le dites qu'une fois par classe. » ; six jours en 3 colonnes, pilules de 44 px, cochée `bg-brand-soft border-brand-strong text-brand-strong` ; ligne « Prochaine séance : lundi 26 oct. », recalculée à chaque case cochée (Stimulus ; sans JavaScript, absente) ; boutons « Annuler » (`secondary`, ferme sans rien écrire) et « Assigner » (`primary`) — « Enregistrer » dans `session_days/edit`.
- **Option A, choix du porteur** : **« Plus tard » est retiré.** Assigner dans une classe sans jours de séance exige au moins un jour ; sans jour coché, la fenêtre revient en 422 avec l'erreur sous les jours (comportement actuel). Toute assignation a donc une échéance.
- **Sur ordinateur (≥ lg)** — option A du porteur (2026-10-24, maquettes en gris à 1440 et 1024 px) : la fenêtre est une **modale centrée** de 30 rem (`ui_modal placement: :sheet, size: :form`, qui est déjà une feuille du bas sous lg et une modale centrée au-dessus), voile sur la fiche ; même contenu, mêmes boutons côte à côte. Échap et « Annuler » ferment sans rien écrire ; le focus revient sur le bouton « Assigner » ou le lien « Modifier les jours » qui l'a ouverte.
- « Vos jours de séance » reste masqué sur la page de classe (§3.5) : **la fenêtre est le seul endroit** où l'on règle et corrige les jours, depuis « Modifier les jours de la … » de la fiche.
- Les assignations déjà créées sans échéance (« Plus tard » avant le pilote) gardent `due_on` nul : elles sont dans « Cette semaine » tant qu'un élève ne les a pas faites, sans pastille de retard.

## 4. Conséquences

- **Amende l'ADR-0103 §4.4, puce « Inscription »** : l'inscription ne demande plus que `material_slug` ; `second_material_slug` quitte le formulaire, le DTO et `RegisterTeacher`. Le plafond de 3 matières (`TeacherMaterials::MAX`, déjà en place) et `UpdateTeacherMaterials` ne changent pas : les matières 2 et 3 passent par « Ajouter une matière ».
- Le badge d'un élève dans une classe (§3.2) est une règle nouvelle : elle vit dans le domaine, avec son test.
- `TeacherFollowUpsQuery` se partage en deux lectures (cette semaine, historique avec moyenne de classe) ; la query de l'accueil ajoute le sigle, le code et les compteurs de badges par classe ; la liste de la classe ajoute le badge par élève et le filtre `badge=`.
- Interdit sur les écrans enseignant : une barre basse ; « Inviter un collègue » ailleurs que dans la grille ; la liste des classes ailleurs que sur l'accueil ; un rangement des élèves autre que le badge ; `bg-brand` sur une barre ou un bandeau ; du rouge sur une note.
- L'assignation sans jours de séance n'est plus possible : l'attribut `later` disparaît de `Dtos::Classroom::AssignmentInput` et du contrôleur (Lot L, avec son test).
- Versions ordinateur : dessinées le 2026-10-24 dans les sous-sections « Sur ordinateur (≥ lg) » de chaque écran. **Couleurs validées par le porteur (option A)** : les écrans ordinateur appliquent §3.1 et l'UDR palette sans ajout ; seule nouveauté, le panneau gauche jaune de l'inscription (§3.9). L'entrée active de la barre latérale reste `bg-brand-soft text-brand-strong`.
- Hors de cette UDR : direction et équipe inchangées, sauf leur fond (UDR palette).
