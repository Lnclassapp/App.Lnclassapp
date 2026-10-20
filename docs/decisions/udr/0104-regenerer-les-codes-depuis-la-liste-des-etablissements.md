# UDR-0104 : « Régénérer les codes » et « Régénérer les liens des classes » se lancent depuis l'en-tête de la liste des établissements, ou depuis la fiche pour les classes, après une confirmation qui donne leur nombre
<!-- index
titre: Régénération des codes et des liens des classes depuis la liste (sélection filtrée) ou la fiche, confirmation chiffrée
statut: Accepté
adr-lie: [0096](../adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md)
problematique: Menu « Codes » à droite du menu « Classes » (deux articles), entrée « Régénérer les liens des classes » du menu ⋮ de la fiche, réservés à l'équipe `admin` ; une modale commune chargée dans le frame « modal » avec le nombre et la portée ; année en cours par défaut pour les classes ; nombre à taper hors d'une seule DRENA ou d'un seul établissement ; 422 qui réaffiche le nombre à jour.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : chantier gardé et élargi aux liens des classes ; réservé à `admin`, à confirmer)* |
| **Date** | 2026-10-16 (amendée le même jour : liens des classes, entrée de la fiche) |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — RM-01, RM-06 à RM-09, RM-15, RM-16, RM-19, RM-22 |
| **ADR lié** | ADR-0096 |
| **Remplacé par** | — |

---

## 1. Contexte

Pour changer les codes d'une DRENA, l'équipe ouvre aujourd'hui chaque fiche, le menu ⋮, « Régénérer le code », puis confirme : quatre gestes par établissement. Pour changer les liens des classes, il faut ouvrir chaque classe et « Changer le lien ». La liste « Établissements » sait déjà filtrer par DRENA, type, cycle, statut et nom. Les gestes de masse doivent partir de ce que l'équipe voit, et l'empêcher de tout changer par erreur.

## 2. Décision

- Les actions vivent dans l'**en-tête de la liste**, dans un menu libellé « Codes », à droite du menu « Classes » : des actions de page, pas des actions de ligne (UDR-0043, UDR-0045). Deux articles : « Régénérer les codes d'établissement », « Régénérer les liens des classes ». Pas de cases à cocher : la sélection est **le filtre en cours**.
- Les liens des classes d'**un seul établissement** se régénèrent aussi depuis sa **fiche** : une entrée du menu ⋮ de l'en-tête, après « Régénérer le code ».
- Une seule modale pour les deux cibles, **chargée à la demande** dans le frame « modal », parce qu'elle dépend des filtres et d'un comptage serveur.
- Sur une seule DRENA ou un seul établissement, un clic suffit. **Ailleurs**, l'équipe tape le nombre : un « tous » par mégarde coûte des milliers de codes ou de liens à retransmettre.
- Pour les classes, l'**année scolaire en cours seulement** est le choix par défaut ; un lien de la modale recompte avec les années passées.

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**

- Fichiers : `app/views/teams/schools/index.html.erb` (menu « Codes »), `app/views/teams/schools/_header.html.erb` (entrée de la fiche), `app/views/teams/code_regenerations/new.html.erb` (modale), `app/views/teams/code_regenerations/_form.html.erb` (formulaire, re-rendu en 422).
- Dans `#schools-header-actions`, après le menu « Classes » : `ui_dropdown label: t(".codes_menu_label"), id: "schools-codes-menu", fixed: true`, déclencheur `tag.span` avec `ui_icon("key", size: :sm)` et `t(".codes_menu")` (« Codes »), mêmes classes que le déclencheur du menu « Classes ».
- Le menu et l'entrée de la fiche ne sont rendus que si `RegenerateCodesInBulkPolicy` autorise `current_actor` (helper `can_regenerate_codes_in_bulk?`). Pour `content` et `field`, pas de menu « Codes » du tout, pas d'entrée sur la fiche.
- Articles du menu : `ui_dropdown_item t(".regenerate_school_codes"), href: new_code_regeneration_path(target: "school_codes", **@filters), icon: "arrow-path", frame: "modal", tone: :danger` puis le même avec `target: "classroom_links"`, `t(".regenerate_classroom_links")`, icône `link`.
- **Sélection vide** (`@page.total_count.zero?`) : les deux articles sont rendus **sans `href`** (le helper les désactive : `aria-disabled="true"`), libellés suivis de « (aucun établissement) ».
- Entrée de la fiche : `ui_dropdown_item t(".regenerate_classroom_links"), href: new_code_regeneration_path(target: "classroom_links", school: school.public_id), icon: "link", frame: "modal", tone: :danger`.
- Le menu est **hors du frame « schools »** : le lien porte les filtres de la requête complète ; la modale **recompte** et affiche toujours la sélection réelle.

**Modale** (`ui_modal title:, id: "code-regeneration-modal", size: :sm, open: true`, dans `turbo_frame_tag "modal"`)

- Titre : « Régénérer les codes d'établissement » ou « Régénérer les liens des classes ».
- Phrase principale, `text-ink`, nombre et portée en `font-semibold` :
  - codes : une DRENA → « Régénérer le code de **214** établissements de la DRENA **Abidjan 1** ? » ; sinon → « Régénérer le code de **3 912** établissements ? » ;
  - liens : un établissement → « Régénérer le lien de **12** classes de **Lycée Moderne de Cocody** ? » ; une DRENA → « … de **3 120** classes de la DRENA **Abidjan 1** ? » ; sinon → « … de **58 400** classes ? ».
  - Nombres par `number_with_delimiter`.
