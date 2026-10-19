# UDR-0093 : « Changer de classe » sur la page d'une classe de la direction
<!-- index
titre: Changer un élève de classe depuis la page de classe de la direction
statut: Proposé
adr-lie: [0092](../adr/0092-fonctions-de-direction-droits-par-rang-et-changement-de-classe.md)
problematique: Où la direction change un élève de classe, comment elle choisit la classe cible, et ce que voient l'ancienne et la nouvelle classe. Amende UDR-0081 §3.7.
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

Un élève inscrit dans la mauvaise classe ne peut être que retiré (UDR-0081 §3.7) ; il doit ensuite rechoisir seul, et le retrait l'empêche de revenir sans le lien. La direction, qui connaît les listes officielles, veut le mettre elle-même dans la bonne classe, souvent depuis son téléphone, au milieu d'une liste de 60 élèves.

## 2. Décision

- **Le geste vit dans le menu ⋮ de la ligne de l'élève**, juste au-dessus de « Retirer de la classe » : c'est là que la direction agit déjà sur un élève (UDR-0081 §3.7).
- **La classe cible se choisit dans une modale à radios groupés par niveau**, plutôt qu'une liste déroulante : 30 à 60 classes se parcourent mieux en groupes visibles, et un radio se touche sans ouvrir de menu. Le niveau de l'élève est ouvert en premier.
- **Une seule confirmation** : cocher la classe puis « Changer de classe » ; pas de seconde modale. Le toast nomme la classe obtenue.
- **La ligne quitte la liste par Turbo Stream**, comme au retrait ; sans JavaScript, la modale est une page complète et la confirmation revient sur la classe.

## 3. Règles d'implémentation

### 3.1 Entrée — `school_admin/classrooms/show`

- Dans le menu ⋮ de chaque ligne d'élève (lignes numérotées, UDR-0081 §3.7), avant « Retirer de la classe » et sans filet entre eux : `ui_dropdown_item` « Changer de classe », icône `arrows-right-left`, `href: new_school_admin_student_move_path(classroom.public_id, student.public_id)`, `data: { turbo_frame: "modal" }`.
- Rendu seulement si la classe est active et l'établissement actif (`MoveStudentPolicy`, drapeau `@movable` du contrôleur). Toutes les fonctions de direction le voient.
- La voie d'arrivée sous le nom gagne `transfer` → « Changé de classe » (même `text-xs text-mute`), ici et dans `classroom/classrooms/_roster` (enseignant).

### 3.2 Modale — `school_admin/student_moves/new`

- `ui_modal id: "student-move", title: "Changer %{name} de classe", size: :md`, dans le frame `modal` ; sans frame, la même page dans le shell (comme `teachers#removal`).
- Sous le titre, `text-sm text-mute` : « Aujourd'hui en %{classe}. Ses résultats passés restent ; il verra les devoirs de sa nouvelle classe. »
- `form_with url: school_admin_student_moves_path(classroom.public_id, student.public_id), method: :post, id: "student-move-form"`.
- Les classes cibles : `Queries::School::MoveTargetsQuery#call(school_id:, except_classroom_id:)` → niveaux dans l'ordre de l'établissement, chacun avec ses classes actives de l'année, triées par nom ; ni la classe actuelle, ni une classe archivée.
- Un `<details>` par niveau (`open` pour le niveau de l'élève, fermés sinon), `summary` « %{niveau} · %{n} classes », `min-h-tap`. Dans chacun, une `grid grid-cols-2 gap-2 sm:grid-cols-3` de `ui_field form, :target, as: :radio, value: classroom.public_id`, libellé « %{nom} », sous-libellé `text-xs text-mute` « %{effectif} / %{plafond} ».
- Une classe pleine est rendue `disabled`, sous-libellé « Pleine » (`text-warning`), pour qu'elle reste lisible.
- Aucun niveau n'a de classe cible : `ui_empty_state` « Aucune autre classe active dans votre établissement. », icône `building-library`, et seul « Fermer ».
- Boutons : « Annuler » (ferme), puis `ui_button` « Changer de classe » (`variant: :brand`, `type: :submit`, `data-turbo-submits-with` « Changement… »). Libellé fixe : aucun JavaScript nouveau. Envoyé sans classe cochée → 422 « Choisissez une classe. »

### 3.3 Réponses — `school_admin/student_moves#create`

- **Succès** (Turbo Stream) : `turbo_stream.remove "student_<public_id>"` ; `turbo_stream.replace` du titre de la liste (compteur et pastille « Nouveau ») ; état vide de la liste si elle devient vide (comme au retrait) ; fermeture de la modale ; toast « %{name} est maintenant en %{classe}. »
- **Succès sans JavaScript** : 303 vers `school_admin_classroom_path(classroom.public_id)`, toast en `flash`.
- **422** (`already_member`, `classroom_full`) : modale re-rendue, message `role="alert"` en tête : « %{name} est déjà dans cette classe. » / « La classe %{classe} est pleine. » ; le radio coché reste coché.
- **403** (classe archivée) : toast « Rien ne bouge dans une classe archivée. »
- **404** (hors établissement, élève déjà parti) : toast « Introuvable. Rechargez la page. »

### 3.4 Ce que voit la nouvelle classe

- Côté enseignant (`classroom/classrooms/_roster`) et côté direction : l'élève est « Nouveau » (règle de l'UDR-0081 §3.7) avec la voie « Changé de classe ».
- Côté ancienne classe : l'élève n'apparaît plus ; il ne figure pas parmi les retirés.

### 3.5 Accessibilité

- Les radios d'un niveau forment un `fieldset` dont la `legend` (`sr-only`) est le nom du niveau ; le `summary` du `<details>` reprend ce nom.
- Une classe pleine est `disabled` **et** dit « Pleine » en texte.
- Après fermeture de la modale, le focus revient au ⋮ de la ligne suivante (ou au titre de la liste si c'était la dernière).
- Cibles ≥ 48 px ; ordre de tabulation : niveaux, classes, « Annuler », « Changer de classe ».

## 4. Conséquences

- L'UDR-0081 §3.7 : le menu ⋮ d'une ligne d'élève de la direction a deux items ; la voie d'arrivée a une valeur de plus.
- Le changement de classe n'existe pas côté enseignant ni côté équipe.
- Interdit : déplacer un élève par glisser-déposer, ou depuis une autre page que celle de sa classe.
