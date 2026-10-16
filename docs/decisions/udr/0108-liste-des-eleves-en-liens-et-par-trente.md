# UDR-0108 : Liste des élèves de la page classe — le nom mène à la fiche, trente lignes puis « Voir les suivants », sans menu ⋮
<!-- index
titre: Liste des élèves : liens vers la fiche, par trente
statut: Proposé
adr-lie: [0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md)
problematique: Page classe, enseignant et équipe : la photo et le nom de chaque élève mènent à sa fiche (UDR-0107) ; le menu ⋮ et la fenêtre de retrait quittent la ligne pour la fiche ; la liste se lit par groupe de note sur 20 (0–10, 11–15, 16–20, « Pas encore de note », sélecteur à liens `?note=` avec effectifs, premier groupe non vide par défaut, colonne « Note »), 30 élèves puis « Voir les N suivants » dans un groupe ; recherche sur toute la classe ; aucune moyenne de classe. Amende UDR-0027, UDR-0054 §3.9, UDR-0077 §3.4, UDR-0081 §3.7
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/rapports-de-classe`](../../chantiers/rapports-de-classe/prd.md) |
| **ADR lié** | [ADR-0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md) §4.7 (pagination), [ADR-0067](../adr/0067-budgets-de-temps-serveur-des-ecrans.md) (budget) |
| **Amende** | [UDR-0027](0027-page-classe.md) (« les lignes ne sont pas des liens ») · [UDR-0054](0054-finitions-d-interface.md) §3.9 (recherche d'un élève) · [UDR-0077](0077-organisation-des-ecrans-enseignant.md) §3.4 (code de récupération dans le menu ⋮) · [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) §3.7 (retrait dans le menu ⋮) |
| **Remplacé par** | — |

---

> **Amendée le 2026-10-16 par le porteur (réponse à Q5)** : la liste n'est pas découpée en pages de trente sans ordre,
> mais **par note sur 20**. Voir [§3.8](#38-groupes-de-note-amendement-du-2026-10-16). Les §3.2 (ligne), §3.3 (compteur et
> « Voir les suivants », à l'intérieur d'un groupe) et §3.4 restent en vigueur.

## 1. Contexte

La liste « Élèves » de la page de la classe rend tous les élèves présents, chacun avec un menu ⋮ et une fenêtre de confirmation de retrait. Avec 55 élèves elle pèse 147,7 Ko, et la page dépasse son budget (231,6 Ko, 153 ms p95). Une classe peut compter 150 élèves. Les lignes ne mènent nulle part : la fiche d'un élève n'existait pas.

## 2. Décision

1. **Le nom est la porte de la fiche.** La photo et le nom forment un seul lien. Le score de la dernière session et son lien « Voir le résultat » restent à droite, comme avant.
2. **Les actions sur un élève vivent sur sa fiche** (Q4). La ligne perd son menu ⋮ et sa fenêtre : c'est la plus grosse part de son poids.
3. **Trente, puis « Voir les suivants ».** Pas de numéros de page : sur téléphone ils ne servent à rien, et les nouveaux, en tête, n'ont de sens qu'au début. Le bouton remplace la liste par une liste plus longue, dans le même cadre. Sans JavaScript, c'est un lien qui rend la page avec la liste plus longue.
4. **La recherche reste le chemin court**, sur toute la classe.

## 3. Règles d'implémentation

> Contrat d'exécution. Fichier : `app/views/classroom/classrooms/_roster.html.erb`. Le reste de la page ne change pas.

### 3.1 Signature du partial (gelée au Lot 0)

`locals: (classroom:, students:, search: "", total: @overview&.students_total.to_i, page: @page || 1, new_count: …, can_remove: …, focus_title: false)`

- `total` : le nombre d'élèves qui répondent à la recherche (toute la classe sans recherche), `Overview#students_total`.
- `page` : la page rendue, ≥ 1.
- `can_remove` reste dans la signature pour le stream de retrait (`classroom_students/destroy.turbo_stream.erb`), qui ne change pas d'appel ; la liste ne l'utilise plus.

### 3.2 Ligne d'un élève

`li#student_<public_id>`, `flex items-center gap-3 px-4 py-3` (inchangé). Dans la partie gauche :

- `link_to classroom_student_path(classroom.public_id, student.public_id), data: { turbo_frame: "_top" }, class: "flex min-w-0 flex-1 items-center gap-3 rounded-ln focus-visible:outline-2 focus-visible:outline-brand"` qui contient l'avatar et le bloc du nom existant (nom, pastille « Nouveau », voie, « fait seul » du téléphone, numéro masqué). Le nom prend `group-hover:underline underline-offset-4` (le lien porte `group`).
- **Supprimés** de la ligne : le `ui_dropdown` ⋮ et la `ui_modal` de retrait, avec leur `form`.
- La partie droite garde « Fait seul (7 j) » (ordinateur) et « Dernière note » avec « Voir le résultat ». Ce lien reste hors du lien du nom : jamais de lien imbriqué.
- Le `ui_icon_sprite` du cadre ne garde que les icônes encore utilisées.

### 3.3 Compteur et bouton « Voir les suivants »

