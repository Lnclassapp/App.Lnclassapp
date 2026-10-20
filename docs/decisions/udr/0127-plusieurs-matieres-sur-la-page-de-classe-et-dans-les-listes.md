# UDR-0127 : Plusieurs matières sur la page de classe et dans les listes — une bande de cours par matière, un badge par fiche à revoir, toutes les matières à côté du nom
<!-- index
titre: Plusieurs matières sur la page de classe, dans les devoirs et à côté du nom
statut: Accepté *(porteur, 2026-10-16 ; matières par établissement)*
adr-lie: [0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md), [0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md)
problematique: La page de classe ne montre que les cours de la matière unique de l'enseignant. Avec plusieurs : bloc « Cours » en une bande par matière (titre badge), fiches à revoir avec badge, exercices assignés et suivi inchangés ; signature « M. Kouassi · PC, SVT » ; colonne « Matières » (badges) pour la direction et l'équipe. Une seule matière : rien ne change. Amende UDR-0027, 0062, 0121, 0071 §3.2, 0052, 0100.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — matières par rattachement enseignant-établissement |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/enseignant-plusieurs-matieres`](../../chantiers/enseignant-plusieurs-matieres/memo.md) — Lots C et D |
| **ADR lié** | [ADR-0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md) §4.5 · [ADR-0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4 (amendé) |
| **Amende** | [UDR-0027](0027-page-classe.md) et [UDR-0062](0062-echeances.md) (bloc « Cours ») · [UDR-0121](0121-fiches-a-revoir-de-la-classe-pour-l-enseignant.md) §3.1 · [UDR-0071](0071-annonces.md) §3.2 (signature) · [UDR-0052](0052-espace-direction-simple.md) (colonne « Matière ») · [UDR-0100](0100-enseignant-partage-vu-par-chaque-direction.md) (ligne d'un retiré) |
| **Remplacé par** | — |

---

## 1. Contexte

Sur la page d'une classe, le bloc « Cours » est le seul chemin de l'enseignant vers les exercices (UDR-0062 §3.4) : il ne montre que les cours de **sa** matière. Un enseignant de PC et SVT de la 3ème 2 ne peut donc pas assigner un exercice de SVT depuis sa classe. Ailleurs, son nom s'accompagne d'**une** matière : signature d'annonce, « Enseignants » de la direction, fiche d'établissement de l'équipe.

## 2. Décision

> **Réponse du porteur (2026-10-16)** : « ses matières » se lit **dans l'établissement de la classe**, qui est l'établissement courant (ADR-0094 §10). La signature d'une annonce lit la liste de l'établissement de l'annonce ; les listes de la direction et de l'équipe, celle de l'établissement affiché ; les comptes de l'équipe comptent un enseignant dans chacune de ses matières.

1. **Une seule matière : rien ne change.**
2. **Une bande par matière** dans le bloc « Cours », dans l'ordre de ses matières : il cherche « un cours de SVT pour la 3ème », pas « un cours parmi vingt ». Une bande unique mélangée l'obligerait à lire chaque badge.
3. **Ce qui montre déjà toutes les matières reste tel quel** : « Exercices assignés » (toutes les assignations de la classe, chacune avec son badge), le suivi d'un exercice, la fiche d'un élève (ADR-0097). Deux enseignants d'une classe y voient déjà le travail l'un de l'autre.
4. **À côté d'un nom, toutes ses matières** : badges dans les listes, noms courts dans la signature.

## 3. Règles d'implémentation

### 3.1 Page de classe — bloc « Cours » (`classroom/classrooms/_courses.html.erb`)

- **Données** : `ClassroomOverviewQuery#courses(level_id, series_id, teacher_id)` filtre par `material_ids` et trie par rang de la matière chez l'enseignant, puis nom du cours. `CourseRow` gagne `material_slug`. L'équipe : inchangé (toutes les matières, une bande).
- **Plusieurs matières** : `courses.chunk_while { _1.material_slug == _2.material_slug }` ; pour chaque groupe :

