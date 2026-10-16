# UDR-0104 : « Régénérer les codes » se lance depuis l'en-tête de la liste des établissements, sur les établissements filtrés, après une confirmation qui donne leur nombre
<!-- index
titre: « Régénérer les codes » depuis l'en-tête de la liste des établissements, sur la sélection filtrée, confirmation chiffrée
statut: Proposé
adr-lie: [0096](../adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md)
problematique: Menu « Codes » à droite du menu « Classes », réservé à l'équipe `admin` ; modale chargée dans le frame « modal » avec le nombre d'établissements et la DRENA ; nombre à taper hors d'une seule DRENA ; 422 qui réaffiche le nombre à jour.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — RM-01, RM-06, RM-07, RM-08, RM-09 |
| **ADR lié** | ADR-0096 |
| **Remplacé par** | — |

---

## 1. Contexte

Pour changer les codes d'une DRENA, l'équipe ouvre aujourd'hui chaque fiche, le menu ⋮, « Régénérer le code », puis confirme : quatre gestes par établissement, des centaines par DRENA. La liste « Établissements » sait déjà filtrer par DRENA, type, cycle, statut et nom. Le geste de masse doit partir de ce que l'équipe voit, et l'empêcher de tout changer par erreur.

## 2. Décision

- L'action vit dans l'**en-tête de la liste**, dans un menu libellé « Codes », à droite du menu « Classes » : une action de page, pas une action de ligne (UDR-0043, UDR-0045). Pas de cases à cocher : la sélection est **le filtre en cours**.
- La confirmation est une **modale chargée à la demande** dans le frame « modal » (comme les confirmations de la liste depuis le lot E3 de `politique-cache`), parce qu'elle dépend des filtres et d'un comptage serveur. Une modale dessinée d'avance dans la page donnerait un nombre périmé dès qu'on change de filtre.
- Sur une seule DRENA, un clic suffit. **Hors d'une seule DRENA**, l'équipe tape le nombre d'établissements : un « tous » par mégarde coûte ~3 900 codes à retransmettre.

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**

- Fichiers : `app/views/teams/schools/index.html.erb` (menu), `app/views/teams/school_code_regenerations/new.html.erb` (modale), `app/views/teams/school_code_regenerations/_form.html.erb` (formulaire, re-rendu en 422).
- Dans `#schools-header-actions`, après le menu « Classes » : `ui_dropdown label: t(".codes_menu_label"), id: "schools-codes-menu", fixed: true`, déclencheur `tag.span` avec `ui_icon("key", size: :sm)` et `t(".codes_menu")` (« Codes »), mêmes classes que le déclencheur du menu « Classes ».
- Le menu n'est rendu que si `RegenerateSchoolCodesPolicy` autorise `current_actor` (helper `can_regenerate_school_codes?` du contrôleur). Pour `content` et `field`, pas de menu « Codes » du tout (un seul article, refusé : le menu serait vide).
- Article unique : `ui_dropdown_item t(".regenerate_codes"), href: new_school_code_regeneration_path(@filters), icon: "arrow-path", frame: "modal", tone: :danger`.
- **Sélection vide** (`@page.total_count.zero?`) : l'article est rendu **sans `href`** (le helper le désactive : `aria-disabled="true"`), libellé « Régénérer les codes (aucun établissement) ».
- Le menu est **hors du frame « schools »** : il ne suit pas un changement de filtre fait dans le frame. Le lien porte donc les filtres de la requête complète ; la modale **recompte** et affiche toujours le nombre réel. Les filtres de la liste naviguent en `turbo_action: "advance"` : l'URL est à jour, et l'en-tête l'est au rechargement.

**Modale** (`ui_modal title: t(".title"), id: "school-code-regeneration-modal", size: :sm`, dans `turbo_frame_tag "modal"`)

