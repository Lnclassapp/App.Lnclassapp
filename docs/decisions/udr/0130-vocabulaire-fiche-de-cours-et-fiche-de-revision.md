# UDR-0130 : Vocabulaire d'interface — « Fiche de cours » et « Fiche de révision »
<!-- index
titre: Vocabulaire « Fiche de cours » et « Fiche de révision »
statut: Proposé
adr-lie: —
problematique: « Cours » devient « Fiche de cours » et « Fiche essentielle » devient « Fiche de révision » à l'écran ; la rubrique « Cours » garde son nom ; « Révisions de la leçon » ; « Fiche(s) à revoir ». Remplace la ligne `Essential` et l'amendement du 2026-09-30 de l'UDR-0007. Numéro 0084 pris sur Develop le 2026-10-15, renuméroté 0130
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-12 |
| **Chantier** | `docs/chantiers/renommage-fiche-revision` |
| **ADR lié** | — (aucun contrat ne bouge : `Course`, `Essential`, routes et clés d'import inchangés) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe a dessiné de nouvelles fiches (fiche de cours, fiche de révision, exercices), que Lnclass va intégrer. À l'écran, les mêmes objets s'appellent encore « Cours » et « Fiche essentielle ». Un élève qui lit « fiche de révision » sur le contenu et « fiche essentielle » dans le titre ne sait pas qu'il s'agit du même objet. Un agent qui lit deux mots écrit deux clés.

Le porteur a tranché le 2026-10-12, au grill du chantier `renommage-fiche-revision`.

## 2. Décision

**Le nom de l'objet change, la rubrique garde son nom court.**

| Concept (code) | Terme d'interface | Pluriel | Genre | Interdits à l'écran |
|---|---|---|---|---|
| `Course` | Fiche de cours | Fiches de cours | féminin | « cours » pour nommer l'objet (hors exceptions ci-dessous), Leçon |
| `Essential` | Fiche de révision | Fiches de révision | féminin | Fiche essentielle, Essentielle(s), Essentiel, Habileté, Notion(s) clé(s), Leçon |

Trois exceptions, et trois seulement :

1. **La rubrique « Cours »** garde son mot court, parce que c'est une rubrique et non le nom d'un objet, et parce que « Fiches de cours » passerait sur deux lignes dans la barre mobile à 390 px. Elle seule le garde : les sections d'une page, les en-têtes de colonnes et les compteurs nomment l'objet et disent « Fiches de cours ». La rubrique couvre :
   - l'entrée de navigation ;
   - le titre de la page du catalogue et le titre de son onglet ;
   - le lien retour vers ce catalogue.
2. **« Révisions de la leçon »** est le titre de la liste des fiches de révision d'une fiche de cours. « Leçon » y désigne la fiche de cours parente. Il remplace « Essentielles de la leçon ».
3. **« Fiche à revoir »** / **« Fiches à revoir »** est le titre d'une lacune en attente : « Fiche de révision à revoir » est redondant. Seuls ces deux titres admettent « Fiche » seul.

Le mot « cours » au **sens scolaire courant** reste libre (« comprendre leurs cours », « Révise l'essentiel du cours »), de même que « en cours ».

## 3. Règles d'implémentation

**Structure**

- Seules les **valeurs** des fichiers `config/locales/**/*.fr.yml` changent. Aucune clé n'est renommée et aucune vue ne change de structure : les vues lisent déjà `t(".key")`.
- Une valeur qui nomme l'objet `Course` dit « fiche de cours », une valeur qui nomme l'objet `Essential` dit « fiche de révision », avec la casse de la phrase (« Fiche de cours » en début de phrase).
- **Accords** : les deux termes sont féminins. Chaque participe, adjectif, déterminant et pronom est accordé.
  - « créé » devient « créée », « publié » devient « publiée », « archivé » devient « archivée », « assigné » devient « assignée ».
  - « Aucun » devient « Aucune », « ce » / « le » devient « cette » / « la », « un » devient « une », « il » devient « elle ».
- **Comptes** : « %{count} cours », invariable, devient `one: "%{count} fiche de cours"` / `other: "%{count} fiches de cours"`. Une clé `zero` existante devient « Aucune fiche de cours ».
- **Valeurs exactes imposées** :

| Clé | Valeur |
|---|---|
| `shared.navigation.courses` (entrée de navigation) | « Cours » (inchangé) |
| `catalog.courses.index.page_title`, `catalog.courses.index.title` | « Cours » (inchangé) |
| `catalog.courses.show.back` | « Cours » (inchangé) |
| `catalog.courses.show.essentials_title` | « Révisions de la leçon » |
| `classroom.classroom_courses.show.essentials_title` | « Révisions de la leçon » |
| `catalog.courses.show.content_title` | « Contenu de la fiche de cours » |
| `catalog.essentials.show.eyebrow` | « Fiche de révision · %{course} » |
| `catalog.essentials.show.student_eyebrow` | « Fiche de révision » |
| `catalog.essentials.show.gap_title` | « Fiche à revoir » |
| `classroom.student_classrooms.pending_gaps.title` | « Fiches à revoir » |
| `shared.home.sections.courses.title`, `classroom.teacher_homes.show.courses_title`, `classroom.classrooms.courses.title` | « Fiches de cours » (sections d'une page, pas la rubrique) |
| `teams.levels.index.columns.courses`, `teams.series.index.columns.courses`, `teams.materials.index.columns.courses` | « Fiches de cours » |
| `classroom.student_classrooms.show.courses_title` | « Fiches de cours assignées » |
| `import_kinds.essentials` | « Fiches de révision » |
| `import_kinds.course_tree` | « Fiches de cours complètes » |
| `teams.courses.create.created` | « Fiche de cours « %{name} » créée (brouillon). » |
| `teams.essentials.create.created` | « Fiche de révision « %{name} » créée (brouillon). » |
| `teams.essentials.transition.parent_not_published` | « La fiche de cours de cette fiche de révision n'est pas publiée : publiez d'abord la fiche de cours. » |
| `teams.exercises.transition.refusals.parent_not_published` | « Publiez d'abord la fiche de révision et sa fiche de cours. » |
| `communication.pages.terms.sections.contenu.paragraphs` (1er paragraphe) | « Les fiches de cours, fiches de révision et exercices sont publiés par Lnclass… » ; `updated_on` inchangé |

**Tokens**

- Sans objet : aucune valeur visuelle ne change.
- Un en-tête de colonne qui passe de « Cours » à « Fiches de cours » (tableaux des niveaux, séries et matières de l'équipe) garde ses classes et peut passer à la ligne. Il ne se tronque jamais.

**Comportement**

- Aucun Turbo Frame, Turbo Stream ni contrôleur Stimulus ne change.
- Les adresses restent `/courses/:course_slug/essentials/:slug`, sans redirection.

**États obligatoires**

- Vide :
  - « Aucune fiche de cours pour l'instant »
  - « Aucune fiche de révision pour cette fiche de cours. »
  - « Aucun exercice pour cette fiche de révision. »
- Erreur : « La fiche de cours de cette fiche de révision n'est pas publiée : publiez d'abord la fiche de cours. »
- Succès : les toasts de l'équipe, dans les valeurs ci-dessus, accordés au féminin.
- Chargement : sans objet (aucun nouvel état asynchrone).

**Accessibilité**

- Les `aria-label` et textes réservés aux lecteurs d'écran qui nomment ces objets suivent la même règle, par exemple « Actions sur la fiche de cours « %{name} » » et « , fiches de cours de %{material} ».

## 4. Conséquences

- **UDR-0007** : la ligne `Essential` du §2 et l'amendement du 2026-09-30 (« Essentielles de la leçon ») sont **remplacés** par la présente UDR. Le reste de l'UDR-0007 (exercice, session, tentative, proposition, badges) reste en vigueur.
- **Glossaire** (§3, §8) : l'interface de `Course` est « Fiche de cours », l'interface de `Essential` est « Fiche de révision ». Les interdits d'écran s'enrichissent de « Fiche essentielle ». Le code garde `Course` et `Essential` ; `Fiche`, `Sheet` et `Lesson` restent interdits dans le code.
- **Garde de vocabulaire** (`test/i18n/locale_files_test.rb`) :
  - le motif interdit ajoute `essentielle` ;
  - l'exception `ALLOWED` passe à « Révisions de la leçon » sous les deux mêmes clés.
- **Contenus** (`docs/contenus/`) : le prompt de rédaction et le guide parlent de « fiche de révision ». Les clés JSON (`essentials`) ne changent pas.
- Les chantiers `contenu-en-blocs` et `questions-enrichies` écrivent leurs textes avec ces termes dès leur cadrage.

## 5. Amendements

### 2026-10-19 — Les textes arrivés par `Develop` depuis le 12/10 (Lot E du chantier)

Deux décisions du porteur, prises à la reprise du chantier après la fusion de `Develop` :

1. **Catalogue public** (`catalog.public.*`, `catalog.level_pages.*`, `catalog.series_pages.*`, `catalog.material_pages.*`, `communication.public_pages.catalog`) : **tout** se renomme, titres compris.
   - « Les cours par niveau » devient « Les fiches de cours par niveau », « Cours de %{level} » devient « Fiches de cours de %{level} », « 1 cours publié » devient « 1 fiche de cours publiée », « Voir le cours » devient « Voir la fiche de cours », « Voir mes cours » devient « Voir mes fiches de cours ».
   - Les trois valeurs de la rubrique « Cours » de l'application (§3, valeurs imposées : `shared.navigation.courses`, `catalog.courses.index.*`, `catalog.courses.show.back`) ne changent pas : le catalogue public est une page publique, pas la rubrique.
2. **Remédiation** (phrases et titres de la lacune, de sa levée et des textes d'images de la fiche de révision) : renommage strict.
   - Seuls les deux titres « Fiche à revoir » et « Fiches à revoir » (exception 3 du §2) gardent « Fiche » seul.
   - « Fiche levée ! » devient « Fiche de révision levée ! », « Revoir la fiche » devient « Revoir la fiche de révision », « Cette fiche passe à revoir » devient « Cette fiche de révision passe à revoir », « ces fiches » devient « ces fiches de révision ».
   - Même règle pour les textes d'images : « images au plus par fiche » devient « images au plus par fiche de révision ».

Restent libres : « en cours » (« Régénération en cours », « Envoi de l'image en cours… »), « cours » au sens scolaire courant, et « fiche » qui ne nomme pas `Essential` (« la fiche de l'établissement »).
