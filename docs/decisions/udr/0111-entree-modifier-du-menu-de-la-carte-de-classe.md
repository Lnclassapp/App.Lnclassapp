# UDR-0111 : Entrée « Modifier la classe » du menu ⋮ des cartes de classe (fiche de l'équipe, niveau de la direction)
<!-- index
titre: Entrée « Modifier la classe » du menu ⋮ des cartes de classe
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0098](../adr/0098-modifier-une-classe-nom-au-prefixe-du-bareme-et-plafond.md)
problematique: Où l'équipe et la direction trouvent la modification d'une classe, à côté de l'archivage, sans nouveau bouton sur la carte.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16)* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/vie-de-la-classe`](../../chantiers/vie-de-la-classe/memo.md) |
| **ADR lié** | [ADR-0098](../adr/0098-modifier-une-classe-nom-au-prefixe-du-bareme-et-plafond.md) · amende [UDR-0083](0083-menu-d-archivage-de-la-classe-et-du-niveau.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'UDR-0083 a posé que « toute nouvelle action sur une classe passe par ce menu ⋮ ». Le menu existe sur la carte de classe de la fiche d'un établissement (équipe, `teams/schools/_classroom_group`) et de la page d'un niveau (direction, `school_admin/levels/_classroom_card`), rendu par `shared/_classroom_archive_menu`. Il ne contient qu'« Archiver la classe » ou « Restaurer la classe ».

## 2. Décision

- « Modifier la classe » devient la **première** entrée du menu d'une classe active, au-dessus d'« Archiver la classe » : le geste fréquent et réversible avant le geste lourd.
- Pas d'entrée pour une classe archivée : on la restaure d'abord (ADR-0098).
- Le partiel `shared/_classroom_archive_menu` reste le menu unique de la carte ; il n'est pas renommé (le renommer toucherait ses locales et ses appelants sans rien changer pour l'utilisateur).

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**
- `app/views/shared/_classroom_archive_menu.html.erb` : nouveau local `edit_path:` ; clé `shared.classroom_archive_menu.edit` ajoutée.
- Classe active, dans l'ordre :
  1. `ui_dropdown_item t(".edit"), href: edit_path, icon: "pencil-square", data: { turbo_frame: "modal" }` — « Modifier la classe ».
  2. `ui_dropdown_item t(".archive"), dialog: dialog_id, icon: "archive-box", tone: :danger` — inchangé.
- Classe archivée : `ui_dropdown_item t(".restore") …` — inchangé, seule entrée.
- Appelants : `teams/schools/_classroom_group` passe `edit_path: edit_school_classroom_setting_path(school_public_id, classroom.public_id)` ; `school_admin/levels/_classroom_card` passe `edit_path: edit_school_admin_classroom_setting_path(classroom.public_id)`. Sur la page d'un niveau, le menu n'est rendu que si `manageable` (direction d'un établissement actif), comme aujourd'hui.
- Libellé accessible du menu inchangé : « Actions de la classe 6ème 1 ».

**Tokens**
- Ceux du composant `ui_dropdown` (UDR-0042) ; ton par défaut pour « Modifier », `danger` pour « Archiver ».

**Comportement**
- Le lien ouvre la modale de l'UDR-0110 dans le frame `modal` présent dans la mise en page des deux espaces.
- Sans JavaScript : le lien mène à la page `edit` complète.
- Après succès, la carte est remplacée (UDR-0110) : son menu se reconstruit avec le nouveau nom dans son libellé.

**États obligatoires**
- Vide, chargement, erreur, succès : ceux de la modale (UDR-0110) et du menu (UDR-0083).

**Accessibilité**
- Cible ≥ 48 × 48 px pour chaque entrée (composant `ui_dropdown`) ; à 390 px, le menu reste dans l'écran (`fixed: true`).
- Navigation au clavier : flèches entre « Modifier » et « Archiver », Entrée ouvre, Échap ferme et rend le focus au ⋮.

## 4. Conséquences

- L'UDR-0083 est amendée : le menu ⋮ d'une classe active a deux entrées.
- Toute action future sur une classe s'ajoute à `shared/_classroom_archive_menu`, jamais en bouton sur la carte.
