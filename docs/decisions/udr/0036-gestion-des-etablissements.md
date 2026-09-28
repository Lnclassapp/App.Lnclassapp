# UDR-0036 : Gestion des établissements — liste nationale filtrée dans un frame, fiche par niveau, modification en modale, aucune création à l'écran

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot S2 ; SC-03 à SC-07) |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (les classes naissent à l'import) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (suppression refusée, désactivation) · UDR-0005, UDR-0006, UDR-0007 |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe gère plusieurs centaines d'établissements répartis dans les DRENA du pays (SC-04 : 600 établissements dans 3 DRENA). Dans l'ancienne application, la liste se rechargeait à chaque filtre, les filtres se perdaient au retour arrière, et un formulaire de création unitaire produisait des établissements **sans classes** : les enseignants s'y inscrivaient, puis ne trouvaient aucune classe à rejoindre (SC-03).

Deux gestes sont fréquents et risqués : corriger un établissement mal importé (nom, sigle, DRENA, type, cycle) et retirer un établissement qui ne devrait plus être proposé. Si changer le type ou le cycle régénérait les classes, ou si supprimer un établissement emportait ses élèves, une correction de routine détruirait l'année d'un établissement.

## 2. Décision

**Un établissement n'entre que par l'import** (décision du porteur du 2026-09-25). L'écran n'a ni bouton ni route de création : son action principale est « Importer des établissements », qui ouvre la modale d'import du lot S3 en `kind=schools`. L'état vide invite à importer le premier fichier.

**La liste se filtre sans quitter la page, et l'URL garde les filtres.** Les filtres (nom ou sigle, DRENA, type, cycle, statut) sont un formulaire `GET` qui vise le frame `schools` avec `data-turbo-action="advance"` : seul le tableau change, le retour arrière et le partage du lien retrouvent la même liste. Pourquoi un frame plutôt qu'un Turbo Stream : c'est une navigation, pas une écriture ; le frame donne l'historique et le repli sans JavaScript gratuitement.

**La modification se fait en modale, la désactivation et la suppression se confirment dans la page.** Les deux confirmations sont des `<dialog>` de la ligne ou de l'en-tête (jamais `confirm()`). Modifier le type ou le cycle **ne touche aucune classe** : une aide le dit dans le formulaire, et « Ajouter une classe » reste le seul geste qui en crée une. Supprimer un établissement dont une classe a un élève, un enseignant ou une assignation est refusé avec sa raison et l'issue : « Désactivez plutôt cet établissement ». Désactiver ne supprime rien : l'établissement disparaît seulement de l'inscription enseignant et de la création de classe.

**Les actions d'une ligne sont des icônes à libellé caché.** Trois boutons texte (« Modifier », « Désactiver », « Supprimer ») élargissaient la dernière colonne au point de faire défiler le tableau sur un écran de bureau. Les icônes (`pencil-square`, `no-symbol`, `trash`) gardent leur nom accessible (`sr-only`, et `aria-label` nommant l'établissement pour « Modifier ») ; sur la fiche, où la place ne manque pas, les mêmes actions gardent leur libellé visible.

## 3. Règles d'implémentation

**Structure**

