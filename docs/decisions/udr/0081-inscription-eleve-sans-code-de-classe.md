# UDR-0081 : Inscription élève sans code — une cascade de quatre listes, un lien de classe, les nouveaux arrivés marqués et le retrait d'un élève
<!-- index
titre: Inscription élève sans code : cascade de quatre listes, lien de classe, nouveaux arrivés marqués, retrait d'un élève
statut: Accepté *(porteur, 2026-10-07)* — *remplace 0009 (Lot F, 2026-10-08) ; amendée le 2026-10-08 : nom et prénoms en deux champs*
adr-lie: [0083](../adr/0085-inscription-eleve-sans-code-de-classe.md), [0083](../adr/0083-inscription-enseignant-en-deux-voies.md)
problematique: Trois rubriques (Ta classe → Toi → Code secret) ; partial `_class_picker` (DRENA → établissement → niveau → classe), états vide, chargement, introuvable, erreur ; lien `/c/<jeton>` avec la classe déjà affichée ; bloc « Lien de la classe » (copier, WhatsApp, changer) ; pastille « Nouveau » et voie d'arrivée dans la liste ; « Retirer de la classe » en modale
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-07 — validation rapportée par le développeur du chantier)* |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/inscription-eleve-sans-code`](../../chantiers/inscription-eleve-sans-code/prd.md) — critères IL-01 à IL-23 |
| **ADR lié** | [ADR-0085](../adr/0085-inscription-eleve-sans-code-de-classe.md) · [ADR-0083](../adr/0083-inscription-enseignant-en-deux-voies.md) · [UDR-0079](0079-inscription-enseignant-en-deux-voies.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0054](0054-finitions-d-interface.md) · remplace [UDR-0009](0009-rejoindre-une-classe.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève n'entre que par le code de sa classe (UDR-0009). Celui dont aucun enseignant n'est sur Lnclass n'a pas de code, et l'écran « Rejoindre une classe » ne lui offre rien d'autre qu'un champ qu'il ne peut pas remplir. L'ADR-0085 retire le code : l'élève choisit sa classe, ou la reçoit par un lien.

L'enseignant, la direction et l'équipe voient aujourd'hui un code à dicter ou à écrire au tableau. Ils reçoivent à la place un lien à partager, et deux gestes qu'ils n'avaient pas : changer ce lien, et retirer un élève.

## 2. Décision

1. **Une seule page**, `/student-signup`, en trois rubriques dans l'ordre du parcours : **Ta classe** (DRENA, établissement, niveau, classe), **Toi** (nom, prénoms, genre, numéro), **Code secret**. Pas d'étapes : même raison que l'UDR-0079 §2.1, et la page marche sans JavaScript.
2. **Quatre listes enchaînées, chacune chargée par le choix de la précédente**, plutôt qu'une recherche : l'élève connaît sa région, son école et son niveau, pas l'orthographe exacte de sa classe (memo Q12). Une liste qui n'a pas encore de parent choisi n'est pas affichée : la page grandit avec les choix.
3. **Par un lien de classe** (`/c/<jeton>`), la même page s'ouvre avec la classe **déjà affichée** dans le bandeau existant (`_classroom_preview`), et « Ce n'est pas ta classe ? » ramène à la page standard. Les quatre listes n'apparaissent pas.
4. **Une classe complète reste visible, désactivée**, plutôt que cachée : l'élève comprend que sa classe existe.
5. **« Introuvable » est un état, pas une erreur** : un message d'orientation remplace la liste (memo Q9).
6. **Nom et prénoms, numéro et code secret** : les règles de l'UDR-0079 §3.3 à §3.5, avec le tutoiement de l'élève. Amendement du 2026-10-08 (memo Q16) : deux champs « Nom » et « Prénom(s) », comme l'enseignant ; plus de nom complet, d'aperçu ni de « Corriger ».
7. **Les nouveaux arrivés se lisent dans la liste des élèves**, par une pastille sur la ligne, plutôt que dans une notification : trois acteurs regardent la même liste (memo Q14).
8. **Retirer un élève passe par une confirmation en modale** qui le nomme : le geste est rare, et il touche une personne.
9. Erreur : page re-rendue en 422 ou 403 par Turbo, saisies gardées sauf les PIN. Succès de l'inscription : la page change, la session vient de naître. Le retrait et le changement de lien répondent par Turbo Stream.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Page `classroom/student_registrations/new`

**Structure**

- La structure en deux colonnes de `classroom/joins/new` (UDR-0009 §3) et la carte `ui_card(padding: :lg)` sont reprises telles quelles. Colonne gauche : « Bienvenue sur Lnclass ».
- Titre de la carte (`h2`) : « Créer ton compte élève ». Sous-titre : « Trois rubriques, une minute. ».
- `@rate_limited` : `ui_error_state` « Trop de tentatives », à la place du formulaire.
- **Lien invalide** (`@link_invalid`) : en tête du formulaire, avant tout `fieldset`, le bloc de l'UDR-0079 §3.1 avec `id="classroom-link-invalid"` et le texte `t(".link_invalid")` : « Ce lien n'est plus valable. Choisis ta classe. ».
- Sous la carte : « Déjà un compte ? Se connecter » (lien existant de `join_codes/new`).

### 3.2 Formulaire `classroom/student_registrations/_form`

- Un seul `form_with model: @form, scope: :student_registration, url: student_registrations_path, id: "student-registration-form"`.
- `data-controller="classroom--class-picker identity--phone-digits identity--pin-match"`.
- Le bloc `role="alert"` des erreurs `base` (classe complète, élève retiré, déjà inscrit) reste en tête du formulaire, classes `bg-error-soft text-error` de l'UDR-0009. *Amendé le 2026-10-08 (challenger de la phase 5)* : après un refus, il reçoit le focus (`tabindex="-1"`, cible `field` du contrôleur `autofocus`) et la page défile jusqu'à lui (`scroll-mt-24`, sous l'en-tête fixe) — sur l'inscription, « Choisis ta classe » et la page du lien.
- Champ caché `link_token`, seulement quand la classe vient d'un lien valide.
- Trois `<fieldset class="space-y-4">`, chaque `<legend>` avec `mb-3 text-xs font-semibold tracking-wider text-mute uppercase` :

| # | Légende (`t`) | Contenu, dans l'ordre |
|---|---|---|
| 1 | « Ta classe » (`.classroom`) | **Voie standard** : partial `_class_picker` (§3.3). **Voie lien** : bandeau `_classroom_preview`, puis lien « Ce n'est pas ta classe ? ». |
| 2 | « Toi » (`.you`) | Nom, Prénom(s) (deux champs, amendement du 2026-10-08), genre (deux radios `min-h-tap`, sans présélection), numéro |
| 3 | « Code secret » (`.security`) | Code secret, confirmation, statut de concordance |

- Puis `ui_button t(".submit")` (« Créer mon compte »), `brand`, `lg`, `full: true`, `id: "student-registration-submit"`.
- **Voie lien** : `link_to t(".other_classroom"), new_student_registration_path, id: "other-classroom"`, classe de `#other-school` (UDR-0079 §3.2).
- Textes de la rubrique 2 : `last_name_placeholder` « Ex. : KOUASSI » ; `first_name_placeholder` « Ex. : Aya Marie » ; erreurs « Saisis ton nom. » et « Saisis ton ou tes prénoms. » (amendement du 2026-10-08 : le nom complet, son aperçu et son erreur d'un seul mot sont retirés).

### 3.3 Cascade `classroom/student_registrations/_class_picker`

Partial partagé par l'inscription (§3.2) et par « Choisis ta classe » (§3.5). Locals : `(form:, drenas:, schools:, levels:, classrooms:, scope:)`.

**Structure**, du haut vers le bas, chaque bloc dans un `div.space-y-4` :

1. **DRENA** : `form.select :drena_public_id, drena_options, { prompt: t(".drena_prompt") }`, libellé « DRENA », `data-action="change->classroom--class-picker#loadSchools"`.
2. `turbo_frame_tag "picker_schools"` : le gabarit `school/drena_schools/index` existant, avec `scope:` ; son `<select>` reçoit `data-action="change->classroom--class-picker#loadLevels"`. Libellé « Établissement ».
3. `turbo_frame_tag "picker_levels"` : `<select name="<scope>[level_slug]">`, libellé « Niveau », invite « Choisis ton niveau », `data-action="change->classroom--class-picker#loadClassrooms"`.
4. `turbo_frame_tag "picker_classrooms"` : un `<fieldset>` de **radios**, `<legend>` « Classe », une ligne par classe : `label.flex.min-h-tap.items-center.gap-3.rounded-ln.border.border-line.px-4` contenant le radio (`name="<scope>[classroom_public_id]"`) et le nom. Classe complète : radio `disabled`, ligne en `opacity-60`, et à droite `ui_badge t(".full")` (« Complète »).

- Les frames 2, 3 et 4 sont **vides** tant que leur parent n'est pas choisi (aucun libellé, aucune liste).
- Chaque frame a la classe `block transition-opacity aria-busy:opacity-50`.
- Sous le sélecteur DRENA, pour le repli sans JavaScript : `<noscript>` avec un bouton secondaire « Continuer » qui soumet la page en `GET` avec les choix faits ; le serveur rend alors la liste suivante dans la page.

**Comportement**

- Contrôleur Stimulus `classroom--class-picker`, sur le modèle de `school--drena-schools`. Valeurs : `schools-url` (`drena_schools_path("__drena__")`), `levels-url` (`school_levels_path("__school__")`), `classrooms-url` (`school_level_classrooms_path("__school__", "__level__")`).
- Chaque `load…` remplace le `src` du frame suivant et **vide les frames d'après**. Changer d'établissement efface le niveau et la classe.
- Le bouton `#student-registration-submit` porte `disabled` tant qu'aucun radio de classe n'est coché (cible `submit`) ; sans JavaScript, il n'est jamais désactivé.

**États obligatoires**, pour chacun des frames 2 à 4

- **Vide (parent non choisi)** : frame sans contenu.
- **Chargement** : `aria-busy="true"` posé par Turbo ; le contenu précédent s'estompe.
- **Introuvable** (aucun établissement actif, aucun niveau, aucune classe active) : `ui_empty_state title: t(".not_found_title"), description: t(".not_found_description"), icon: "academic-cap"` — titre « Ta classe n'est pas encore sur Lnclass. », description « Préviens ton enseignant ou la direction de ton établissement. ».
- **Erreur** (réponse non 2xx, 429 compris) : `ui_error_state retry_href:` l'adresse du frame, texte « Impossible de charger la liste. » ; pour 429 : « Trop de tentatives. Réessaie dans une minute. ».
- **Succès** : la liste.
- **Erreur de validation au renvoi** : message sous le champ fautif (`aria-invalid`, `aria-describedby`) ; les quatre choix déjà faits sont rendus dans la page, cochés.

### 3.4 Page du lien `classroom/joins/new`

- Jeton valide, **visiteur** : la page §3.1 avec la voie lien.
- Jeton valide, **élève sans classe active** : la carte de l'UDR-0009 §2.5, inchangée : bandeau, un seul bouton « Rejoindre cette classe ».
- Jeton valide, **classe complète** : bandeau, puis l'alerte « Cette classe est complète. », sans formulaire ni bouton.
- Jeton invalide : redirection vers `/student-signup` (visiteur) ou `/students/classroom/new` (élève sans classe), avec `@link_invalid`.
- `_classroom_preview` est inchangé : « Ta classe », « <classe> — <établissement> », « Niveau : <niveau> ».

### 3.5 Élève sans classe : accueil et `classroom/student_classroom_choices/new`

- Accueil de l'élève sans classe active : à la place de la carte de classe, `ui_card` avec le titre « Choisis ta classe », le texte `t(".no_classroom")` (« Tu n'as pas de classe cette année. ») et `ui_button t(".choose")` (« Choisir ma classe »), `brand`, vers `new_student_classroom_choice_path`.
- Après un retrait, le bandeau d'accueil (`flash`, variante `warning`) dit une fois : « Tu ne fais plus partie de cette classe. Choisis ta classe. ».
- Page « Choisis ta classe » : gabarit d'une page de l'espace élève (pas les deux colonnes), `ui_card(padding: :lg)`, titre `h1` « Choisis ta classe », le partial `_class_picker` avec la DRENA et l'établissement de sa dernière classe **déjà choisis** et le frame des niveaux déjà chargé, puis `ui_button` « Rejoindre cette classe », `id: "student-classroom-choice-submit"`.
- Refus « retiré de cette classe » : 403, alerte en tête, texte « Tu ne peux pas rejoindre cette classe. Demande son lien à ton enseignant. ».