- `#classroom_roster_count` (inchangé de place, `aria-live="polite"`) : « 55 élèves » quand toute la liste est rendue ; « 30 sur 55 » sinon (`t(".count_partial", shown:, total:)`). Avec une recherche : « 30 sur 40 ».
- Sous la `ul`, si `students.size < total` : `div.mt-4.flex.justify-center` avec `ui_button t(".more", count: [ total - students.size, 30 ].min), href: classroom_path(classroom.public_id, q: search.presence, page: page + 1, anchor: "classroom_roster"), variant: :secondary, icon: "chevron-down", data: { turbo_frame: "classroom_roster_list", turbo_action: "replace" }`. Libellé : « Voir les 30 suivants », « Voir les 10 suivants », « Voir le dernier » (`one`).
- Le cadre `classroom_roster_list` est remplacé par sa version plus longue. Le défilement ne bouge pas : la liste grandit sous les yeux.
- **Après le remplacement**, le focus va au lien de la première ligne ajoutée : quand `page > 1`, le lien de la ligne d'indice `30 × (page - 1)` porte l'attribut `autofocus`, que Turbo honore au rendu d'un cadre. Aucun contrôleur nouveau. Les lecteurs d'écran entendent le compteur mis à jour.
- La recherche (formulaire existant) ne transmet pas `page` : une recherche repart des 30 premiers.

### 3.4 Sans JavaScript

Le bouton est un lien. Il ouvre la page de la classe avec `page=2` et l'ancre `#classroom_roster` : la page entière s'affiche avec les 60 premiers élèves.

### 3.5 États obligatoires

| État | Rendu |
|---|---|
| **Vide** — classe sans élève | inchangé (`#classroom_roster_empty`) |
| **Vide** — recherche sans résultat | inchangé (« Aucun élève ne correspond », bouton « Effacer la recherche ») |
| **Chargement** | `aria-busy` posé par Turbo sur le cadre → `opacity-50` (inchangé) |
| **Erreur** | inchangé : le contrôleur `search` pose l'état d'erreur du cadre ; un `page` invalide n'est pas une erreur (première page) |
| **Succès** | 30 × `page` lignes au plus, compteur, bouton tant qu'il en reste |

### 3.6 Accessibilité

- Le lien de la ligne a pour nom accessible le nom de l'élève, puis « Nouveau » s'il l'est (texte déjà dans le lien) ; l'avatar est `aria-hidden` dans le lien.
- Cible du lien : toute la hauteur de la ligne (≥ 48 px avec `py-3` et l'avatar `sm`).
- Bouton « Voir les suivants » : ≥ 48 px de haut (`ui_button` taille `md`).

### 3.7 Libellés — `config/locales/classroom/classrooms.fr.yml` (Lot 0)

`classroom.classrooms.roster` : `count_partial` (« %{shown} sur %{total} »), `more` (one : « Voir le dernier » ; other : « Voir les %{count} suivants »), `open_file` (sr-only si nécessaire : « Ouvrir la fiche de %{name} »). Les clés `actions_label`, `issue_code`, `remove*` et `cancel` passent à `classroom.classroom_students.show` (UDR-0107 §3.10) ; celles que plus rien ne lit sont supprimées. `open_file` n'a pas servi (le nom du lien est celui de l'élève) : supprimée au Lot B avec `actions_label`, `issue_code`, `issue_code_hint`, `remove`, `remove_title`, `remove_warning`, `remove_confirm` et `cancel` ; `removed` (toast) reste.

### 3.8 Groupes de note (amendement du 2026-10-16)

Décision du porteur : la liste se lit **par groupe de note sur 20**, un groupe à la fois.

- **Note d'un élève** : la moyenne, sur 20, de ses meilleurs scores aux exercices assignés **actifs** de cette classe (sessions
  faites rattachées à l'assignation, remédiation comprise, ADR-0079 §4.1), arrondie par `Entities::Assessment::Grading.grade_on_20`.
  Règle du domaine : `Entities::Classroom::RosterGrade`. Lue en **une requête** pour toute la classe (`ClassroomOverviewQuery`).
- **Groupes** : « 0 à 10 », « 11 à 15 », « 16 à 20 », puis « Pas encore de note » (aucun exercice assigné fait). Clés `0-10`,
  `11-15`, `16-20`, `none`.
- **Sélecteur** : `nav#classroom_roster_groups[aria-label="Élèves par note sur 20"]`, dans le cadre `classroom_roster_list`, une
  grille `grid-cols-2 sm:grid-cols-4` de quatre liens (≥ 48 px) : libellé du groupe et nombre d'élèves. Le groupe courant porte
  `aria-current="true"`, `border-brand bg-brand-soft`. Chaque lien vise `classroom_path(classe, note: clé, anchor: "classroom_roster")`
  avec `data-turbo-action="advance"` : il remplace le cadre avec JavaScript, recharge la page sans.
- **Par défaut** : le premier groupe non vide en partant de « 0 à 10 ». Un groupe demandé et connu est gardé, même vide (état
  vide « Aucun élève dans ce groupe ») ; un groupe inconnu vaut le défaut.
- **Dans un groupe** : l'ordre existant (nouveaux en tête, puis nom), trente puis « Voir les 30 suivants » (§3.3), qui garde `note`.
- **Recherche** : elle porte sur **toute la classe**, sans groupe courant ; « Voir les suivants » garde `q`. Les comptes du
  sélecteur restent ceux de toute la classe.
- **Ligne** : une colonne « Note » (`#grade_<public_id>`, « 12/20 », « — » sans note), à gauche de « Fait seul » et de « Dernier score ».
- **Interdit** : une moyenne de la classe (porteur, Q7 confirmée).

## 4. Conséquences

- La page de la classe ne grossit plus avec l'effectif à l'ouverture. Mesure avant et après au Lot B, consignée au journal.
- Le code de récupération et le retrait demandent un geste de plus : ouvrir la fiche. Le retrait par la direction, depuis sa propre page, ne change pas.
- Le stream du retrait (`destroy.turbo_stream.erb`) continue de remplacer `#classroom_roster` : la liste qu'il rend repart des 30 premiers.
- Interdit désormais : un menu ⋮ sur une ligne d'élève de la page classe ; une liste d'élèves de la page classe sans limite.
