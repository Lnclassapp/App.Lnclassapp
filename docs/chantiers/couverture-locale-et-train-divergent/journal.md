# Journal — couverture-locale-et-train-divergent

## 2026-11-15

- Poste remis d'équerre : Ruby 3.4.9 (le conteneur avait 3.3.6, qui ne connaît pas `it`), PostgreSQL, assets, `LANG=C.UTF-8`. Sans la locale, 12 tests (`build_index`) et 3 gardes tombaient pour une raison sans lien (`invalid byte sequence in US-ASCII`).
- Reproduit à l'identique la mesure du porteur : 9381 runs, 99,46 % / 99,26 %, `corrections_production.rb` à 0.
- Même arbre, 983 fichiers nommés (comme une part du train, en un seul run) : 100 % / 100 %. Les 9 369 identifiants de test sont les mêmes des deux côtés.
- Piste écartée : la différence de liste de fichiers (identique, 983 / 983). Piste écartée : un défaut de collation des processus fils (le fichier est absent aussi du processus parent, et présent partout avec des fichiers nommés).
- Cause trouvée : `test:prepare` (découverte sans fichier) charge les `.rake` ; l'un requérait le script en tête, avant SimpleCov. Confirmé par `load_tasks` et par un run restreint à `test/tasks`.
- Correctif : `require` déplacé dans la tâche + règle de garde. Mesure locale rejouée : 100 % / 100 %, 310 s.

## 2026-11-15 — suite : la règle, pas seulement le cas (#641)

- Retiré les deux `require` devenus inutiles (`lib/tasks/contenus_corriger.rake`, `test/tasks/corrections_production_test.rb`) : `autoload_lib(ignore: %w[assets tasks])` charge `lib/contenus/corrections_production.rb`. Les quatre gardes d'acteur de la tâche n'ont pas été touchées.
- Garde élargie : plus de famille de fichiers ni de forme d'écriture, mais tout le dépôt et tout chemin qui résout sous `app/` ou `lib/` (hors `assets`, `tasks`). Un test d'auto-contrôle vérifie qu'elle voit les formes `require "x"`, `require Rails.root.join`, `require_relative`, `load`, et laisse passer stdlib, gems, `test_helper`, `db/migrate`, `script/`.
- Règle écrite dans `docs/guide/conventions.md` §7, avec sa raison. Le contrôle à l'exécution proposé plus bas reste écarté.

## À trancher

- **Faut-il aussi un contrôle générique « aucun fichier de `app/` ou `lib/` n'est chargé avant le démarrage de SimpleCov » dans `test_helper` ?** Option prudente appliquée : non. Le défaut est déjà bruyant (la mesure tombe sous 100 % et le fichier sort en tête des moins couverts) et la règle de garde ferme le cas connu ; un contrôle à l'exécution risque de bloquer des chemins légitimes (`COVERAGE_PART`, niveau `pr`) sans qu'on les ait tous mesurés.
