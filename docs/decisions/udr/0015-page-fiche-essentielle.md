# UDR-0015 : Page fiche essentielle — contenu riche sous KaTeX, exercices avec la progression de l'élève, menu de l'équipe en modales

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `interface-epuree`* — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `fonctions-espace-eleve` : plus d'assignation de cours ni de fiche (UDR-0062)* |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B3, critères CA-10, CA-11, AS-37 ; CA-29 (bandeau retiré) |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadPublishedPolicy`, tout exercice publié se démarre) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (badges, maîtrise) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (statuts) · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (lacune) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [ADR-0053](../adr/0053-validation-collaborative-requalifiee.md) (aucun label de conformité) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0016](0016-formulaire-fiche-essentielle.md) (modale « Modifier ») · [UDR-0017](0017-formulaire-exercice.md) (modale « Nouvel exercice ») · [UDR-0021](0021-page-exercice.md) (page d'un exercice) |
| **Remplacé par** | — |

---

## 1. Contexte

La fiche essentielle est la page que l'élève ouvre pour réviser, puis pour s'exercer. Dans l'ancienne application (`views/catalog/essentials/show.html.erb`, captures « Brassage génétique par la méiose » et « Anomalies de la méiose ») :

- l'interface l'appelait « Habilité » (sic), et une fiche était visible dès qu'elle existait, publiée ou non ;
- chaque carte d'exercice rendait l'aperçu de ses questions dans un fragment mis en cache **sans le rôle dans la clé** : l'élève pouvait recevoir les bonnes réponses cochées (sécurité n° 29) ;
- un bandeau « Validation collaborative — Conforme au programme » s'affichait partout, alors qu'aucun contenu n'a jamais été validé (CA-29) ;
- le badge de l'élève n'était jamais affiché, faute d'être écrit ;
- l'élève ne savait pas quels exercices son enseignant lui avait demandés, ni que la fiche était à revoir ;
- le menu de l'équipe proposait « Supprimer », qui détruisait les exercices et leurs sessions.

## 2. Décision

