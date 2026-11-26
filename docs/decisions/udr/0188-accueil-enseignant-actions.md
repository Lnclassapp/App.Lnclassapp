# UDR-0188 : Accueil enseignant tourné vers l'action — « À suivre », ronds nommés, barre du haut sur l'accueil seulement, liste des élèves par état, relance WhatsApp
<!-- index
titre: Accueil enseignant « À suivre », ronds nommés, barre du haut sur l'accueil seulement, élèves par état, relance WhatsApp
statut: Accepté
adr-lie: —
problematique: L'accueil de l'enseignant cache la classe en retard (carrousel), ses ronds ne disent pas ce qu'ils ouvrent, ses pages répètent la barre du haut, la liste d'une classe répète une ligne par élève et la relance n'a pas de bouton. Amende UDR-0006, UDR-0082 §3.1, UDR-0134 §3.3, §3.5, §3.8, §3.14
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-26, sur maquettes, transmis par la session d'orchestration) |
| **Date** | 2026-11-26 |
| **Chantier** | `docs/chantiers/accueil-enseignant-actions` |
| **ADR lié** | — |
| **Amende** | UDR-0006 (en-tête du shell), UDR-0082 §3.1 (en-tête de l'enseignant), UDR-0134 §3.3 (accueil), §3.5 (page de classe), §3.8 (rapport), §3.14 (barre du haut sur ordinateur) |
| **Remplacé par** | — |

---

## 1. Contexte

Audit du 2026-11-26 (test-ecrans, jeu standard, enseignant `0500000011`, 14 classes) : sur l'accueil, la classe en retard (Tle D, 38 élèves sur 40) n'apparaît qu'après une dizaine de glissements du carrousel ; les ronds de niveaux portent tous la même calculatrice et rien ne dit qu'ils ouvrent les fiches de cours ; « Aucun exercice à suivre cette semaine » s'affiche seul. Sur chaque page intérieure, la barre du haut redit l'accueil alors que la page a son retour. Sur la page d'une classe, quarante lignes « Pas encore · 0 fait sur 1 · 1 en retard » ; sur le suivi d'un devoir, « Relancez les 38 élèves » sans moyen de le faire.

## 2. Décision

1. **Accueil : « À suivre » d'abord.** Une liste plate (style Wave) des seules classes qui ont quelque chose à suivre, la plus urgente en premier, une ligne par classe ; les autres se déplient en dessous. Une liste plutôt qu'un carrousel : on lit l'urgence d'un coup d'œil, sans geste.
2. **Ronds nommés.** Un titre visible dit ce qu'ils ouvrent ; chaque rond porte le nom court de son niveau sur une teinte propre, au lieu d'une illustration identique.
3. **Jamais de section vide** : « Cette semaine » vide n'est pas rendue.
4. **Barre du haut sur l'accueil seulement**, pour l'enseignant. Chaque page intérieure a déjà son retour en tête : la barre n'y ajoute qu'un doublon. La barre latérale sur ordinateur reste (option prudente, à trancher par le porteur).
5. **Liste des élèves par état** : deux chiffres en tête, les élèves en retard d'abord, une ligne = un nom et un état, dix lignes puis « Voir plus (n) ».
6. **« Relancer sur WhatsApp »** dans « Prochain geste » : un lien de partage `wa.me` prérempli ; l'enseignant choisit le groupe de sa classe. Lnclass n'envoie rien.

Le code de la classe, qui n'était plus que sur la carte du carrousel (UDR-0134 §3.5, CA-I1), revient dans le bloc « Inscrire vos élèves » de la page de la classe.

## 3. Règles d'implémentation

### 3.1 Accueil — section « À suivre » (`classroom/teacher_homes/_to_follow.html.erb`, remplace le carrousel et `_classroom_card`)

```
section#teacher_home_classrooms  (lg:col-span-2)
├── h2#teacher_home_classrooms_title   « À suivre » | « Mes classes »   (visible, font-display text-base font-medium text-ink)
├── ul#teacher_home_to_follow          carte blanche groupée : divide-y divide-line rounded-card border border-line bg-white shadow-card
│   └── li#classroom_<public_id>       une ligne par classe à suivre
└── details#teacher_home_other_classrooms   (s'il reste des classes)
    ├── summary                        « Voir mes 12 autres classes » / « Voir mon autre classe »
    └── ul                             mêmes lignes, puis « + Ajouter une classe »
```

- Le bandeau de l'accueil et le débord sur le bandeau sous lg restent (`-mt-20` sur la grille) : la section devient une carte, posée à cheval sur le bandeau comme le carrousel avant elle. Le titre est **au-dessus** de la carte, sur le bandeau sous lg (`text-band-ink`), `text-ink` dès lg.
- **Classe à suivre** : au moins un élève présent **et** (au moins un élève en retard **ou** au moins une assignation active). En retard = élève présent qui n'a pas terminé une assignation active dont l'échéance est passée (avant aujourd'hui, jour d'Abidjan), comme la liste de la classe.
- **Ordre (urgence)** : élèves en retard, décroissant ; puis assignations actives, décroissant ; puis l'ordre des classes (position du niveau, nom naturel).
- **Ligne** (`li`, `relative flex min-h-14 items-center gap-3 px-4 py-3 active:bg-mist`) :
  - lien `classroom_path` sur le nom (14 px, 500, `text-ink`, `after:absolute after:inset-0` : toute la ligne est cliquable), `aria-label` absent : le texte suffit ;
  - dessous 13 px : en retard → « 38 élèves en retard sur 1 exercice » en `text-warning` ; sinon « 4 exercices en cours » `text-mute` ; classe sans rien à suivre (dans les autres classes) → « 40 élèves » `text-mute`, « Aucun élève » pour une classe vide ;
  - chevron `chevron-right` mini `text-mute` à droite, `aria-hidden`.
- **Autres classes** : `<details>` natif (marche sans JavaScript), `summary` en lien discret 14 px `text-brand-strong` avec chevron `chevron-down` (`group-open:rotate-180`), zone ≥ 44 px, centré, sous la carte. Contenu : la même carte de lignes, ordre des classes, puis une dernière ligne « + Ajouter une classe » (`text-brand-strong`) vers `teacher_classrooms_path`.
- **Aucune classe à suivre** (mais des classes) : titre « Mes classes », la carte montre les trois premières classes, `details` pour les suivantes (« Voir mes N autres classes »), la ligne « + Ajouter une classe » à la fin de la dernière carte visible.
- **Toutes à suivre** : pas de `details` ; la ligne « + Ajouter une classe » termine la carte « À suivre ».
- **Aucune classe** : la carte « Ajoutez vos classes » du §3.13 d'UDR-0134 (`_add_classroom_card`, `empty: true`), sans titre ni liste, rendue dans un `div` (plus de `li` de carrousel).
- Retirés : `communication--carousel` des classes, `_classroom_card` (code, badges, « Copier »), les points et les boutons « Classes précédentes / suivantes ».

### 3.2 Accueil — ronds de niveaux (`_course_levels`, `components/_subject_bubble`)

- Titre visible au-dessus des ronds : `h2#teacher_home_courses_title` « Fiches de cours · Mathématiques » (une matière) ou « Fiches de cours » (plusieurs), même style que le titre du §3.1.
- Rond de niveau : `ui_subject_bubble(text: "Tle D", tint: …)` — **variante texte** : le rond de 60 px porte le nom court (14 px, 600, `text-ink`, `leading-none`) au lieu de l'illustration ; le libellé sous le rond est retiré à l'écran (lu par `sr-only` avec son suffixe « fiches de cours de Mathématiques »).
- Teintes en rotation, dans l'ordre des ronds : `bg-tint-indigo`, `bg-tint-green`, `bg-tint-yellow`, `bg-tint-pink`, `bg-tint-lilac`, `bg-tint-red`, `bg-tint-lavender` (`CourseLevelTints`), puis on recommence. Les jetons `tint-*` ont leur valeur sombre (thème sombre) : aucune couleur en dur.
- Nom court (`Entities::Classroom::LevelShortName`) : « 6ème » → « 6e », « 5ème » → « 5e », « 2nde » → « 2de », « 1ère » → « 1re », « Tle » → « Tle », suivi de la série : « 2de A », « 1re D », « Tle D ».
- Le rond « Inviter » ne change pas (illustration, libellé dessous).

### 3.3 Accueil — section vide

- `_follow_ups` n'est **pas rendu** si `follow_ups` est vide et que l'enseignant a des matières. Sans matière, `_choose_materials` reste (c'est une invitation, pas une section vide). « Historique » prend alors les deux colonnes dès lg.

### 3.4 Barre du haut sur l'accueil seulement (`layouts/shell`, amende UDR-0006, UDR-0082 §3.1, UDR-0134 §3.14)

- Pour le rôle `teacher`, `shared/navigation/_header` n'est rendu que si la page pose `content_for :home_band` (l'accueil enseignant). Ailleurs : ni barre du haut, à aucune largeur. L'inscription (utilisateur nil) ne change pas.
- La barre latérale (`_sidebar`) reste dès lg, inchangée. Pas de barre basse (inchangé).
- Chaque page enseignant commence par un retour : `ui_back_link` ou `ui_page_header(back:)`. Ajoutés : « Reçues » (`communication/inboxes/show`, « ‹ Accueil » pour l'enseignant), « Mes annonces » (`communication/authored_messages/index`, idem), « Rejoindre un établissement » (`school/teacher_school_joins/new`, « ‹ Accueil »), « Mon compte » en page (`classroom/teacher_menus/show`, « ‹ Accueil »). Les modales servies en page sans JavaScript (« Mes matières » en édition, jours de séance) gardent leur « Annuler » et n'en ont pas.
- Le panneau « Mon compte » (la `<dialog>` de l'en-tête) ne s'ouvre donc plus que depuis l'accueil, dès lg ; sous lg, l'avatar du bandeau mène à `/teachers/menu` (inchangé). Hors accueil, « Mon compte » reste à un retour.
- La barre latérale part du haut (`top-0`) quand la barre du haut est absente.
- Direction, équipe, élève : inchangés.

### 3.5 Page de la classe — code (`classroom/classrooms/_link`, amende UDR-0134 §3.5)

- Sous la phrase « Ils s'inscrivent… », un encadré `div#classroom_code` : bordure pointillée `border-line-strong`, `rounded-ln`, `p-3`, « Code de la classe » (12 px `text-mute`) et le code en `font-mono text-base font-medium tracking-widest select-all`, `ui_copy_button` « Copier » à droite (annonce « Code copié »). Même condition d'affichage que le bloc.

### 3.6 Page de la classe — liste des élèves (`classroom/classrooms/_roster`, amende UDR-0134 §3.5)

- Sous le titre « 40 élèves » et avant la recherche : `p#classroom_roster_summary` « **38 en retard** · **2 à jour** » (14 px ; le premier nombre en `text-warning` s'il est positif ; sans exercice assigné : rien). Les chiffres sont ceux de toute la classe, quels que soient recherche et filtre.
- Ordre : en retard d'abord, puis nouveaux, puis nom (le reste de l'ordre d'UDR-0081 §3.7 ne change pas).
- Ligne (`li`, `min-h-11`) : le lien photo + nom (UDR-0108) et, à droite, l'état : « En retard » `ui_badge tone: :warning, dot: true, size: :sm` ou « À jour » `text-sm text-mute` ; sans exercice assigné, rien. Retirés de la ligne : « N faits sur M », « · N en retard », la médaille.
- Pagination : 10 élèves par page (`PER_PAGE`), puis `ui_button` « Voir plus (n) », n = élèves restants (frame `classroom_roster_list`, comportement d'UDR-0108 §3.3 inchangé).
- Recherche, filtres par médaille et leurs états vides : inchangés.
- Sur ordinateur, les deux colonnes restent ; la liste bornée à dix lignes équilibre leur hauteur.

### 3.7 Suivi d'un devoir — relance (`assessment/comprehension/_section`, amende UDR-0134 §3.8)

- Local `remind_url:` (nil par défaut) : rendu par `classroom/assignment_follow_ups/show` pour l'enseignant seulement, quand il reste des élèves qui n'ont pas fait l'exercice (`pending_students.any?`).
- Dans `#comprehension_next_step`, sous le texte : `ui_button` « Relancer sur WhatsApp » `id: comprehension_remind`, `variant: :primary`, `size: :sm`, `icon: "chat-bubble-left-right"`, `href: whatsapp_share_url(message)`, `target: _blank`, `rel: noopener`.
- Personne n'a fait l'exercice (état vide du rapport, pas de « Prochain geste ») : le même bouton est l'action de l'état vide.
- Message (`assessment.comprehension.remind.message`) : « %{classroom} : pensez au devoir « %{exercise} », à rendre le %{due}. Ouvrez-le ici : %{link} » ; sans échéance : « … pensez au devoir « %{exercise} ». Ouvrez-le ici : %{link} ». `link` = `exercise_url` de l'exercice. Aucun nom d'élève.

### 3.8 États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| À suivre | §3.1 (Mes classes / Ajoutez vos classes) | rendu serveur | page d'erreur standard | §3.1 |
| Ronds | « Choisissez vos matières » (inchangé) | — | — | §3.2 |
| Liste des élèves | états existants | frame `aria-busy` | `ui_error_state` existant | §3.6 |
| Relance | bouton absent | — | — (lien sortant) | WhatsApp s'ouvre |

### 3.9 Accessibilité

- Cibles ≥ 44 px (lignes, `summary`, bouton). Focus visible `outline-brand` sur les liens de ligne et le `summary`.
- Les ronds texte : le nom court est `aria-hidden`, le nom entier et le suffixe sont lus (`sr-only`), `title` porte le nom entier.
- « 38 en retard · 2 à jour » est un texte lu tel quel ; l'état d'une ligne est du texte, pas une couleur seule.

## 4. Conséquences

- Hors accueil, l'enseignant n'a plus « Mon compte » ni « Besoin d'aide ? » sur le site (l'accueil est à un geste) ; la coque Android garde les siens.
- La carte de classe, ses badges de médailles et son code quittent l'accueil ; le code vit sur la page de la classe.
- Toute nouvelle page enseignant doit commencer par un retour (§3.4).
- La liste d'une classe ne montre plus la médaille par ligne : le filtre par médaille la donne.
