# UDR-0013 : Catalogue et page cours — cartes filtrées dans un frame, contenu riche sous KaTeX, actions du rôle en modale

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B1, critères CA-01, CA-04, CA-10, CA-26, CA-27 (point d'entrée), TR-41 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadPublishedPolicy`) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (statuts) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (KaTeX et Trix à la demande) · [UDR-0001](0001-design-visuel-du-catalogue-pedagogique.md) (carte-vitrine) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0014](0014-formulaire-cours.md) (modale du cours, panneau de statut) |
| **Remplacé par** | — |

---

## 1. Contexte

Le catalogue est la porte d'entrée de l'élève, de l'enseignant et de l'équipe. Dans l'ancienne application :

- les filtres par niveau et par matière étaient **silencieusement ignorés** (clés String lues en Symbol) et la pagination était factice ;
- un brouillon était **invisible de l'équipe** sur le catalogue, mais **lisible par n'importe qui** par son URL directe ;
- la couleur d'une matière venait de deux tables d'expressions régulières sur son **nom**, jamais de sa catégorie (CA-26) ;
- la page d'un cours intitulait « Habiletés » la liste des fiches, proposait « Supprimer » à l'équipe, et son bouton d'assignation pour l'enseignant n'était **jamais rendu** (CA-27) ;
- KaTeX venait d'un CDN.

## 2. Décision

1. **Une grille de cartes-vitrines, filtrée dans un frame.** Les filtres niveau et matière sont un formulaire `GET` qui vise le frame `courses` et avance l'URL : le filtre survit au retour arrière et au partage du lien, sans rechargement de page. Le serveur ne renvoie que le frame à ses requêtes. Pas de pagination en V1 : le catalogue publié tient en une page.
2. **Publié seulement, sauf pour l'équipe.** L'élève, l'enseignant et le personnel d'établissement ne voient que les cours publiés. L'équipe voit tous les statuts, chaque carte portant son badge (« Brouillon — visible uniquement par l'équipe », « Publié », « Archivé »). Un cours non publié ouvert par URL directe répond **404** hors de l'équipe, sans rien confirmer.
3. **La matière se reconnaît à sa catégorie** : `ui_subject_badge(name, category:)`, partout.
4. **Page d'un cours** : fil d'Ariane (Cours › matière › cours), en-tête (titre, sous-titre, badges), contenu riche, puis les fiches essentielles. Le contenu est rendu par Action Text, qui l'assainit par sa liste blanche (en plus de `RichTextSanitizer` à l'écriture), et ses formules `$…$` passent par le contrôleur `math` (KaTeX servi par l'application).
5. **Actions selon le rôle, dans l'en-tête.** L'équipe : le panneau de statut (`content_status_panel`, publier ou archiver) et un menu dont chaque entrée s'ouvre dans la modale : « Modifier », « Nouvelle fiche essentielle », « Importer des fiches essentielles ». L'enseignant : « Assigner à mes classes », qui mène à l'écran du Lot D7. Pas de « Supprimer » : un cours s'archive.
6. **Aucun stream propre.** Les pages de B1 sont en lecture ; les écritures (B2, B4, imports) rafraîchissent la page par morphing (`turbo_stream.refresh`) ou remplacent le panneau de statut.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `catalog/courses/index` : `ui_page_header` (« Cours ») ; équipe : `ui_button` « Importer des cours » (`secondary`, `new_teams_import_path(kind: "course_tree")`) et « Nouveau cours » (`new_teams_course_path`), tous deux `data-turbo-frame="modal"`. Puis `form#courses-filters` (`role="search"`, `method: get`, `data-turbo-frame="courses"`, `data-turbo-action="advance"`) : `select` niveau et matière (« Tous les niveaux », « Toutes les matières »), « Filtrer », « Effacer ». Puis `turbo_frame_tag "courses", target: "_top"` → `#courses_total` (`aria-live`) et `ul#courses_list` (1 colonne, 2 dès `sm`, 3 dès `xl`). Une requête du frame `courses` ne reçoit que le frame.
- `_course_card` (`li#course_<slug>`) : `ui_card(href: course_path)` — toute la carte est le lien. Badge de matière et badge « niveau série », titre `h2` en `font-display font-extrabold`, sous-titre sur 2 lignes (`line-clamp-2`), pied « Ouvrir le cours » ; équipe : `content_status_badge` dans le pied. **Jamais la liste des fiches sur la carte.**
- `catalog/courses/show` : `nav` fil d'Ariane (`ol`, dernier élément `aria-current="page"`) ; `#course_header` → `ui_card` → `h1`, sous-titre, badges, puis `_role_actions`. `section#course_content` (si le contenu n'est pas vide) → `ui_card padding: :lg` → conteneur `#course_content_<empreinte>` → `#course_math_<empreinte>[data-turbo-permanent][data-controller=math]` → le rich text. `section#course_essentials` → titre « Fiches essentielles » → `ul` de `_essential_row`, ou l'état vide.
- `_essential_row` (`li#essential_<slug>`) : lien vers `course_essential_path`, sous-titre, badge « N exercices » ; équipe : `content_status_badge` de la fiche.
- `_role_actions` : équipe → `content_status_panel(record:)` (entité du cours) et `ui_dropdown` `#course-actions-menu` dont chaque `a[role=menuitem]` porte `data-turbo-frame="modal"` ; enseignant → `ui_button` « Assigner à mes classes » vers `course_assignments_path(slug)`.
- Lecture : `CourseCatalogQuery(actor:, level:, material:)` ; `CourseDetailQuery(slug:, actor:)`, puis `ReadPublishedPolicy` sur la ligne du cours ; `ManageContentPolicy` décide du panneau de statut, qui lit l'entité par `CourseRepository#find_by_slug`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune valeur arbitraire.
- Couleur d'une matière : `ui_subject_badge` (science → `brand`, littérature → `gold`, autres → `team`).