- Rappel des filtres autres que la DRENA, `text-sm text-mute`, une ligne : « Filtres : Lycée · Actif · « moderne » » ; absent sans filtre et pour un établissement seul.
- Liens seulement, ligne `text-sm text-mute` : « Classes de l'année 2026-2027 seulement. » suivie du lien « Inclure les années passées » (`data-turbo-frame="modal"`, recharge la modale avec `all_years=1`) ; ou « Classes de toutes les années. » et « Seulement l'année 2026-2027 ».
- Liste `list-disc pl-5 text-sm text-mute`, trois puces :
  - codes : « Les anciens codes cessent aussitôt de fonctionner. » ; « Les directions déjà inscrites et les enseignants ne sont pas touchés ; les liens d'invitation ne changent pas. » ; « Rien n'est envoyé : vous transmettrez le nouveau code depuis la fiche de l'établissement. »
  - liens : « Les anciens liens cessent aussitôt de fonctionner : un élève qui en ouvre un arrive sur l'inscription standard. » ; « Les élèves déjà inscrits restent dans leur classe ; les classes archivées ne sont pas touchées. » ; « Rien n'est envoyé : l'enseignant ou la direction partage le nouveau lien depuis la page de la classe. »
- Hors d'une seule DRENA ou d'un seul établissement : `ui_field form, :typed_count, label: t(".typed_count_label", count:)` (« Tapez 3 912 pour confirmer »), `inputmode: "numeric"`, `autocomplete: "off"`, requis, `autofocus: true`. Espaces tolérés à la saisie, retirés par le serveur.
- La cible, les filtres, l'établissement et l'option d'année voyagent en champs cachés (`target`, `selection[drena]`, …, `selection[school]`, `current_year_only`) : le `POST` rejoue la sélection, jamais une liste d'identifiants.
- Phrase de fond, `text-xs text-mute` sous la liste : « Le changement se fait en arrière-plan ; vous suivrez son avancement dans un rapport. »
- Pied : `ui_button t(".cancel"), variant: :secondary, data: { action: "modal#close" }` puis `ui_button t(".confirm.<target>"), type: :submit, form: "code-regeneration-form", icon: "arrow-path", variant: :danger`.

**Tokens**

- Couleurs : `text-ink`, `text-mute`, variante `danger` du bouton et des articles ; aucune valeur en dur.
- Typographie : nombre et portée en `font-semibold` ; corps `text-sm`.
- Espacements : `space-y-3` dans le formulaire.

**Comportement**

- `GET /teams/schools/code-regenerations/new?target=…&drena=…` : page complète sans frame (repli sans JavaScript), modale dans le frame « modal » sinon. `target` inconnu : 404.
- `POST /teams/schools/code-regenerations` :
  - succès → `redirect_to teams_import_path(report.public_id), notice: t(".started.<target>"), status: :see_other` (le formulaire porte `data-turbo-frame="_top"`) ; toast « Régénération des codes lancée. » ou « Régénération des liens des classes lancée. » ;
  - `:invalid` → 422, `_form` re-rendu dans le frame « modal » : `typed_count` → message sous le champ « Tapez 3 912 pour confirmer. » avec le nombre recompté ; `:empty` → alerte « Aucun établissement à régénérer. » ou « Aucune classe à régénérer. », bouton de confirmation absent ;
  - `:conflict` → redirection vers le rapport en cours du même `kind`, flash `info` « Une régénération des codes (ou des liens des classes) est déjà en cours. » ;
  - `:forbidden` → 403.
- Pas de Stimulus nouveau : `modal` et `autofocus` existants.
- Pas de `secret_response` : la modale ne montre aucun code ni lien.

**États obligatoires**

- Vide : articles désactivés (sélection vide) ; modale avec l'alerte `:empty` (établissement sans classe, adresse forcée).
- Chargement : le frame « modal » existant (`aria-busy`).
- Erreur : 422 dans la modale (nombre faux, sélection vide) ; 403.
- Succès : redirection vers le rapport (UDR-0105) et toast.

**Accessibilité**

- Cibles ≥ 48×48 px (déclencheur du menu, articles, boutons).
- Le champ « Tapez … » a son `label` visible ; l'erreur est liée par `aria-describedby` (`ui_field`).
- Focus : à l'ouverture, sur le champ s'il existe, sinon sur « Annuler » (action sûre par défaut).
- Téléphone (390 px) : le menu « Codes » passe à la ligne avec « Classes » (`flex-wrap` existant) ; la modale tient en largeur sans défilement horizontal.

## 4. Conséquences

- L'en-tête de la liste porte trois actions : « Importer des établissements », « Classes », « Codes ». Une quatrième action de page devra regrouper les menus.
- La sélection d'un geste de masse sur la liste est **toujours** le filtre en cours ; aucun geste futur n'introduira de cases à cocher sans revenir sur cette UDR.
- Le geste unitaire de la fiche (UDR-0044) et « Changer le lien » d'une classe (UDR-0081 §3.6) ne changent pas.
- Quand `inscription-direction-sans-code` retirera le code d'établissement, l'article « Régénérer les codes d'établissement » partira ; le menu « Codes » gardera les liens des classes.