### 3.6 Bloc « Lien de la classe » — `classroom/classrooms/_link`

Remplace le bloc du code dans `classroom/classrooms/_header`, et sert tel quel à la page de classe de la direction et à la fiche d'établissement de l'équipe. Rendu seulement si `ManageClassroomMembersPolicy` l'accorde et si la classe est active.

**Structure** : `div#classroom_link` →

- libellé `p#classroom_link_label` « Lien de la classe », petites capitales `text-mute` (classes du libellé actuel du code) ;
- `ui_copy_button` existant (UDR-0054), libellé `t(".copy")` (« Copier le lien »), valeur : l'adresse absolue `/c/<jeton>` ;
- `ui_button t(".whatsapp")` (« Partager sur WhatsApp »), `secondary`, lien `wa.me` sortant, `target="_blank" rel="noopener"`, message `t(".whatsapp_message", classroom:, url:)` : « Rejoins la classe %{classroom} sur Lnclass : %{url} » ;
- menu `ui_dropdown` (⋮, `aria-label` « Autres actions sur le lien ») avec un item « Changer le lien », `dialog: "change-classroom-link"` ;
- aide `p.text-xs.text-mute` : « Vos élèves s'inscrivent avec ce lien, ou choisissent la classe eux-mêmes. ».

L'adresse du lien n'est **pas** affichée en clair : seuls les boutons la portent.

