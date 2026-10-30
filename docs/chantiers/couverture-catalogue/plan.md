# Plan d'exécution — Couverture à 100 % perdue par la refonte des maths

## Lot A — Couvrir les lignes et branches manquantes

- **Couche**       : tests surtout ; `app/` seulement pour retirer une branche inatteignable (voir le memo)
- **Lire d'abord** : `docs/chantiers/couverture-catalogue/memo.md`, ADR-0116, les tests existants de chaque fichier (`test/domain/...`, `test/infrastructure/...`, `test/controllers/catalog/...`)
- **Done quand**   : `bin/rails test` (suite complète, sans `COVERAGE=0`) : 0 échec et « Line coverage … (100.0%) », « Branch coverage … (100.0%) » ; aucun `:nocov:`, aucun seuil changé.

### Manques mesurés sur `Develop` (9961fd29)

Numéros de ligne du fichier ; une branche se lit `then@L` / `else@L` (le `if` / `unless` / ternaire / `&.` de la ligne L).

```
app/controllers/catalog/courses_controller.rb
  lines: 
  branches: then@45
app/domain/dtos/assessment/question_input.rb
  lines: 
  branches: else@90
app/domain/entities/catalog/content_node.rb
  lines: 93,94,95,96,98,139,147,154,200,202,215
  branches: then@24 then@32 then@40 then@45 then@62 then@77 then@93 else@93 then@95 else@95 then@118 then@128 then@129 then@131 else@137 then@146 then@149 else@152 then@175 else@176 else@199 then@200 else@200 then@207
app/domain/entities/catalog/figure.rb
  lines: 122,131
  branches: then@15 then@33 then@45 then@57 then@62 then@81 then@90 else@104 else@114 else@115 else@116 then@118 else@127 else@129 then@136 then@143 then@160 then@167
app/domain/entities/catalog/notion_sheet.rb
  lines: 
  branches: else@22 else@25 else@27
app/domain/entities/catalog/statement_blocks.rb
  lines: 68
  branches: then@45 then@83 then@84 then@85 then@93 then@94 then@97 then@110 else@112 else@120 else@121 then@125
app/domain/ports/catalog/content_tree_writer_port.rb
  lines: 29,33,35,36
  branches: then@33 then@34 then@35
app/domain/use_cases/catalog/import_course_tree.rb
  lines: 190
  branches: then@39 else@89 then@99 then@119 then@135 else@188
app/domain/use_cases/catalog/run_import.rb
  lines: 
  branches: else@263
app/infrastructure/queries/assessment/session_play_query.rb
  lines: 
  branches: else@26
app/infrastructure/queries/assessment/session_result_query.rb
  lines: 
  branches: else@34
app/infrastructure/repositories/catalog/content_tree_writer.rb
  lines: 
  branches: then@228
app/infrastructure/repositories/catalog/course_repository.rb
  lines: 
  branches: then@63
```

### Contrat d'exécution

1. Pour chaque fichier, lire la ligne ; trouver l'entrée réelle (fichier d'import v3, appel du use case, requête) qui la joue. Écrire le test dans le fichier de test existant du composant.
2. Branche inatteignable : la retirer (et seulement elle), relancer les tests du composant, noter au journal « fichier:ligne — pourquoi inatteignable ».
3. Mesurer avec la suite complète (`bin/rails test`, une seule à la fois sur la machine) ; recommencer jusqu'à 100 % / 100 %. Pour lister les manques : `ruby <script>` sur `coverage/.resultset.json` (fusionner les sous-processus), ou `coverage/index.html`.
4. Rubocop des fichiers touchés. Journal : une ligne par fichier (tests ajoutés, retraits). Un seul commit `test(catalog): restore full coverage of the v3 import`, pied `Chantier: docs/chantiers/couverture-catalogue`.
