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
5. **État vide piloté par le tableau** : il paraît dès que le tableau n'a plus de ligne, que ce soit au premier affichage ou après la dernière suppression, sans que chaque stream ait à le gérer.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `teams/drenas/index` : `ui_page_header` (titre « DRENA », sous-titre, bouton « Nouvelle DRENA » `data-turbo-frame="modal"`), puis un conteneur `group/drenas` qui contient :
  - le tableau (`rounded-card border-line bg-white shadow-card`, `overflow-x-auto relative`), `tbody#drenas`, colonnes Nom · Slug (à utiliser dans les fichiers d'import) · Établissements · Classes · actions ;
  - `#drenas_empty` : `ui_empty_state` « Aucune DRENA pour l'instant », icône `building-library`.
- Ligne `teams/drenas/_drena_row` : `tr#drena_<public_id>`. Le slug est dans un `<code>` ; les compteurs sont alignés à droite en `tabular-nums`. Actions : `ui_button` « Modifier » (`ghost`, `sm`, `pencil-square`, `data-turbo-frame="modal"`) et `ui_modal` à déclencheur « Supprimer » (`ghost`, `trash`), `id: "delete-drena-<public_id>"`, taille `sm`. Son pied contient « Annuler » et un formulaire `DELETE` dont le bouton « Supprimer la DRENA » est `danger`.
- Modales `new` et `edit` : `turbo_frame_tag "modal"` → `ui_modal(id: "drena-modal", open: true)` → `form#drena-form`, un seul `ui_field :name` (obligatoire, 80 caractères au plus). L'aide de `new` explique que le slug sera figé ; celle d'`edit` affiche le slug actuel dans un `<code>`.
- Navigation : l'écran déclare `content_for :nav_key, "schools"` (organisation scolaire).

**Tokens**
- Composants `ui_*` et tokens `@theme` uniquement : `bg-mist` et `font-mono` pour le slug, `text-mute` pour les en-têtes de colonnes, `bg-error-soft`/`text-error` pour les erreurs.
- Aucune couleur ni classe reprise de l'ancienne application.

**Comportement**
- `create` et `update` : `create.turbo_stream.erb` / `update.turbo_stream.erb` envoient un toast de succès, vident `modal` et font `update "drenas"` avec toute la liste. La liste est triée par nom : une création ou un renommage peut déplacer une ligne.
- Nom vide, trop long ou déjà pris : la modale est re-rendue en 422 avec l'erreur sous le champ (« Une DRENA porte déjà ce nom. »).
- `destroy` : succès, toast et `remove "drena_<public_id>"`. Refus (`:conflict`, `has_schools`) : statut 422, toast d'erreur « La DRENA « X » a N établissements : elle ne peut pas être supprimée. », et `replace` de la ligne, qui referme sa `<dialog>`.
- État vide en CSS : le tableau porte `hidden group-has-[#drenas>tr]/drenas:block`, l'état vide `group-has-[#drenas>tr]/drenas:hidden` (`:has()` fait partie du socle navigateur de l'ADR-0051).
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
- Les écrans de gestion de l'équipe qui suivent (niveaux, séries, matières) peuvent reprendre la même confirmation de suppression dans la ligne et le même état vide piloté par CSS.
