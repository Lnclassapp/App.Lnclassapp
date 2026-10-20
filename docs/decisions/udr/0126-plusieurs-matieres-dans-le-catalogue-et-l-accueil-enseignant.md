# UDR-0126 : Plusieurs matières dans le catalogue et l'accueil de l'enseignant — toutes ensemble, rangées par matière, un filtre « Matière » limité aux siennes
<!-- index
titre: Plusieurs matières dans le catalogue et l'accueil de l'enseignant
statut: Accepté *(porteur, 2026-10-16 ; matières par établissement)*
adr-lie: [0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md)
problematique: Le catalogue, l'accueil et l'en-tête de l'enseignant ne connaissent qu'une matière. Avec plusieurs : catalogue groupé par matière (titres de groupe de l'élève), filtre « Matière » réduit aux siennes (≥ 640 px) ; en-tête de l'accueil, un badge par matière ; bulles « Cours » par niveau, illustration générique, vers toutes ses matières ; « Activités » avec badge ; score moyen sur toutes. Une seule matière : rien ne change. Amende UDR-0026, 0069, 0077.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) — matières par rattachement enseignant-établissement |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/enseignant-plusieurs-matieres`](../../chantiers/enseignant-plusieurs-matieres/memo.md) — Lot B |
| **ADR lié** | [ADR-0103](../adr/0103-matieres-de-l-enseignant-par-une-table-de-jointure.md) §4.5 |
| **Amende** | [UDR-0077](0077-organisation-des-ecrans-enseignant.md) §3.1 et §3.2 · [UDR-0069](0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md) §3.3 · [UDR-0026](0026-accueil-enseignant.md) (score moyen) |
| **Remplacé par** | — |

---

## 1. Contexte

Le catalogue de l'enseignant ne montre que **sa** matière (UDR-0077 §3.2), sans liste « Matière ». Son accueil porte un badge de matière, des bulles « Cours » à l'illustration de cette matière, un score moyen et des « Activités » limités à elle (UDR-0026, UDR-0069, UDR-0077 §3.1). Un enseignant de PC et SVT n'y trouve jamais la SVT.

## 2. Décision

> **Réponse du porteur (2026-10-16)** : « ses matières » se lit **dans l'établissement courant** (ADR-0103 §4). Changer d'établissement depuis le compte change aussi les matières de l'accueil, du catalogue et de l'en-tête ; aucun second sélecteur.

1. **Règle d'or : une seule matière, aucun écran ne change.** Tout ce qui suit ne s'applique qu'au-delà d'une matière (`materials.size > 1`).
2. **Toutes ses matières ensemble**, pas de « matière courante » à basculer (memo Q5) : un enseignant de PC et de SVT de la même classe ne doit pas changer de mode entre deux gestes.
3. **Rangé par matière** : le catalogue reprend les titres de groupe de l'élève (UDR-0085 §3.2), déjà dessinés et testés.
4. **Un filtre « Matière »** sur ordinateur, limité à ses matières : c'est le seul endroit où il veut en isoler une.
5. **Pas de produit cartésien** sur l'accueil : une bulle par niveau, comme aujourd'hui, et non une bulle par (matière, niveau), qui inventerait « Maths 3ème » pour un enseignant qui ne fait que de la PC en 3ème.

## 3. Règles d'implémentation

### 3.1 Catalogue (`catalog/courses/index.html.erb`, `_page.html.erb`)

- **Données** : `TeacherAudienceQuery::Scope(audience:, material_ids:)` ; `CourseCatalogQuery#call(material_ids:, group_by_material:)` ; `group_by_material: true` pour l'enseignant de plusieurs matières, qui calcule `material_counts` comme pour l'élève.
- **Sous-titre** : une matière, inchangé (« Les cours de %{material}, aux niveaux de vos classes. ») ; plusieurs, `teacher_subtitle_many` : « Les cours de %{materials}, aux niveaux de vos classes. », `materials` = noms reliés par `to_sentence` (« Physique-Chimie et SVT »).
- **Groupes** : la condition qui groupe les cartes de l'élève (`student`) devient `student || teacher_grouped` ; même partial `_course_group_title`, même `after_material` d'une page à l'autre, même `id="courses_group_<slug>"`.
- **Cartes** : inchangées ; le badge de matière reste (amendement du 2026-10-06 bis de l'UDR-0077).
- **Filtre « Matière »** (≥ 640 px, là où les filtres existent déjà) : `select` `material`, options « Toutes vos matières » (`""`) puis ses matières dans l'ordre, après « Niveau » et « Série ». Absent pour une seule matière (inchangé).
- **`?material=<slug>` hors de ses matières** (lien partagé) : aucun cours, état vide existant avec « Tout voir ». Aucune erreur.
- **Téléphone (390 px)** : pas de filtre (UDR-0077, décision du porteur) ; les groupes par matière font le tri.

### 3.2 Accueil — en-tête (`classroom/teacher_homes/show.html.erb`)

- Le bloc de `ui_page_header` rend un `ui_subject_badge(tag.name, category: tag.category)` **par matière**, dans l'ordre, dans un `div.flex.flex-wrap.gap-1.5`. Une matière : un badge, comme aujourd'hui.
- `TeacherHomeQuery::Row` : `materials: [MaterialTag]` remplace `material_name`, `material_category`, `material_slug`.

### 3.3 Accueil — bulles « Cours » (`classroom/teacher_homes/_course_levels.html.erb`)

| | Une matière (inchangé) | Plusieurs matières |
|---|---|---|
| Bulles | une par couple (niveau, série) des classes de l'année | **idem** |
| Illustration | `subject_illustration(slug)` | `subject_illustration(nil)` (illustration générique) |
| Lien | catalogue `level`, `series`, `material` | catalogue `level`, `series`, **sans** `material` (toutes ses matières, groupées) |
| `sr_suffix` | « , cours de %{material} » | « , cours de vos matières » (`sr_level_many`) |
| Sous-titre de la carte | « Les cours de vos niveaux en %{material} » | « Les cours de vos niveaux, dans vos matières » (`courses_subtitle_many`) |

### 3.4 Accueil — classes et « Activités »

- **Score moyen** (UDR-0026, amendé) : moyenne des sessions terminées des élèves présents sur les exercices de **ses matières**. Libellé inchangé. L'enseignant d'une matière lit le même chiffre qu'avant.
- **« Activités »** (UDR-0077 §3.1, amendé) : les assignations d'un exercice de **l'une de ses matières**. Avec plusieurs matières, chaque ligne ajoute `ui_subject_badge(row.material_name, category: row.material_category, size: :sm)` avant le nom de la classe (`TeacherFollowUpsQuery::Row` gagne `material_name`, `material_category`). Une matière : pas de badge (inchangé).

### 3.5 En-tête du shell (`ShellUserQuery#teacher_detail`)

- Une matière : « Physique-Chimie · Lycée X » (inchangé).
- Plusieurs : les noms courts reliés par « , » : « PC, SVT · Lycée X ». La ligne garde sa troncature (`truncate`).

**États** : vides inchangés (aucune classe, aucun cours, aucune activité). **Accessibilité** : chaque badge a son texte ; le `select` « Matière » a son `label` ; les titres de groupe sont des `h2` comme chez l'élève.

## 4. Conséquences

- L'enseignant de plusieurs matières voit des groupes dans son catalogue, comme l'élève : un seul dessin pour deux rôles.
- Interdit désormais : une bulle « Cours » par (matière, niveau) ; un sélecteur de matière dans le menu du compte ; une lecture « sa matière » au singulier dans les queries de l'accueil et du catalogue.
- Les illustrations par matière restent sur l'accueil de l'enseignant d'une seule matière, la grande majorité.
