# UDR-0146 : Les libellés courts des matières dans Cours de l'élève
<!-- index
titre: Libellés courts des matières (Cours de l'élève)
statut: Accepté
adr-lie: —
problematique: Les noms entiers des matières alourdissent les pastilles « Matières » (ordinateur) et les titres de groupe (téléphone) de Cours ; le porteur veut « Maths », « PC », « HG ».
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/libelles-courts-matieres` |
| **ADR lié** | — |
| **Remplacé par** | — |

---

## 1. Contexte

Sur ordinateur, l'élève choisit sa matière dans Cours par leçons par des pastilles (`#lesson_materials`, CA-E15) ; sur téléphone, Cours range ses fiches sous un titre par matière (`#courses_group_<slug>_title`, UDR-0085 §3.2). « Mathématiques », « Histoire-Géographie », « Physique-Chimie » y prennent de la place et cassent la ligne ; les élèves disent « Maths », « HG », « PC ».

## 2. Décision

Ces pastilles, et sur téléphone les titres de groupe du même écran, montrent le libellé court de la matière (le porteur a ajouté le téléphone en cours de lot). Le nom entier reste partout ailleurs (h1 et titre de la vue d'une matière, grille de l'accueil élève, homepage, catalogue public, profil, référentiel) : le porteur l'a tranché au cadrage. Le libellé court vient de la table I18n existante `shared.subjects.short` (par slug figé), déjà lue par « Mon compte » de l'enseignant ; la donnée ne change pas.

## 3. Règles d'implémentation

**Structure**
- `app/views/catalog/courses/index.html.erb`, `nav#lesson_materials` : le libellé de chaque pastille vient de `subject_short_label(slug)` (`ComponentsHelper`), qui rend `shared.subjects.short.<slug>` ou `nil`.
- Avec un libellé court : `<span aria-hidden="true">Maths</span><span class="sr-only">Mathématiques</span>`, et `title="Mathématiques"` sur le lien. Sans : le nom entier, sans `title`, comme avant.
- Même règle que `ui_subject_bubble short_label:` (UDR-0084 §3.5).
- `app/views/catalog/courses/_course_group_title.html.erb` (téléphone) : le texte visible du titre est le libellé court, sinon le nom entier ; le lien garde son `aria-label` (« matière, n cours », UDR-0085 §3.7), qui porte le nom entier, et prend `title` = nom entier quand un libellé court s'affiche. Pas de `sr-only` : l'`aria-label` le rend inutile.

**Tokens**
- Inchangés : la pastille garde ses classes ; seul le texte change.

**Comportement**
- Aucun : liens, `aria-current`, mémoire de la matière en session inchangés.

**États obligatoires**
- Pastille active et inactive : même libellé court. Matière sans entrée : nom entier.

**Accessibilité**
- Le nom accessible de chaque lien reste le nom entier (« Mathématiques ») ; le court est muet. Cibles ≥ 48 px inchangées.

## 4. Conséquences

- Une nouvelle abréviation s'ajoute dans `shared.subjects.short`, jamais dans la vue ni en base.
- Un autre écran ne passe aux libellés courts que par une nouvelle décision du porteur.
- `materials.shortname` (en base) n'est pas lu ici ; les deux sources sont à unifier si l'usage s'étend.
