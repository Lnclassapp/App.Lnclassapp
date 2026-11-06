# Plan d'exécution — Base de leçons

Un seul lot.

## Lot A — Déplacer les leçons hors format et remettre le jeu standard d'aplomb

- **Couche**       : contenus + seeds + tests
- **Fichiers**     :
  - `git mv` des 438 fichiers de `docs/contenus/lecons-traitees/<dossier>/<matière>/<fichier>.json` vers `docs/contenus/a-reprendre/<catégorie>/<dossier>/<matière>/<fichier>.json`, selon `classement.tsv`, en gardant l'arborescence ;
  - `docs/contenus/a-reprendre/README.md` : les 3 catégories, leurs effectifs, ce qui manque à chacune et la règle de retour (un fichier revient dans `lecons-traitees/` quand il a le format complet et passe `valider.rb`) ;
  - `docs/contenus/README.md` : le tableau des leçons traitées et le texte décrivent la base des 60 leçons ;
  - `db/seeds/standard/jeu.yml` : `lecons` ne garde que les couples `3eme/…` ; `sans_v3` est vidé, car ses couples n'existent plus dans `lecons-traitees/` ; `longue` reste ;
  - `app/domain/entities/catalog/v3_programme_levels.rb` : seulement si un test ou le chargement l'exige. Sinon, ne pas y toucher et noter dans le journal que Staging ne trouvera plus de dossiers de lycée ;
  - les tests qui lisent un fichier déplacé (`test/integration/contenus/tle_histoire_geographie_je_m_entraine_test.rb`, `test/integration/catalog/automatic_lesson_load_test.rb` avec `PROGRAMME_FILE`, `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb`, et tout autre test que la suite fait échouer) :
    - un test sur le **contenu** d'une leçon lit son nouveau chemin sous `a-reprendre/` ;
    - un test sur le **chargement** (dossier de niveau du programme) prend une copie sous `test/fixtures/files/`, pour ne pas dépendre d'un fichier qui sera retravaillé.
- **Dépend de**    : —
- **Test associé** :
  - `test/db/seeds/standard_manifest_test.rb` et `test/db/seeds/standard_seed_test.rb` ;
  - `test/integration/catalog/*` et `test/integration/contenus/*` ;
  - `test/db/pr_environment_seeds_test.rb`.
- **Done quand**   :
  - `lecons-traitees/` contient exactement les 60 fichiers « base » de `classement.tsv`, et chacun passe `ruby script/contenus/valider.rb` ;
  - aucun test ne lit un chemin disparu ;
  - le manifeste standard est valide ;
  - `bin/ci-quiet` est vert sur le head.