```erb
<div id="classroom_courses_<%= first.material_slug %>" class="min-w-0">
  <h3 class="mb-2 flex items-center gap-2 text-sm font-semibold text-mute">
    <%= ui_subject_badge first.material_name, category: first.material_category, size: :sm %>
    <span><%= t(".count", count: group.size) %></span>
  </h3>
  <%# la bande existante (data-controller="communication--carousel"), avec les cartes du groupe %>
</div>
```

  Les bandes sont séparées par `space-y-5`. Chaque `ul` garde `aria-label` = « Cours de %{material} » (`band_label`). Les cartes sont **inchangées** (le badge de matière reste : même partial que l'équipe).
- **Une matière sans cours publié** à ce niveau : pas de bande. **Aucun cours du tout** : l'état vide existant.
- **Une matière** : une seule bande, sans `h3` (inchangé).

### 3.2 Page de classe — « Fiches à revoir » (`_gaps.html.erb`, UDR-0121 §3.1, amendée)

- Les fiches sont celles des cours du bloc « Cours », donc de toutes ses matières (ADR-0101 §4.4 amendé).
- **Plusieurs matières** : chaque ligne ajoute `ui_subject_badge … size: :sm` avant le badge « N élèves ». La matière d'une fiche se lit dans `@overview.courses` par `course_slug` : aucune requête de plus.
- Si `remediation-ciblee` n'a pas encore livré le bloc, cette règle s'applique à sa livraison.

### 3.3 Exercices assignés, suivi, cours dans la classe

Inchangés : `_assigned_exercises.html.erb`, `assignment_follow_ups/show.html.erb`, `classroom_courses/show.html.erb` montrent déjà le badge de la matière de chaque exercice ou cours, quel que soit l'enseignant qui l'a assigné.

### 3.4 Signature d'une annonce (`Communication::MessagesHelper#announcement_signature`, UDR-0071 §3.2, amendée)

| Matières | Signature |
|---|---|
| une | « M. Kouassi · SVT » (nom de la matière, inchangé) |
| plusieurs | « M. Kouassi · PC, SVT » (noms courts, dans l'ordre, reliés par « , ») |
| auteur anonymisé | la fonction seule : « SVT » ou « PC, SVT » (inchangé dans son principe) |

`InboxQuery::MessageCard` : `materials: [MaterialTag]` remplace `material_name` ; une requête agrège les matières des auteurs de la page (`teacher_materials` × `materials`, ordre d'ajout).

### 3.5 Listes de la direction et de l'équipe

`school_admin/teachers/index.html.erb` (UDR-0052), `school_admin/departed_teachers/index.html.erb` (UDR-0100), `teams/schools/show.html.erb`, `teams/schools/_join_requests.html.erb`, `classroom/teacher_homes/_pending_colleagues.html.erb` :

- La colonne ou le libellé « Matière » devient « Matières ».
- La cellule rend un `ui_subject_badge(tag.name, category: tag.category, size: :sm)` par matière, dans un `div.flex.flex-wrap.gap-1` ; sans matière (impossible après le Lot 0, gardé pour les données anciennes) : le tiret et le texte `sr-only` existants.
- Les queries (`SchoolTeachersQuery`, `DepartedTeachersQuery`, `JoinRequestsQuery`, `SchoolDetailQuery`) lisent les matières par `Queries::Identity::TeacherMaterialsQuery.tags_for(teacher_ids:)` : **une** requête pour la liste, quel que soit le nombre d'enseignants.
- Téléphone (390 px) : le tableau défile déjà en largeur (`overflow-x-auto`, colonne d'actions collée) ; trois badges passent à la ligne dans leur cellule, sans élargir le tableau.

### 3.6 Référentiel de l'équipe (`teams/materials`)

« N enseignants » d'une matière compte les enseignants qui l'ont **parmi** leurs matières. La suppression reste refusée tant qu'un enseignant la porte (message existant).

**Accessibilité** : `h3` de bande lu avant la bande ; chaque badge porte son texte ; aucun sens porté par la seule couleur.

## 4. Conséquences

- L'enseignant bivalent assigne les exercices de ses deux matières depuis la page de classe, sans passer par un second compte.
- Coût consenti (ADR-0103) : en 3ème, l'enseignant de Maths (6ème) et de PC (3ème) voit aussi une bande « Mathématiques ». Si le porteur le constate à l'usage, la matière par liaison (option D de l'ADR-0103) la retirera.
- Interdit désormais : afficher **une** matière à côté du nom d'un enseignant qui en a plusieurs.