**Modale** `ui_modal title: t(".change_title"), id: "change-classroom-link", size: :sm` : texte « L'ancien lien ne marchera plus. Les élèves déjà inscrits ne sont pas touchés. », boutons « Annuler » et « Changer le lien » (`type: :submit`, `form: "change-classroom-link-form"`). Formulaire `form_with url: classroom_link_path(classroom.public_id), method: :patch`.

**Comportement** : la réponse est un Turbo Stream qui remplace `#classroom_link` et pose le toast « Le lien de la classe a changé. ». Erreur : toast d'erreur existant, le bloc ne change pas.

### 3.7 Nouveaux arrivés et retrait — `classroom/classrooms/_roster`

**Nouveaux arrivés**

- Titre de la liste : après le compteur existant, si au moins un élève est nouveau, `ui_badge t(".new_count", count:)` (« 1 nouveau », « 3 nouveaux »), `tone: :brand`.
- Sur la ligne d'un élève nouveau, après son nom : `ui_badge t(".new"), tone: :brand, size: :sm` (« Nouveau »). *Amendé le 2026-10-08 (porteur)* : sous `sm`, la pastille passe à la ligne, sous le nom, sur la ligne de la voie d'arrivée ; à partir de `sm`, elle reste à côté du nom. Le nom n'est jamais tronqué par la pastille.
- Sous le nom de **chaque** élève, en `text-xs text-mute` : `t(".via.standard")` « Inscrit seul », `t(".via.link")` « Par le lien », rien pour `code`.
- Les élèves nouveaux sont listés **en premier**, du plus récent au plus ancien ; les autres gardent l'ordre actuel.