- Titre : « Régénérer les codes ».
- Phrase principale, `text-ink` : une DRENA → « Régénérer le code de **214** établissements de la DRENA **Abidjan 1** ? » ; sinon → « Régénérer le code de **3 912** établissements ? » ; nombres par `number_with_delimiter` (espace fine).
- Rappel des filtres autres que la DRENA, `text-sm text-mute`, une ligne : « Filtres : Lycée · Actif · « moderne » » ; absent sans filtre.
- Liste `list-disc pl-5 text-sm text-mute`, trois puces :
  1. « Les anciens codes cessent aussitôt de fonctionner. »
  2. « Les directions déjà inscrites et les enseignants ne sont pas touchés ; les liens d'invitation ne changent pas. »
  3. « Rien n'est envoyé : vous transmettrez le nouveau code depuis la fiche de l'établissement. »
- Hors d'une seule DRENA : `ui_field form, :typed_count, label: t(".typed_count_label", count:)` (« Tapez 3 912 pour confirmer »), `inputmode: "numeric"`, `autocomplete: "off"`, requis. Espaces tolérés à la saisie, retirés par le serveur.
- Les filtres voyagent en champs cachés (`hidden_field_tag "selection[drena]"`, etc.) : le `POST` rejoue la sélection, jamais une liste d'identifiants.
- Pied : `ui_button t(".cancel"), variant: :secondary, data: { action: "modal#close" }` puis `ui_button t(".confirm"), type: :submit, form: "school-code-regeneration-form", icon: "arrow-path", variant: :danger` (« Régénérer les codes »).
- Phrase de fond, `text-xs text-mute` sous la liste : « Le changement se fait en arrière-plan ; vous suivrez son avancement dans un rapport. »

**Tokens**

- Couleurs : `text-ink`, `text-mute`, variante `danger` du bouton et de l'article ; aucune valeur en dur.
- Typographie : nombre et DRENA en `font-semibold` ; corps `text-sm`.
- Espacements : `space-y-3` dans le formulaire, comme la modale de génération des classes.

**Comportement**

- `GET /teams/schools/code-regenerations/new?drena=…` : page complète sans frame (repli sans JS), modale dans le frame « modal » sinon.
- `POST /teams/schools/code-regenerations` :
  - succès → `redirect_to teams_import_path(report.public_id), notice: t(".started"), status: :see_other` (`_top`, le formulaire porte `data-turbo-frame="_top"`) ; toast « Régénération des codes lancée. » ;
  - `:invalid` → 422, `_form` re-rendu dans le frame « modal » : `typed_count` → message sous le champ « Tapez 3 912 pour confirmer. » avec le nombre recompté ; `:empty` → alerte en tête de la modale « Aucun établissement à régénérer. », bouton de confirmation absent ;
  - `:conflict` → redirection vers le rapport en cours, flash `info` « Une régénération des codes est déjà en cours. » (même forme que `ClassroomGenerationsController#redirect_to_running`) ;
  - `:forbidden` → 403 (`render_forbidden`).
- Pas de Stimulus nouveau : `modal` existant.
- Pas de `secret_response` : la modale ne montre aucun code.

**États obligatoires**

- Vide : article désactivé (sélection vide) ; modale avec l'alerte `:empty` si on force l'adresse.
- Chargement : le frame « modal » existant (`aria-busy`).
- Erreur : 422 dans la modale (nombre faux, sélection vide) ; 403.
- Succès : redirection vers le rapport (UDR-0105) et toast.

**Accessibilité**

- Cibles ≥ 48×48 px (déclencheur du menu, article, boutons).
- Le champ « Tapez … » a son `label` visible ; l'erreur est liée par `aria-describedby` (`ui_field`).
- Focus : à l'ouverture, sur le champ s'il existe, sinon sur « Annuler » (action sûre par défaut).
- Le nombre et la DRENA sont dans le titre accessible de la phrase principale, pas seulement en gras.
- Téléphone (390 px) : le menu « Codes » passe à la ligne avec « Classes » (`flex-wrap` existant) ; la modale tient en largeur sans défilement horizontal.

## 4. Conséquences

- L'en-tête de la liste porte trois actions : « Importer des établissements », « Classes », « Codes ». Une quatrième action de page devra regrouper les menus.
- La sélection d'un geste de masse sur la liste est **toujours** le filtre en cours ; aucun geste futur n'introduira de cases à cocher sans revenir sur cette UDR.
- Le geste unitaire de la fiche (UDR-0044) ne change pas.
