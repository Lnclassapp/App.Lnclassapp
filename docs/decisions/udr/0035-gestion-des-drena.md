# UDR-0035 : Gestion des DRENA — tableau par nom, slug affiché pour les imports, création et renommage en modale, suppression confirmée dans la ligne

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot S1, critère SC-01 |
| **ADR lié** | [ADR-0029](../adr/0029-identifiants-exposes-public-id-et-slugs.md) (slug figé) · [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (production vide) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (suppression refusée) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) |
| **Remplacé par** | — |

---

## 1. Contexte

La production démarre **sans aucune DRENA** (ADR-0034). L'équipe crée les 41 DRENA à l'écran, puis importe les établissements de chacune : le fichier d'import cite la DRENA par son **slug** (`"drena": "abidjan-1"`). Décision du porteur : les DRENA se créent **uniquement par formulaire**, jamais par import (SC-02 écartée).

Dans l'ancienne application, trois défauts gênaient ce travail :

- le slug n'était affiché nulle part : pour écrire un fichier d'import, il fallait le deviner ;
- le nom saisi était transformé (`titleize`) : « DRENA ABIDJAN 1 » devenait « Drena Abidjan 1 » ;
- supprimer une DRENA supprimait en cascade ses écoles, leurs classes et leur contenu, après un simple `confirm()` du navigateur.

## 2. Décision