1. **Une seule page, `/courses/:course_slug/essentials/:slug`**, pour l'élève, l'enseignant et l'équipe. Une fiche en brouillon ou archivée, ou une fiche d'un cours non publié, répond **404** hors de l'équipe, sans rien confirmer (`ReadPublishedPolicy`). Une fiche lue sous un autre cours que le sien répond aussi 404.
2. **Trois blocs empilés** : l'en-tête avec le contenu, la lacune éventuelle de l'élève, la liste des exercices. Tout se lit d'un défilement ; aucun chargement différé.
3. **Le contenu** est rendu par Action Text (assaini, calque `.trix-content`) et ses formules par KaTeX (contrôleur `math`, chargé à la demande). Il s'affiche en entier : pas de « Lire la suite ».
4. **La liste des exercices ne montre aucune question** : ni énoncé, ni proposition. L'aperçu, corrigé ou non selon le rôle, vit sur la page de l'exercice (UDR-0021). La fiche ne peut donc rien fuiter.
5. **L'élève** ne voit que les exercices **publiés**. Chacun porte son type, son nombre de questions, le badge de l'élève (« Badge Or »), son meilleur score et sa maîtrise, ou « Pas encore de session terminée ». **Tout exercice publié se démarre** (ADR-0028) : « Commencer » (POST, change de page) ou « Reprendre » (session en cours). Un exercice assigné à sa classe principale active, directement, par sa fiche ou par son cours, porte l'étiquette **« Assigné par ton enseignant »** ; l'assignation oriente, elle ne conditionne pas.
6. **La lacune** : si l'élève a une lacune en attente sur la fiche (ADR-0043), un encart « Fiche essentielle à revoir » le dit, avec sa date et la règle pour la lever (au moins 70 % à l'un des exercices de la fiche). Aucun bouton de remédiation en V1 : la route n'existe pas.
7. **L'enseignant** voit les exercices publiés et « Voir l'exercice », sans progression ni bouton de session. L'assignation se fait depuis la classe.
8. **L'équipe** voit tous les exercices, brouillons et archives compris, chacun avec son statut. Dans l'en-tête : le panneau de statut (`content_status_panel`, publier ou archiver), puis **« Modifier »**, **« Nouvel exercice »** et **« Importer des exercices »**, qui ouvrent tous trois leur écran dans le frame `modal`. Il n'y a **pas de « Supprimer »** : une fiche s'archive.
9. **Aucun label de conformité** (ADR-0053) : le bandeau « Validation collaborative » disparaît.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `catalog/essentials/show` : `#essential_header` (lien retour, `ui_card`), puis `div.space-y-8` → `#essential_gap` si `@detail.pending_gap`, puis `ui_card` `#essential_exercises`. `content_for :title` « Fiche essentielle : La méiose » ; `content_for :nav_key, "courses"`.
- `#essential_header` : lien « Cours : Génétique et évolution » vers `course_path(course_slug)` ; `ui_card` → surtitre « Fiche essentielle · <cours> », `h1` nom, sous-titre (`#essential_subtitle`) s'il existe, badges : matière **toujours** `ui_subject_badge(name, category:)`, niveau et série. Équipe : à droite (dessous au téléphone), `#essential_team_actions` (`role=group`) → `content_status_panel(record:)`, `ui_button` « Modifier » (`secondary`, `sm`, `pencil-square`), « Nouvel exercice » (`primary`, `sm`, `plus`), « Importer des exercices » (`secondary`, `sm`, `arrow-up-tray`, `new_teams_import_path(kind: "exercises", essential: slug)`), tous en `data-turbo-frame="modal"`. Sous un filet, `#essential_content[data-controller=math]` : le contenu, ou « Cette fiche essentielle n'a pas encore de contenu. ».
- `#essential_gap` : `rounded-card`, `bg-warning-soft`, icône `light-bulb`, titre « Fiche essentielle à revoir », « Depuis le 12 septembre 2026 », puis la règle avec `Grading::MASTERY_THRESHOLD`.
- `#essential_exercises` : `ui_card` « Exercices » (icône `academic-cap`), compteur « N exercices » en `ui_badge` `brand` dans `card.actions` ; `ul[data-controller=math]` de `_exercise_progress`.
- `_exercise_progress` (`li#essential_exercise_<public_id>`) : titre en lien vers `exercise_path`, description tronquée à 2 lignes, badges (« Assigné par ton enseignant » en ton `teacher` et icône `user-group` pour l'élève ; type en `brand` ; « N questions » ; statut `content_status_badge` pour l'équipe). Élève : ligne de progression (badge `trophy` au ton de `badge_tone`, « Meilleur score : 85 % » et maîtrise). Action à droite (dessous au téléphone) : élève → « Reprendre » (`brand`, lien vers la session) ou « Commencer » (`button_to` POST `exercise_sessions_path`, `primary`) ; autres → « Voir l'exercice » (`secondary`).
- Lecture : `EssentialRepository#find_by_slug` (fait de la policy et panneau de statut), `ReadPublishedPolicy`, puis `EssentialDetailQuery(course_slug:, slug:, student_id:, include_unpublished:)` ; `student_id` pour un élève seulement, `include_unpublished` si `ManageContentPolicy` l'accorde.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune valeur arbitraire.

**Comportement**
- Lecture seule : aucun `*.turbo_stream.erb` propre à la page. « Commencer » et « Reprendre » changent de page (Turbo Drive) ; « Commencer » est un vrai formulaire `POST` qui marche sans JavaScript.
- Les modales « Modifier » (B4) et « Nouvel exercice » (B5) répondent par un stream qui rafraîchit la page par morphing (`turbo_stream.refresh`), sans rechargement de fenêtre ; les formules sont rendues de nouveau après le morphing. La publication ou l'archivage remplace le panneau `#content_status_essential_<slug>`.
- Aucun `cache` dans la page ni dans ses partials : le HTML dépend du rôle et de l'élève.

