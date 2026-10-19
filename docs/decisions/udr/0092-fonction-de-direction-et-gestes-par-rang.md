# UDR-0092 : Fonction de direction — à l'inscription, à l'invitation, dans le bloc « Direction » ; gestes masqués au rang vie scolaire
<!-- index
titre: Fonction de direction à l'inscription, à l'invitation et dans le bloc « Direction » ; gestes par rang
statut: Proposé
adr-lie: [0092](../adr/0092-fonctions-de-direction-droits-par-rang-et-changement-de-classe.md)
problematique: Où la direction choisit et lit sa fonction, comment l'équipe la corrige, et quels gestes disparaissent pour l'éducateur et la secrétaire. Amende UDR-0056, 0070 (§3.1, §3.4), 0083.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/espace-direction` |
| **ADR lié** | ADR-0092 |
| **Remplacé par** | — |

---

## 1. Contexte

Le bloc « Direction » (UDR-0070 §3.4) ne montre qu'un nom et une date d'arrivée. Une direction ne sait pas qui, parmi ses collègues, est le chef d'établissement ; l'équipe non plus. Avec l'ADR-0092, une fonction se choisit à l'arrivée et règle les gestes : l'interface doit la demander, l'afficher, et retirer les gestes que le rang « vie scolaire » n'a plus, au lieu de les laisser échouer en 403.

## 2. Décision

- **Un `fieldset` « Fonction » à quatre radios** sur l'inscription de la direction et sur l'invitation par l'équipe, plutôt qu'une liste déroulante : quatre choix courts se lisent d'un coup d'œil au téléphone et se touchent sans ouvrir de menu (même choix que les cycles en radio, UDR-0005 ter).
- **La fonction s'affiche sous le nom**, dans la ligne existante du bloc « Direction », avant la date d'arrivée : pas de colonne de plus.
- **Préciser ou changer une fonction passe par le menu ⋮ de la ligne** (UDR-0042) et une modale à radios, comme le retrait.
- **Un geste refusé n'est pas montré.** Les contrôleurs calculent l'affichage par la policy (jamais par une règle recopiée dans la vue) ; une note dit pourquoi les gestes manquent.

## 3. Règles d'implémentation

### 3.1 Champ « Fonction » — `identity/school_staff_registrations/_form` et `teams/staff_invitations/new`

- Inscription : nouveau `fieldset` entre « Établissement » et « Sécurité » (UDR-0070 §3.1 devient cinq `fieldset`). Invitation : après le numéro.
- `legend` « Votre fonction » (inscription) ou « Fonction » (invitation), classes des autres `legend`.
- Quatre `ui_field form, :position, as: :radio`, valeurs `head`, `deputy`, `educator`, `secretary`, dans cet ordre, aucune cochée par défaut. Libellés par `t("shared.staff_positions.<clé>")`, clé donnée par `Entities::School::StaffPosition.label_key`. À l'inscription, l'établissement n'est pas encore connu : le radio `deputy` se lit « Adjoint au chef d'établissement ou directeur des études » ; à l'invitation, l'équipe est sur la fiche, le libellé suit le type de l'établissement.
- Chaque radio : cible `min-h-tap`, le libellé entier cliquable, `grid gap-2` en une colonne sous `sm`, deux colonnes à partir de `sm`.
- Erreurs, sous le `fieldset`, `role="alert"` relié par `aria-describedby` :
  - vide : « Choisissez votre fonction. » (inscription) / « Choisissez une fonction. » (invitation) ;
  - `head_taken` : « Votre établissement a déjà un chef d'établissement sur Lnclass. Choisissez votre fonction ou contactez l'équipe Lnclass. » (inscription) / « Cet établissement a déjà un chef d'établissement actif. » (invitation).
- La valeur choisie est gardée au re-rendu 422 ; les PIN sont vidés (inchangé).

### 3.2 Libellé dans le bloc « Direction » — `shared/_school_staff`

- Sur chaque `<li id="school_staff_<public_id>">`, sous le nom (`font-medium`), la ligne existante devient : « %{fonction} · Depuis le %{date} · avec le code » (ou « · sur invitation »).
- Sans fonction : « Fonction à préciser », en `text-warning` ; le reste de la ligne en `text-mute`.
- La mention « (vous) » reste après le nom.
- Le libellé de `deputy` suit le type de l'établissement affiché (§4.1 de l'ADR-0092).
- Lu par `Queries::School::SchoolStaffQuery#active_for`, dont la ligne gagne `position` (Lot 0).

### 3.3 « Préciser ma fonction » — direction, sur sa propre ligne