1. **Un tableau par nom**, qui montre pour chaque DRENA son nom, son **slug** (« à utiliser dans les fichiers d'import »), et le nombre de ses établissements et de ses classes. L'équipe y lit tout ce qu'il faut pour préparer un import.
2. **Création et renommage en modale**, sans rechargement (UDR-0006 §7). Le nom est enregistré tel que saisi, espaces normalisés et casse conservée.
3. **Le slug est tiré du nom à la création, puis ne change plus.** La modale d'édition le rappelle, pour que l'équipe sache qu'un renommage ne casse aucun fichier d'import.
4. **Suppression confirmée dans la ligne**, par une `<dialog>` de l'application, jamais par le `confirm()` du navigateur. Une DRENA qui a des établissements n'est **pas supprimée** : un toast d'erreur donne la raison et le nombre d'établissements, et la ligne reste. Aucune cascade (ADR-0036).
5. **État vide sous le tableau**, dans la même carte, comme l'écran des imports : il paraît au premier affichage sans DRENA et revient quand la dernière est supprimée ; la première création l'efface.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `teams/drenas/index` : `ui_page_header` (titre « DRENA », sous-titre, bouton « Nouvelle DRENA » `data-turbo-frame="modal"`), puis une carte (`rounded-card border-line bg-white shadow-card`, `overflow-x-auto relative`) qui contient :
  - le tableau, `tbody#drenas`, colonnes Nom · Slug (à utiliser dans les fichiers d'import) · Établissements · Classes · actions ;
  - `div#drenas_empty.p-6.empty:hidden` : `ui_empty_state` « Aucune DRENA pour l'instant », icône `building-library`, rendu seulement quand il n'y a aucune DRENA. Vide, le bloc ne prend aucune place.
- Ligne `teams/drenas/_drena_row` : `tr#drena_<public_id>`. Le slug est dans un `<code>` ; les compteurs sont alignés à droite en `tabular-nums`. Actions : `ui_button` « Modifier » (`ghost`, `sm`, `pencil-square`, `data-turbo-frame="modal"`) et `ui_modal` à déclencheur « Supprimer » (`ghost`, `trash`), `id: "delete-drena-<public_id>"`, taille `sm`. Son pied contient « Annuler » et un formulaire `DELETE` dont le bouton « Supprimer la DRENA » est `danger`.
- Modales `new` et `edit` : `turbo_frame_tag "modal"` → `ui_modal(id: "drena-modal", open: true)` → `form#drena-form`, un seul `ui_field :name` (obligatoire, 80 caractères au plus). L'aide de `new` explique que le slug sera figé ; celle d'`edit` affiche le slug actuel dans un `<code>`.
- Navigation : l'écran déclare `content_for :nav_key, "schools"` (organisation scolaire).

**Tokens**
- Composants `ui_*` et tokens `@theme` uniquement : `bg-mist` et `font-mono` pour le slug, `text-mute` pour les en-têtes de colonnes, `bg-error-soft`/`text-error` pour les erreurs.
- Aucune couleur ni classe reprise de l'ancienne application.

**Comportement**
- `create` et `update` : `create.turbo_stream.erb` / `update.turbo_stream.erb` envoient un toast de succès, vident `modal` et font `update "drenas"` avec toute la liste. La liste est triée par nom : une création ou un renommage peut déplacer une ligne. `create` vide aussi `drenas_empty`.
- Nom vide, trop long ou déjà pris : la modale est re-rendue en 422 avec l'erreur sous le champ (« Une DRENA porte déjà ce nom. »).
- `destroy` : succès, toast et `remove "drena_<public_id>"` ; si c'était la dernière DRENA, `update "drenas_empty"` avec l'état vide. Refus (`:conflict`, `has_schools`) : statut 422, toast d'erreur « La DRENA « X » a N établissements : elle ne peut pas être supprimée. », et `replace` de la ligne, qui referme sa `<dialog>`.
- Repli sans Turbo : chaque écriture redirige vers la liste (`303`) avec un flash (`notice` ou `alert` pour le refus).

**États obligatoires**
- Vide : « Aucune DRENA pour l'instant » et une phrase qui dit quoi faire.
- Erreur de saisie : message sous le champ, `aria-invalid`, modale ouverte.
- Refus de suppression : toast d'erreur persistant (`role="alert"`).
- Succès : toast « DRENA « X » créée. », « … modifiée. » ou « … supprimée. ».

**Accessibilité**
- « Modifier » porte `aria-label="Modifier la DRENA « X »"`. Le titre de la `<dialog>` de suppression nomme la DRENA.
- Cibles tactiles ≥ 48 px (`ui_button`, zone étendue en `sm`).
- Sur téléphone, seul le tableau défile en largeur, jamais la page : le conteneur est `relative` et contient ainsi l'en-tête `sr-only` de la colonne d'actions.

## 4. Conséquences

- La suppression d'une DRENA n'efface jamais une école : l'équipe désactive les écoles, puis supprime une DRENA vide.
- Un renommage ne demande aucune mise à jour des fichiers d'import déjà écrits.
- Les écrans de gestion de l'équipe qui suivent (niveaux, séries, matières) peuvent reprendre la même confirmation de suppression dans la ligne et le même état vide sous le tableau.

## Amendement du 2026-09-28

*Chantier [`docs/chantiers/actions-en-menu`](../../chantiers/actions-en-menu/prd.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Les actions de ligne passent dans le menu ⋮** « Actions pour <nom> » (`#drena-actions-<public_id>`, `fixed: true`) : « Modifier » (`frame: "modal"`) puis « Supprimer » (`dialog: "delete-drena-<public_id>"`, `:danger`). La modale est rendue sans `trigger:`, son pied est inchangé. L'`aria-label` de « Modifier » est remplacé par celui du bouton ⋮.

## Amendement du 2026-10-05 — confirmation de suppression chargée à la demande

*Chantier [`docs/chantiers/politique-cache`](../../chantiers/politique-cache/plan.md), lot E3. Décision du porteur, 2026-10-05, avec la liste des établissements (UDR-0036, même date). Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- L'item « Supprimer » du menu ⋮ devient un lien vers `GET /teams/drenas/:public_id/deletion`, avec `data-turbo-frame="modal"`. La confirmation arrive ouverte dans le frame « modal », avec le même titre, le même texte, le même `DELETE` et l'identifiant `delete-drena-<public_id>`. Sans frame, la même adresse est une page complète, avec un retour « ← DRENA ». Une DRENA inconnue répond 404.
- Le refus (`:conflict`) ajoute `turbo_stream.update "modal"`, qui referme la confirmation : avant, c'est le re-rendu de la ligne qui la refermait.
- Mesure (`measure_screens.rb`, 42 DRENA, 100 requêtes, médiane de 3) : HTML 240,4 → **121,2 Ko**, sous le budget de 150 Ko ; rendu de la vue 35,1 → **16,5 ms** ; p50 76,5 → **59,3 ms**, p95 108,5 → **84,6 ms**.