- Liste : `GET /teams/schools` (`schools_path`), `Teams::SchoolsController#index`, lecture par `Queries::School::SchoolsQuery` (50 par page, total, page ramenée dans les bornes).
- `ui_page_header` « Établissements », action « Importer des établissements » (`ui_button`, icône `arrow-up-tray`, `href: new_teams_import_path(kind: "schools")`, `data-turbo-frame="modal"`). Aucun lien vers `/teams/schools/new`.
- Filtres (`_filters.html.erb`) hors du frame : `form#schools-filters`, `role="search"`, grille `sm:grid-cols-2 lg:grid-cols-4` (recherche sur deux colonnes, puis DRENA, type, cycle, statut) ; champs `filter_search`, `filter_drena`, `filter_school_type`, `filter_cycle`, `filter_status`, chacun avec une première option « Tous / Toutes » à valeur vide ; « Filtrer » (`funnel`) et « Réinitialiser » (`ghost`, `data-turbo-frame="_top"`).
- `turbo_frame_tag "schools", data: { turbo_action: "advance" }` : `p#schools_total` (`aria-live="polite"`), tableau, `#schools_empty`, `ui_pagination`. Une requête du frame ne rend que le frame.
- Tableau dans `relative overflow-x-auto rounded-card border border-line bg-white shadow-card`, `table.min-w-4xl`, `caption` `sr-only`, `tbody#schools_list`, une ligne `tr#school_<public_id>` par établissement, triées par nom.
- Colonnes : Établissement (lien `_top` vers la fiche, sigle dessous en `text-xs text-mute`, `min-w-48`), DRENA (`whitespace-nowrap`), Type, Cycle, Statut (`ui_badge` à point), Classes, Enseignants (`tabular-nums`), actions (`sr-only`).
- Actions de ligne, dans cet ordre et alignées à droite : « Modifier » (`ui_button` `ghost`, icône seule, `data-turbo-frame="modal"`), « Désactiver » (`ui_modal` `deactivate-school-<public_id>`, absente pour un établissement inactif et remplacée par une place vide `w-15` pour garder l'alignement), « Supprimer » (`ui_modal` `delete-school-<public_id>`, bouton de confirmation `danger`).
- Fiche : `GET /teams/schools/:public_id`, `Queries::School::SchoolDetailQuery` ; `content_for :nav_key, "schools"`.
  - `_header.html.erb` → `div#school_header` : retour « Établissements », `ui_card` avec monogramme (sigle, sinon trois premières lettres du nom), `h1`, puis une `dl` sigle · DRENA (`map-pin`) · type · cycle · statut ; actions « Ajouter une classe » (`plus`, modale de création de classe, seulement si l'établissement n'est pas inactif), « Modifier » (`secondary`), « Désactiver » (`ghost`, confirmation `deactivate-school-header`, seulement s'il n'est pas inactif).
  - `section#school_classrooms` : « Classes (n) », année scolaire, un groupe par niveau (ordre des niveaux), une carte `li#classroom_<public_id>` par classe : nom, code d'adhésion (police à chasse fixe), effectif, enseignants.
  - `section#school_teachers` : une carte par enseignant (avatar, nom, `ui_subject_badge` de sa matière), l'établissement principal d'abord.
- Modale `school-modal` (`size: :lg`), formulaire `school-form` (`_form.html.erb`) : nom (150 au plus), sigle (facultatif, `SIGLE_MAX` : 20 au plus) et DRENA, puis type, cycle, statut ; aide `info` : changer le type ou le cycle ne crée ni ne supprime aucune classe.

**Tokens**

- Statuts : `active` → `success`, `draft` → `warning`, `inactive` → `neutral` (`ui_badge`, `dot: true`).
- Libellés des types et statuts : locales communes `school_types.*`, `school_statuses.*` ; cycles : `teams.schools.cycles.*`.
- Champs de filtre : `ComponentsHelper::FIELD_INPUT`, `FIELD_SHAPES[:select]`, `FIELD_STATES[:valid]`. Aucune valeur en dur (UDR-0005).

**Comportement**

- Recherche : sur le nom et le sigle, sans tenir compte des accents ni de la casse ; une valeur de filtre inconnue est ignorée.
- `edit` : `turbo_frame_tag "modal"` → `ui_modal(open: true)` ; hors frame, la même modale s'ouvre sur le shell.
- `update` : échec de saisie, DRENA disparue ou nom déjà pris dans la DRENA → `render :edit`, 422, erreurs sous chaque champ ; succès → toast, `replace "school_<public_id>"` et `replace "school_header"` (chacun ignoré s'il n'est pas sur la page) ; la modale se ferme par `modal#submitEnd`.
- `deactivate` (`PATCH`) : toast, `replace` de la ligne et de l'en-tête ; l'en-tête perd « Ajouter une classe » et « Désactiver ». Un établissement déjà inactif répond par le même succès.
- `destroy` : succès → toast, `remove "school_<public_id>"`, puis `turbo_stream.refresh(request_id: nil)` : la liste filtrée est re-demandée et fusionnée par morphing, le compteur et l'état vide suivent (le toast survit au morph) ; refus (`:conflict`) → 422, toast d'erreur « … Désactivez plutôt cet établissement. », `replace` de la ligne, ce qui referme la confirmation.
- Repli HTML : chaque écriture redirige vers `schools_path` avec `notice` ou `alert`.
- `GET /teams/schools/new` répond 404 (aucun établissement n'a ce `public_id`) ; `POST /teams/schools` n'a pas de route.

**États obligatoires**

- Vide : sans filtre, `ui_empty_state` « Aucun établissement pour l'instant » (`building-library`) avec « Importer des établissements » ; avec filtres, « Aucun établissement ne correspond » (`magnifying-glass`) avec « Effacer les filtres ».
- Fiche : « Aucune classe cette année » et « Aucun enseignant rattaché » en `ui_empty_state`.
- Chargement : sans objet (rendu serveur ; Turbo pose `aria-busy` sur le frame et le formulaire pendant la requête).
- Erreur : message sous le champ fautif ; refus de suppression en toast d'erreur ; établissement inconnu en 404.
- Succès : « Établissement « … » enregistré. », « … désactivé. », « Établissement supprimé. ».

**Accessibilité**

- Type, cycle et statut sont écrits en toutes lettres : le badge n'est jamais la seule information.
- Chaque bouton icône porte un nom accessible (`sr-only`) ; « Modifier » ajoute un `aria-label` qui nomme l'établissement et un `title` pour la souris.
- Libellés de filtre reliés à leur champ (`label for`) ; formulaire `role="search"` nommé.
- Cibles ≥ 48 px (`min-h-tap`).
- Sur téléphone (390 px), seul le tableau défile horizontalement, jamais la page : le conteneur `overflow-x-auto` est `relative` pour que les libellés `sr-only` restent pris dans son défilement.

## 4. Conséquences

- Aucun écran, aucune route ne crée un établissement ; tout établissement a ses classes dès sa naissance (ADR-0030). Un besoin de création unitaire passerait par un fichier d'import d'un seul établissement.
- Modifier un établissement ne crée ni ne supprime jamais de classe ; le seul geste qui en ajoute une est « Ajouter une classe ».
- Aucune suppression en cascade : un établissement utilisé se désactive. Ses classes, élèves et enseignants restent.
- Toute autre liste d'administration longue (plusieurs centaines de lignes, plusieurs filtres) reprend ce patron : formulaire `GET` hors du frame, frame `advance`, compteur `aria-live`, actions de ligne en icônes à libellé caché.

## Amendement du 2026-09-28

*Chantier [`docs/chantiers/actions-en-menu`](../../chantiers/actions-en-menu/prd.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Les actions d'une ligne ne sont plus des icônes à libellé caché** : elles passent dans le menu ⋮ « Actions pour <nom> » (`#school-actions-<public_id>`, `fixed: true`) — « Modifier », « Désactiver » (absente pour un établissement inactif ; la place vide `w-15` disparaît), « Supprimer » (`:danger`). Les modales `deactivate-school-<public_id>` et `delete-school-<public_id>` sont rendues sans `trigger:`.
- **En-tête de la fiche** : « Ajouter une classe » reste un bouton ; « Modifier » et « Désactiver » (si actif) passent dans le menu ⋮ `#school-header-actions`, la confirmation `deactivate-school-header` est rendue sans `trigger:`.
- Le §4 « actions de ligne en icônes à libellé caché » est remplacé par : actions de ligne dans un menu ⋮ (UDR-0042).

## Amendement du 2026-09-28 — générer les classes manquantes

*Chantier [`docs/chantiers/generer-classes`](../../chantiers/generer-classes/prd.md), [UDR-0043](0043-generer-les-classes-manquantes.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- L'en-tête de la liste gagne une action secondaire, « Générer les classes manquantes » (`sparkles`), à gauche de « Importer des établissements », qui reste l'action principale. Sa confirmation et son suivi sont décrits par l'UDR-0043.
- Le §4 « tout établissement a ses classes dès sa naissance » admet une exception : un établissement importé avant le référentiel les reçoit par cette génération (ADR-0056).

## Amendement du 2026-09-28 — code d'établissement

*Chantier [`docs/chantiers/code-etablissement`](../../chantiers/code-etablissement/prd.md), [UDR-0044](0044-inscription-enseignant-par-code-d-etablissement.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- L'en-tête de la fiche gagne le bloc `#school_code` : le code d'établissement (`K7M-4QZ`), « Copier le code », « Copier le lien », le lien `/e/<code>`, et un avertissement si l'établissement n'est pas actif.
- Le menu ⋮ `#school-header-actions` devient : « Modifier », « Régénérer le code » (confirmation `regenerate-school-code`), « Désactiver » si actif.
- L'état vide des enseignants dit désormais qu'ils s'inscrivent avec le code d'établissement.