**États obligatoires**
- Vide, élève et enseignant : « Aucun exercice publié pour cette fiche. » (UDR-0007), avec une phrase qui dit qu'ils arriveront à leur publication.
- Vide, équipe : « Aucun exercice pour cette fiche essentielle », « Créez un exercice ou importez-en : chacun naît en brouillon, à publier ensuite. »
- Chargement : sans objet (page rendue d'un bloc).
- Erreur : 404 par `RendersResult`, sans aucune donnée de la fiche.
- Succès : sans objet sur cette page ; les toasts viennent des Lots B4 et B5.

**Accessibilité**
- « Commencer », « Reprendre », « Voir l'exercice » et « Modifier » nomment leur cible : « Commencer l'exercice « Méiose » », « Modifier la fiche essentielle « La méiose » ».
- Le badge se lit « Badge Or », jamais par la couleur seule ; l'étiquette d'assignation est un texte.
- Cibles tactiles ≥ 48 px ; la page tient dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Le test système `test/system/catalog/essential_page_test.rb` prouve le rendu, sur la fiche, du contenu saisi dans Trix (gras, liste, formule) et des exercices créés par la modale du Lot B5, sans rechargement de page.
- Un futur bouton de remédiation (`StartRemediationSession`, ADR-0043) prendra place dans `#essential_gap`.
- « Supprimer une fiche essentielle » disparaît de l'interface ; l'archivage (UDR-0016) le remplace.

## Amendement du 2026-09-28

*Chantier [`docs/chantiers/actions-en-menu`](../../chantiers/actions-en-menu/prd.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **« Modifier » passe dans le menu ⋮** « Actions pour <nom> » (`#essential-actions-menu`), seule entrée, placé après « Nouvel exercice » et « Importer des exercices », qui restent des boutons. Le nom accessible « Modifier la fiche essentielle « … » » est remplacé par celui du bouton ⋮.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- Retour : `ui_back_link` vers `course_path`, libellé = nom du cours (au lieu de « Cours : <nom> »).
- Titre : « <nom de la fiche> · <espace> · Lnclass » (au lieu de « Fiche essentielle : <nom> »).
- Badges de progression : suivis d'une infobulle des seuils (UDR-0054 §3.4).

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Accepté (2026-10-02, porteur)

> **Décision du porteur (2026-10-02)** : amendement accepté. Les retraits ne valent **que pour l'élève** : l'enseignant et l'équipe gardent ces écrans inchangés, y compris pour les simples répétitions. Toute ligne du tableau ci-dessous qui vise un autre rôle est caduque.

*Chantier [`interface-epuree`](../../chantiers/interface-epuree/memo.md), Lot D, règle de l'[UDR-0057](0057-ecrans-eleve-epures.md). Le texte ci-dessus et les amendements précédents restent en vigueur. Une fois acceptée, cette section fait foi en cas d'écart.*

Aujourd'hui, chaque ligne d'exercice montre jusqu'à huit éléments, et chaque ligne a son bouton `primary` ou `brand`. Cet amendement applique la règle de sobriété à la fiche, telle que l'élève la voit. La fiche n'a pas de maquette : elle garde une seule mise en page, épurée à toutes les tailles (UDR-0057 §3). Le détail retiré des lignes est déjà sur la page de l'exercice (UDR-0021, `#student_progress`), à un tap.

### Changements pour l'élève

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Surtitre de l'en-tête | « Fiche essentielle · <cours> » | « Fiche essentielle », pour l'élève seulement (décision du porteur du 2026-10-02) | R6 | Le lien de retour nomme déjà le cours (`ui_back_link course.name`). |
| Encart `#essential_gap` | Titre, date, puis la règle pour lever la lacune, en toutes lettres | Titre suivi de `ui_info_tip t(".gap_body", threshold: …), label: t(".gap_title")`, puis la date | R4 | Dans l'infobulle, texte inchangé. |
| Aide « Badges » (`#essential_badges_help`) | Au-dessus de la liste, avec son infobulle | Retirée | R4 | Les badges quittent les lignes. Leur explication reste sur la page de l'exercice : infobulles « Badge » et « Maîtrise » de `#student_progress`. |
| Liste `#essential_exercises` | Tous les exercices | Les 3 premières lignes, puis « Voir plus » | R3 | Les lignes suivantes sont rendues, en `hidden`. « Voir plus » les révèle sans requête. |
| Bouton de chaque ligne | « Commencer » `primary` ou « Reprendre » `brand`, sur chaque ligne | `primary` sur la première ligne seulement, `secondary` ensuite. « Reprendre » n'est plus `brand`. | R1 | Même motif que l'accueil sur ordinateur (UDR-0058 §3.3). Libellés, icônes et noms accessibles inchangés. |
| Description de l'exercice | 2 lignes sous le titre | Retirée de la ligne | Q4 | Page de l'exercice, `#exercise_description`. |
| Type (« Fixation », « Évaluation ») | `ui_badge` `brand` | Texte du sous-texte de la ligne | Q4, R5 | Reste dans la ligne : il sert à choisir. Aussi dans l'en-tête de la page de l'exercice. |
| « Assigné par ton enseignant » | `ui_badge` ton `teacher`, icône `user-group` | Texte du sous-texte : « Fixation · Assigné par ton enseignant » | Q4, R5 | Reste dans la ligne : il sert à choisir. La page de l'exercice ne le montre pas. |
| « N questions » | `ui_badge` sur chaque ligne | Retiré de la ligne | Q4 | Page de l'exercice, badges de l'en-tête. |
| Badge de l'élève (« Badge Or ») | Ligne de progression | Retiré de la ligne | Q4 | `#student_progress` : « Badge ». |
| Meilleur score et maîtrise | « Meilleur score : 85 % » et « Acquis » | Retirés de la ligne | Q4 | `#student_progress` : « Meilleur score » et « Maîtrise ». |
| « Pas encore de session terminée » | Ligne de progression | Retiré de la ligne | Q4 | `#student_progress` : « Aucune session terminée ». |
| Forme de la ligne | Seul le titre est un lien. La ligne s'empile au téléphone. | La ligne entière est le lien (lien étiré vers `exercise_path`). Elle reste horizontale à toutes les tailles : titre et sous-texte à gauche, le bouton à droite. État pressé `active:bg-mist`. | Règle « Listes » de l'UDR-0057 | Le détail (score, badge, maîtrise, sessions) est à un tap. |

La colonne de droite porte une seule donnée : l'action. La ligne ne dit pas « Commencé » : le bouton « Reprendre » le dit déjà (R6). La pastille de matière de la règle « Listes » n'est pas rendue : tous les exercices de la fiche ont la matière du cours, déjà dite par le badge de l'en-tête (R6).

Ce qui ne change pas pour l'élève : le retour (nom du cours), le titre, le sous-titre, les badges de matière et de niveau, le contenu sous KaTeX, le titre « Exercices » et son compteur, la date de l'encart, les états vides.

### Contrôle de la règle

| Règle | Fiche essentielle (élève) |
|---|---|
| R1 — une action principale | Respectée : le bouton de la première ligne est le seul `primary`. Aucun `brand`. Sans exercice, aucune action principale. |
| R2 — 5 blocs au plus avant le défilement | 2 : `#essential_header` (retour compris), puis le conteneur de l'encart et des exercices. |
| R3 — 3 lignes, puis « Voir plus » | Respectée : `#essential_exercises` montre 3 lignes, puis « Voir plus ». |
| R4 — aucun texte d'aide permanent | Respectée : la règle de la lacune passe dans une infobulle ; l'aide « Badges » est retirée. Les états vides gardent leur phrase, obligatoire (UDR-0057, « États obligatoires »). |
| R5 — un seul accent | Respectée : le ton `teacher`, le badge de type `brand` et les tons des badges de progression quittent les lignes. Restent le badge de matière (codage par catégorie), le `warning` de l'encart (signal) et le compteur `brand`. |
| R6 — une information une fois | Respectée : le cours est nommé une fois (le retour), la matière une fois (l'en-tête). L'état d'un exercice est dit une fois, par le libellé du bouton. |

### Règles d'implémentation

**`catalog/essentials/show`**
- Surtitre : élève, `t(".student_eyebrow")`, sans interpolation ; enseignant et équipe, `t(".eyebrow", course:)`, inchangé.
- `#essential_gap` : `h2#essential_gap_title` puis, sur la même ligne, `ui_info_tip t(".gap_body", threshold: Entities::Assessment::Grading::REMEDIATION_THRESHOLD), label: t(".gap_title")`. Puis `t(".gap_since", …)`. Le paragraphe `gap_body` visible disparaît. L'icône `light-bulb`, `bg-warning-soft` et la date restent.
- `#essential_badges_help` est retiré.
- La liste est rendue par `exercises.each_with_index`. Chaque ligne reçoit `primary: @student && index.zero?` et `folded: @student && index >= 3`.
- Une ligne `folded` porte `hidden` et la cible du contrôleur `reveal`, selon le contrat du Lot 0.
- Après le `ul`, si l'élève a plus de 3 exercices : « Voir plus » du Lot 0 (`ui_button`, `ghost`, pleine largeur, contrôleur `reveal`, région `aria-live="polite"`, textes de `shared.components`).
- Enseignant et équipe : la liste reste complète, sans « Voir plus ».

**`_exercise_progress`**
- Locals stricts : `(exercise:, student:, team:, primary: false, folded: false)`.
- Élève : `li#essential_exercise_<public_id>.relative.flex.items-center.gap-3.px-5.py-4.active:bg-mist.sm:px-6`.
  - À gauche, `div.min-w-0.flex-1` : le titre en lien vers `exercise_path`, `truncate`, avec `after:absolute after:inset-0` (motif de `classroom/classrooms/_assigned_courses`) ; dessous, le sous-texte `p.text-sm.text-mute` : `t(".exercise_types.<type>")`, puis `· t(".assigned")` si `exercise.assigned_to_my_classroom`.
  - À droite, `div.relative.shrink-0` (au-dessus du lien étiré) : « Reprendre » (`ui_button`, `href:` la session, icône `arrow-path`) ou « Commencer » (`button_to` POST `exercise_sessions_path`, icône `play`). Variante `primary` si `primary`, sinon `secondary`, taille `sm` dans les deux cas.
  - Pas de description, de badge, de « N questions », de score, de maîtrise ni de « Pas encore de session terminée ».
- Enseignant et équipe : la ligne actuelle, inchangée.

**`config/locales/catalog/essentials.fr.yml`**
- Ajouter `show.student_eyebrow` : « Fiche essentielle ». `show.eyebrow` (« Fiche essentielle · %{course} ») reste : l'enseignant et l'équipe le lisent.
- Retirer `show.badges_help`, `exercise_progress.badge`, `exercise_progress.best_score` et `exercise_progress.not_started`, devenus inutilisés. `exercise_progress.questions` reste : l'enseignant et l'équipe le lisent.

**Tokens** : tokens du `@theme` seulement (UDR-0005). Aucune couleur en dur, aucune valeur entre crochets, aucun `dark:`.

### Inchangé pour l'enseignant et l'équipe

- `#essential_team_actions` : le panneau de statut et le menu ⋮ (« Modifier », « Nouvel exercice », « Importer des exercices », transitions, « Tout publier »).
- La ligne d'exercice de l'enseignant et de l'équipe : titre, description, type, « N questions », statut, « Voir l'exercice » (`secondary`).
- La liste complète des exercices, sans « Voir plus ».
- Les états vides de l'équipe.
- Le surtitre « Fiche essentielle · <cours> » (décision du porteur du 2026-10-02 : les retraits ne valent que pour l'élève).

### Vérification

- `test/controllers/catalog/essentials_controller_test.rb` : la fiche de l'élève ne montre plus ni badge ni meilleur score ; chaque ligne porte son type, et « Assigné par ton enseignant » quand il le faut ; la règle de la lacune reste dans `#essential_gap`, dans l'infobulle.
- `test/system/catalog/essential_page_test.rb` : le badge Or à 80 % se vérifie sur la page de l'exercice, après un tap sur la ligne. À 390 × 844, sur une fiche à 4 exercices : `assert_single_primary_action`, `assert_blocks_above_fold(max: 5)` et `assert_list_capped(max: 3)` sur `#essential_exercises`, puis « Voir plus » montre le 4e.
- Les tests de l'équipe (`test/system/teams/essential_management_test.rb`) restent verts sans changement.

## Amendement du 2026-10-02 — une fiche ne s'assigne plus · Statut : Accepté (porteur, 2026-10-02 : « lance les lots »)

*Chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md), grill Q6 et Q7 ; [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (seul un exercice s'assigne) ; [UDR-0062](0062-echeances.md) §3.6. Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Aucun bouton à retirer de cette page.** La fiche du catalogue ne porte pas d'assignation (§2.7 : « L'assignation se fait depuis la classe ») ; la bascule d'une fiche est sur la fiche dans la classe (UDR-0029), qui la perd.
- **§2.5, « Assigné par ton enseignant »** : un exercice porte l'étiquette s'il est assigné **directement** à la classe principale active de l'élève. « Par sa fiche ou par son cours » disparaît : ces assignations n'existent plus. `Queries::Catalog::EssentialDetailQuery` ne lit plus que les assignations `Exercise`.
- L'échéance n'est **pas** répétée sur cette page : elle est sur l'accueil (UDR-0062 §3.2, R6).
- **§2.7** : inchangé pour l'enseignant (« Voir l'exercice », sans action) ; il assigne depuis la fiche dans la classe, avec l'étape des jours de séance (UDR-0062 §3.4).
- **Vérification** : `test/controllers/catalog/essentials_controller_test.rb` — l'étiquette « Assigné par ton enseignant » apparaît pour un exercice assigné à la classe, et pour lui seul.

## Amendement du 2026-10-03 — réorganisation des espaces équipe et enseignant

*Chantier [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md), [UDR-0069](0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md). Statut : proposé, accepté avec le plan du chantier. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Enseignant** : sous chaque exercice publié, une bascule d'assignation par classe de l'enseignant au niveau et à la série du cours ; sans telle classe, la phrase « Aucune de vos classes n'est en <niveau série>. » au-dessus des exercices (UDR-0069 §3.8). Équipe et élève : inchangés.

## Amendement du 2026-10-06 — « Refaire », titre sur 2 lignes, action de la lacune · Statut : Accepté (porteur, 2026-10-06)

*Chantier [`ux-pages-eleve`](../../chantiers/ux-pages-eleve/README.md), plan par page n° 4 et 5. Décision du porteur du 2026-10-06 : « refaire au lieu de commencer ». Le texte ci-dessus et les amendements précédents restent en vigueur ; en cas d'écart, cette section fait foi. Élève seulement : l'enseignant et l'équipe sont inchangés.*

Avec des données réelles (un élève qui a fait 6 fois chaque exercice), la fiche disait « Commencer » sur des exercices déjà faits, et les titres d'exercice étaient tronqués à 13 caractères à 390 px, à côté du bouton.

- **« Refaire »** : une ligne d'exercice dont l'élève a au moins une session terminée (`best_score_percent` présent) porte « Refaire » (icône `arrow-path`, nom accessible « Refaire l'exercice « <titre> » »), au lieu de « Commencer ». « Reprendre » (session en cours) l'emporte toujours. Même règle sur la page de l'exercice (`#student_progress`) : « Refaire l'exercice » dès une session terminée. Le bouton reste un POST vers `exercise_sessions_path` : il ouvre une nouvelle session.
- **Forme de la ligne** : la règle « horizontale à toutes les tailles » ne vaut plus qu'à partir de 640 px. Sous 640 px, le bouton passe sous le titre, aligné à gauche ; le titre tient sur 2 lignes (`line-clamp-2`) au lieu d'une ligne tronquée. Le lien étiré, l'état pressé et la variante (`primary` sur la première ligne seulement, R1) ne changent pas.
- **Encart `#essential_gap`** : sous la date, un bouton `secondary` `sm` « Refaire un exercice » (`#essential_gap_action`) mène à la page du premier exercice de la fiche, quand la fiche en a. R1 reste respectée : un seul `primary`.

**Vérification** : à 390 × 844 sur la fiche « Calculer une limite et lever une forme indéterminée » de l'élève de démo 0110000020 (`db/seeds/demo/saint_michel.rb`) : titres entiers sur 2 lignes, « Refaire » sur les 3 lignes, bouton sous l'encart de la lacune.
