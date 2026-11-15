# Plan d'exécution — simplification-ecrans-eleve

> Un lot = un commit. Format des lots : [`conventions.md` §6](../../guide/conventions.md#6-format-dun-lot). Lots séquentiels : tous touchent les locales, le CSS ou le shell, donc aucun parallélisme (règle 3 du workflow).

```
Lot 0 — règles et socle ─► Lot A accueil ─► Lot B matière ─► Lot C leçon
```

### Lot 0 — Règles et socle

- **Couche**       : doc + ui (fichiers partagés)
- **Fichiers**     : `docs/decisions/udr/0173-ecrans-minimalistes-style-wave.md` · `app/views/layouts/shell.html.erb` · `app/assets/stylesheets/application.tailwind.css` · `app/views/shared/screens/*` · `app/javascript/controllers/dismissible_controller.js` · `config/locales/fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/views/layouts/shell_inner_test.rb`, `test/design/design_tokens_test.rb`
- **Done quand**   : l'UDR est écrite ; une page qui pose `content_for :inner` n'a ni barre ni menu ; les composants `shared/screens` existent

### Lot A — Accueil `/students`

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/classroom/student_homes/*` · `app/controllers/classroom/student_homes_controller.rb` · `app/views/shared/navigation/_home_band.html.erb` · `app/views/communication/messages/_carousel.html.erb`, `_card.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/student_homes_controller_test.rb`, `test/system/…`
- **Done quand**   : la carte de classe, la grille, le carrousel, « À faire » et « Historique » (non vides) et la bannière d'invitation sont rendus ; plus d'« Exercice du jour »

### Lot B — Matière `/courses?material=`

- **Couche**       : ui + helper
- **Fichiers**     : `app/views/catalog/courses/index.html.erb` · `app/views/catalog/courses/_lesson_tile.html.erb` · `app/helpers/catalog/lesson_tile_helper.rb`
- **Dépend de**    : Lot A
- **Test associé** : `test/helpers/catalog/lesson_tile_helper_test.rb`, tests du contrôleur
- **Done quand**   : grille de 4 colonnes, icône calculée, recherche grise, sans barre ni carte

### Lot C — Leçon `/courses/<slug>`

- **Couche**       : ui
- **Fichiers**     : `app/views/catalog/courses/show.html.erb` · `_prepare_sheets.html.erb` · `_revision_sheet.html.erb`
- **Dépend de**    : Lot B
- **Test associé** : tests du contrôleur et système de la leçon
- **Done quand**   : « Réviser », « Prépare interros », « Prépare devoirs » en groupes de 3 puis « Voir plus (n) »
