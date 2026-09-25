# UDR-0033 : Gestion des séries — un tableau des séries et une matrice niveaux × séries sur le même écran

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/boucle-pedagogique` — Lot R2 (CA-19, CA-24) |
| **ADR lié** | [ADR-0029](../adr/0029-identifiants-exposes-public-id-et-slugs.md) (slug figé) · [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (référentiel créé par l'équipe) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (suppression refusée tant qu'une ligne référence) |
| **Remplacé par** | — |

---

## 1. Contexte

La production démarre vide (ADR-0034) : avant de créer une classe ou un cours de second cycle, l'équipe doit saisir les séries (A, A1, A2, C, D) et dire à quels niveaux chacune est ouverte. Seul un couple niveau–série lié est proposé dans les formulaires de classe et de cours.

L'ancienne application n'avait aucune page pour voir les séries : `index` et `show` n'avaient pas de template (CA-23), et seul l'onglet « Setup » du tableau de bord les listait. Une série se rattachait aux niveaux depuis le formulaire **du niveau**, par des cases à cocher. Pour voir quelles séries s'ouvrent en Tle, il fallait ouvrir la Tle. Supprimer une série remettait silencieusement à `NULL` la série des classes et des cours qui la portaient.

## 2. Décision

**Un seul écran, `/teams/series`, porte deux blocs : le tableau des séries, puis la matrice niveaux × séries.** Une case par couple : cochée, la série est ouverte au niveau.

- **Matrice plutôt que cases dans le formulaire du niveau.** L'équipe voit en un coup d'œil toute la structure du second cycle. Un clic sur une case écrit un seul couple, sans ouvrir de formulaire. Le formulaire du niveau (Lot R1) ne porte plus les séries.
- **Création et renommage en modale** (UDR-0006 §7). Le formulaire ne demande que le nom. Le code (slug) est dérivé du nom à la création, puis figé (ADR-0029). Il est affiché dans le tableau, parce que les fichiers d'import et la génération des classes l'utilisent.
- **Suppression confirmée dans la page**, par une modale native, jamais par `window.confirm`. Une série liée à un niveau, ou portée par une classe ou un cours, est gardée : le refus donne sa raison.
- **Les séries n'existent qu'au second cycle** (arbitrage de l'orchestrateur, 2026-09-25) : la matrice ne montre que les niveaux du second cycle, et lier une série à un niveau du premier cycle est refusé (`:invalid`, 422, toast avec la raison).
- **Un couple utilisé ne se décoche pas.** Le refus est affiché dans un toast d'erreur et la case reste cochée. Une serrure signale d'avance les couples utilisés.

## 3. Règles d'implémentation

**Structure**

- `app/views/teams/series/index.html.erb` : `ui_page_header` (titre, sous-titre, bouton « Nouvelle série » en `data-turbo-frame="modal"`) ; tableau `tbody#series` (Nom, Code, Niveaux en `ui_badge`, Classes, Cours, Actions) ; `#series_empty` (`ui_empty_state`) quand il n'y a aucune série ; puis `_matrix`.
- `_series_row` : `tr#series_<slug>`. « Modifier » est un `ui_button` en `data-turbo-frame="modal"`. « Supprimer » est le déclencheur d'un `ui_modal` d'id `delete-series-<slug>`, dont le pied porte « Annuler » et un `form_with … method: :delete` contenant un `ui_button` `danger`.
- `_matrix` : `section#level_series_matrix`. Les niveaux, par position, sont les lignes (`th scope="row"`). Les séries, par nom, sont les colonnes (`th scope="col"`). Sans niveau ou sans série, un `ui_card` explique qu'il faut d'abord en créer.
- `teams/level_series/_cell` : `td#level_series_<niveau>_<série>`, un `button_to` bascule. Cochée : `DELETE /teams/levels/:level_slug/series/:series_slug`. Décochée : `POST /teams/levels/:level_slug/series` avec `series_slug`.
- `new` et `edit` : `turbo_frame_tag "modal"` → `ui_modal(open: true)` → `form#series-form`. Le bouton d'envoi, dans `modal.footer`, vise `form: "series-form"`.

**Tokens**

- Case cochée : `bg-brand`, `border-brand`, icône `check`. Case décochée : `bg-white`, `border-line`, icône transparente. Couple utilisé : icône `lock-closed` à la place de `check`.
- Tableau et matrice : `rounded-card`, `border-line`, `shadow-card`, comme l'écran des imports.
- Aucune couleur en dur : seulement les tokens `@theme` et les composants `ui_*`.

**Comportement**

- `create` : toast, `remove "series_empty"`, `append "series"`, `replace "level_series_matrix"` (nouvelle colonne). La modale se ferme sur `turbo:submit-end` réussi.
- `update` : toast, `replace "series_<slug>"`, `replace "level_series_matrix"` (en-tête de colonne).
- `destroy` : toast, `remove "series_<slug>"`, `replace "level_series_matrix"`. Refus (`:conflict`) : **422**, toast d'erreur avec la raison, `replace "series_<slug>"` (la ligne est re-rendue et sa modale de confirmation se referme).
- Couples (`level_series#create`, `#destroy`) : toast et `replace` de la case, avec son état relu en base. Refus (déjà lié, ou utilisé) : **422** et toast d'erreur.
- Erreur de saisie : `render :new` ou `:edit` en **422**. La modale se rouvre avec l'erreur sous le champ.
- Repli sans Turbo : chaque écriture redirige vers `/teams/series` en 303, avec un flash (`notice` ou `alert`).

**États obligatoires**

- Vide : « Aucune série pour l'instant » (tableau) ; « Créez d'abord des niveaux et des séries pour les associer. » (matrice).
- Erreur : nom vide, trop long (10 caractères au plus) ou déjà pris, sous le champ ; refus de suppression ou de retrait dans un toast d'erreur, avec sa raison.
- Succès : toast « Série « D » créée. », « … : série ouverte au niveau. », etc.
- Chargement : sans objet. L'écran est rendu côté serveur, et Turbo marque `aria-busy` pendant l'envoi.

**Accessibilité**

- Chaque case est un vrai bouton, avec `aria-pressed` (`true` ou `false`) et un `aria-label` « Tle × D ». Pour un couple utilisé, le libellé ajoute « utilisé par une classe ou un cours ». La zone tactile atteint 48 px grâce au pseudo-élément `after:-inset-2`.
- Focus visible `outline-brand` sur les cases et les boutons ; la modale de confirmation est une `<dialog>` native (piège du focus, Échap).
- Les en-têtes de la matrice sont des `th` avec `scope`, et la légende de la serrure est écrite en toutes lettres sous la matrice.

## 4. Conséquences

- Le formulaire d'un niveau (Lot R1) ne propose pas de séries : l'association se fait uniquement dans cette matrice.
- Une série ne se supprime qu'après avoir été retirée de tous ses niveaux. Une série portée par une classe ou un cours ne se supprime pas en V1.
- Interdit désormais : la remise à `NULL` silencieuse de la série d'une classe ou d'un cours, et un retrait de couple qui échoue sans le dire.
- Hors périmètre : la page publique d'une série (CA-23).