**Retrait**

- Dans le menu ⋮ existant de la ligne, dernier item, séparé par un filet : « Retirer de la classe », `tone: :danger`, icône `user-minus`, `dialog: "remove-student-<public_id>"`. Rendu seulement si la policy l'accorde et si la classe est active. Le serveur refuse aussi le retrait dans une classe archivée (403, *amendé le 2026-10-08, porteur*), comme le changement de lien.
- `ui_modal title: t(".remove_title", name:), size: :sm` : « %{name} quittera cette classe. Son compte et son travail sont gardés. Il pourra revenir avec le lien de la classe. » ; boutons « Annuler » et « Retirer » (`danger`, `type: :submit`).
- Formulaire `button_to`/`form_with url: classroom_student_path(classroom.public_id, student.public_id), method: :delete`.
- Réponse : Turbo Stream qui retire la ligne `#student_<public_id>` (*amendé le 2026-10-08, porteur* : l'identifiant existant de la ligne est gardé ; un index change avec la recherche et la réponse au retrait ne le connaît pas), remplace le titre (compteur et pastille) et pose le toast « %{name} a été retiré de la classe. ». Si la liste devient vide, le stream remplace `#classroom_roster` par son état vide existant.

**Page de classe de la direction** (`school_admin/classrooms/show`) : mêmes pastilles, même menu et même modale sur ses lignes numérotées ; le bloc §3.6 au-dessus des trois tuiles. *Amendé le 2026-10-08 (porteur, challenger de la phase 5)* : même ordre que la page de l'enseignant (les nouveaux d'abord, du plus récent au plus ancien, puis par nom) ; sous `sm`, chaque élève est une ligne empilée — nom, pastille et voie, puis « Devoirs rendus : … » et « Score moyen : … », le ⋮ à droite —, l'en-tête du tableau en `sr-only` ; à partir de `sm`, le tableau.