**Comportement**
- Filtrer : Turbo Frame `courses`, URL avancée, sans rechargement de page. Sans JavaScript, le même formulaire recharge la page filtrée.
- Une carte ouvre la page du cours par Turbo Drive (`target: "_top"` du frame).
- Rafraîchissement par morphing (modification du cours) : un contenu inchangé garde ses formules rendues (élément permanent) ; un contenu modifié change d'empreinte, donc d'id, et son conteneur est remplacé, ce qui reconnecte le contrôleur `math`. Un élément permanent seul ne serait jamais retiré par le morphing.
- Publier ou archiver : le stream du Lot B2 remplace `#content_status_course_<slug>` et affiche un toast.
- Ni Trix ni Action Text JavaScript ne se chargent sur ces pages ; KaTeX se charge à la demande.

**États obligatoires**
- Vide : « Aucun cours pour l'instant » ; aucun résultat filtré : « Aucun cours ne correspond à ces filtres » et « Effacer les filtres » ; cours sans fiche : « Aucune fiche essentielle pour ce cours. ».
- Chargement : Turbo marque `aria-busy` pendant le filtrage.
- Erreur : 404 (cours inconnu, ou non publié hors équipe) par `RendersResult`, sans aucune donnée du cours.
- Succès : sans objet ici ; les toasts viennent des Lots B2, B4 et de l'import.

**Accessibilité**
- Le formulaire de filtres est un `role="search"` nommé ; chaque `select` a son `label`.
- Le fil d'Ariane est un `nav` nommé, ses séparateurs `aria-hidden`.
- Le menu de l'équipe suit le motif « menu button » de `ui_dropdown` ; son nom cite le cours.
- Cibles tactiles ≥ 48 px ; les deux pages tiennent dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Tout écran qui liste des cours réutilise `_course_card` et `ui_subject_badge(category:)`.
- Un brouillon n'est jamais lisible par URL directe hors de l'équipe ; `test/controllers/catalog/courses_controller_test.rb` le garde.
- Les formulaires ouverts depuis ces pages (B2, B4, imports) répondent par `turbo_stream.refresh` et ne rendent aucun partial de B1.
- Toute page qui passe du contenu à KaTeX et qui est rafraîchie par morphing reprend le motif « conteneur à empreinte + élément permanent ».
- Interdit désormais : « Habileté(s) » à l'écran, « Supprimer un cours », une couleur de matière tirée de son nom, un script ou une feuille de style servis par un CDN.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Catalogue** : le formulaire des filtres (`form#courses-filters`) gagne un champ `q` (`ui_field as: :search`, « Rechercher un cours ») sur le nom du cours, sans casse ni accents, et porte le contrôleur `search` : envoi 300 ms après la dernière frappe (URL remplacée), envoi au changement des listes niveau et matière ; « Filtrer » reste sans JavaScript. État vide « Aucun cours ne correspond », avec « Effacer la recherche ». Pas de pagination dans ce chantier.
- **Page cours** : le fil d'Ariane complet (« Cours › Matière › Nom ») est remplacé par le lien de retour « Cours » (UDR-0054 §3.2).
- Titres par `page_title` : « Cours · <espace> · Lnclass », « <nom du cours> · <espace> · Lnclass ».