- Rendu seulement si la ligne est celle de la direction connectée **et** sa fonction est vide **et** l'établissement est actif.
- Sur sa propre ligne, qui n'avait pas de menu (UDR-0070 §3.4), un menu ⋮ apparaît avec un seul `ui_dropdown_item` « Préciser ma fonction », icône `identification`, `href: edit_school_admin_staff_position_path(public_id)`, `data: { turbo_frame: "modal" }`.
- Note sous la liste, si la fonction est vide : « Précisez votre fonction : elle décide de vos gestes et ne se changera ensuite que par l'équipe Lnclass. » (`text-xs text-mute`).
- Modale `ui_modal id: "staff-position", title: "Votre fonction", size: :sm` : les quatre radios du §3.1 (libellé `deputy` selon le type), puis « Annuler » et « Enregistrer » (`variant: :brand`, `type: :submit`).
- Vue `school_admin/staff_positions/edit`, chargée à la demande dans le frame `modal` (page complète sans JavaScript, comme la confirmation de retrait d'un enseignant, UDR-0056) ; `form_with url: school_admin_staff_position_path(public_id), method: :patch`. Route du Lot 0 : `resources :staff_positions, only: %i[edit update], path: "staff-positions", param: :public_id`, dans le `scope "school"`.
- Succès : `turbo_stream.replace "school_staff_<public_id>"` (ligne avec sa fonction, sans menu), `turbo_stream.remove` de la note, toast « Votre fonction est enregistrée. »
- Erreurs : `head_taken` → modale re-rendue en 422 avec le message du §3.1 ; 403 (fonction déjà renseignée) → toast « Votre fonction ne se change que par l'équipe Lnclass. »

### 3.4 « Changer la fonction » — équipe, sur la fiche de l'établissement

- Dans le menu ⋮ de **chaque** ligne active du bloc « Direction » de `teams/schools/show`, premier item : « Changer la fonction », icône `identification`, `href: edit_teams_school_staff_member_position_path(school.public_id, public_id)`, `data: { turbo_frame: "modal" }` ; « Retirer de la direction » reste dernier, séparé par un filet.
- Rendu pour les sous-rôles de l'équipe qui retirent déjà une direction (mêmes conditions que « Retirer », UDR-0070 §3.4).
- Modale : titre « Fonction de %{name} », radios du §3.1 avec la valeur actuelle cochée, « Annuler », « Enregistrer ».
- Vue `teams/school_staff_positions/edit`, frame `modal` ; `form_with url: teams_school_staff_member_position_path(school.public_id, public_id), method: :patch`. Route du Lot 0 : `resource :position, only: %i[edit update], controller: "school_staff_positions"`, imbriquée sous `resources :staff_members` de `config/routes/teams.rb` (le nom exact du helper est celui que `bin/rails routes` donne après le Lot 0).
- Succès : ligne remplacée, toast « La fonction de %{name} est enregistrée. » Erreur `head_taken` : 422 dans la modale.
- Restauration d'une direction (UDR-0070 §3.5) refusée pour `head_taken` : toast « Cet établissement a déjà un chef d'établissement actif. Changez d'abord une fonction. »

### 3.5 Gestes masqués au rang « vie scolaire »

Pour une direction `educator` ou `secretary`, les contrôleurs posent les drapeaux d'affichage à `false` par la policy du geste ; les vues ne changent que par ces drapeaux :

| Page | Ce qui disparaît | Drapeau (policy) |
|---|---|---|
| `school_admin/schools/show` | « + » et « − » du bloc « Classes par niveau » ; menu ⋮ « Retirer de la direction » | `@structure_manageable` (`ManageSchoolStructurePolicy`), `@removable` (`RemoveSchoolStaffPolicy`) |
| `school_admin/levels/show`, `_classroom_card` | menus d'archivage de la classe et du niveau (UDR-0083) | `manageable` (`ManageSchoolStructurePolicy`) |
| `school_admin/teachers/index` | « Retirer de l'établissement » | `@manageable` (`ManageSchoolTeachersPolicy`) |
| `school_admin/departed_teachers/index` | « Réintégrer » | `@manageable` (`ManageSchoolTeachersPolicy`) |

- Ce qui **reste** : le lien d'invitation (copie, WhatsApp), la page de classe avec « Changer le lien », « Retirer de la classe », « Changer de classe » (UDR-0093), la recherche d'élève (UDR-0094), toutes les lectures.
- Une note, une seule fois par page touchée, sous le titre du bloc concerné, `text-xs text-mute` : « Votre fonction (%{fonction}) ne permet pas ces gestes. Le chef d'établissement ou son adjoint peut les faire. » Aucune note pour le rang gestion.
- Une requête forgée reçoit 403 et le toast existant de la page (« Vous ne pouvez pas … »).

### 3.6 États

- **Vide** : inchangé (« Aucun compte direction »).
- **Chargement** : `data-turbo-submits-with` « Enregistrement… » sur « Enregistrer ».
- **Erreur** : §3.1, §3.3, §3.4.
- **Succès** : toasts des §3.3 et §3.4.

### 3.7 Accessibilité

- Chaque groupe de radios est un `fieldset` avec `legend` ; l'erreur est annoncée (`role="alert"`) et reliée au groupe.
- Le libellé de fonction n'est pas porté par la seule couleur (« Fonction à préciser » est écrit).
- Menus ⋮ : label « Actions pour %{name} » (inchangé), focus rendu au bouton ⋮ après fermeture de la modale.
- Cibles ≥ 48 px (`min-h-tap`).

## 4. Conséquences

- L'UDR-0070 §3.1 passe à cinq `fieldset` ; §3.4 : la ligne gagne la fonction, la direction peut avoir un menu sur sa propre ligne (« Préciser ma fonction » seulement).
- L'UDR-0056 et l'UDR-0083 : leurs gestes ne sont rendus qu'au rang gestion.
- Aucune vue ne recopie la règle de rang : elle passe toujours par une policy.
- Interdit : afficher une fonction ailleurs que dans le bloc « Direction » ; proposer une fonction libre.