**Fiche d'établissement de l'équipe** (`teams/schools/_classroom_group`) : la ligne `dt`/`dd` du code est remplacée par un `ui_copy_button` « Copier le lien » ; le changement de lien et le retrait se font sur la page de la classe, que l'équipe ouvre déjà.

### 3.8 Ce qui disparaît

- `classroom/join_codes/new` et son contrôleur ; `/join` redirige vers `/student-signup`.
- L'entrée « Je suis élève » de `homepage/_role_modal` vise `new_student_registration_path`.
- Le code affiché sur l'accueil et la page de classe de l'élève (`student_homes/_classroom_card`, `student_classrooms/show`) : retiré, sans rien à la place.
- Le code dans les messages de création de classe (direction et équipe) : « La classe %{name} est créée. ».
- Les clés i18n `join_code`, `join_code_hint`, `no_join_code` et celles de `join_codes`.

**Tokens** (toute la décision)

- Composants `ui_*` et tokens `@theme` seulement : `ui_card`, `ui_field`, `ui_button`, `ui_badge`, `ui_modal`, `ui_dropdown`, `ui_empty_state`, `ui_error_state`. Aucune couleur en dur.
- Pastille « Nouveau » et « Complète » : `ui_badge`, `tone: :brand` et `tone: :neutral`.
- Alerte de lien invalide : `bg-warning-soft`, icône `text-warning`. Refus : `bg-error-soft text-error`.

**Accessibilité** (toute la décision)

- Cibles tactiles ≥ 48 px : chaque ligne de classe est un `label` entier `min-h-tap` ; les items de menu aussi.
- Les frames de la cascade portent `aria-live="polite"` : une liste chargée, l'état « introuvable » et l'erreur sont annoncés.
- Le `<fieldset>` des classes a sa `<legend>` ; une classe complète garde son nom lisible, et « Complète » est dans le `label`, pas seulement en couleur.
- La pastille « Nouveau » est du texte, pas une icône seule. Le compteur de nouveaux est dans le titre `h2`, donc lu avec lui.
- Les modales de retrait et de changement de lien rendent le focus à leur déclencheur à la fermeture (comportement de `ui_modal`) ; après un retrait, le focus va au titre de la liste (`tabindex="-1"`).
- PIN : règles de l'UDR-0009 §3, inchangées.
- Parcours prouvé à 390 px et sur ordinateur, menus et modales ouverts.

## 4. Conséquences

- **L'UDR-0009 est remplacée** : plus d'écran à un champ, plus de code nulle part. Sa règle de l'aperçu en trois noms est gardée.
- Tout écran qui montre une classe à quelqu'un qui la gère montre son lien par le bloc §3.6, jamais une adresse en clair ni un code.
- Une liste publique d'une classe ne montre que son nom et « Complète » : ni effectif, ni enseignant.
- Le partial `_class_picker` est la seule façon de faire choisir une classe à un élève ; un futur écran qui en a besoin le réutilise.
- Les textes de l'élève tutoient ; ceux de l'enseignant, de la direction et de l'équipe vouvoient. Le bloc §3.6, vu par les trois, vouvoie.
