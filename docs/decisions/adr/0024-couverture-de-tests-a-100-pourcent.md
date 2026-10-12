# ADR-0024 : Couverture de tests à 100 %, bloquante sur le projet cible
<!-- index
titre: Couverture de tests à 100 %, bloquante sur le projet cible
statut: Accepté
problematique: Exiger 100 % de couverture lignes **et** branches sur `app/` et `lib/`, avec `# :nocov:` interdit et test de mutation obligatoire. Bloquant dès le premier commit du projet Rails cible ; sur ce dépôt, cliquet non régressif à 45 %/29 % jusqu'à la migration.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-18 |
| **Chantier** | `docs/chantiers/` — décision transverse, hors chantier |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Jusqu'à cet ADR, la couverture de tests était **mesurée et jamais bloquante**. C'était un choix explicite, inscrit dans `docs/guide/conventions.md` §7 et commenté dans `test/test_helper.rb` : « on mesure pour voir le trou, pas pour faire échouer une PR ».

Ce choix reposait sur une hypothèse qui s'est révélée fausse : que la suite de tests tournait. Le 2026-09-18, on a découvert qu'une seule `NameError` dans `test/domain/use_cases/exercise_use_cases_test.rb:55` interrompait le chargement des **60 fichiers de tests**. `bin/rails test` répondait « no tests ran » depuis une durée indéterminée. Personne ne l'avait vu, précisément parce que rien ne bloquait.

Après réparation, la ligne de base réelle est la suivante :

| Groupe | Lignes couvertes | Branches couvertes |
|---|---:|---:|
| Domaine | 62,9 % | 46,4 % |
| Infrastructure | 61,9 % | 33,4 % |
| Delivery (contrôleurs, helpers) | 16,5 % | 8,0 % |
| Jobs | 0 % | 0 % |
| Mailers | 0 % | 0 % |
| **Global** | **45,8 %** | **29,5 %** |

Le chiffre le plus éloquent n'est dans aucune de ces cases : **114 fichiers Ruby sur 275** sous `app/` et `lib/` ne sont chargés par aucun test. Ils n'apparaissent dans le rapport que parce que SimpleCov les déclare en `track_files` ; sans cela, la couverture affichée serait de 90 % et serait un mensonge.

Deux éléments de contexte pèsent lourd sur cette décision :

1. **Environ 97 % du code de Lnclass est écrit par des agents IA.** Ce qui n'est pas vérifié mécaniquement n'est pas vérifié du tout — la relecture humaine ne passe pas à l'échelle de la vitesse de production.
2. **Une migration vers un nouveau projet Rails est planifiée.** L'application actuelle sera reconstruite. C'est une fenêtre qui ne se représentera pas : le coût de la couverture est presque entièrement dans le *rattrapage*, pas dans l'écriture initiale.

## 2. Moteurs de décision

Par ordre d'importance :

- **Aucune ligne de code non exécutée par un test ne doit atteindre la production.** C'est la leçon directe de la panne : du code cassé depuis des mois (`Orm::ClassroomExercise`, deux boucles de redirection infinies) a survécu parce que rien ne l'exécutait.
- **Le garde-fou doit être mécanique.** Avec 97 % de code produit par des agents, une consigne en prose est un vœu.
- **Le coût doit être payé au bon moment.** Rattraper 45,8 % → 100 % sur le dépôt actuel coûterait des semaines. Naître à 100 % sur le projet cible coûte marginalement.
- **La métrique ne doit pas devenir la cible.** Voir §5 — c'est le coût consenti principal.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| **A — Statu quo : mesurer sans bloquer** | Zéro friction ; laisse l'équipe juger au cas par cas | Six mois de preuve empirique que ça ne marche pas : la suite était morte et personne ne l'a vu. Une jauge que personne ne regarde n'est pas une jauge |
| **B — Seuils par couche, progressifs** (domaine 90 %, infra 75 %, delivery par tests système) | Adapté à la réalité de chaque couche ; paliers atteignables sans arrêter la production | Introduit un débat permanent sur *quel* chiffre pour *quelle* couche, à chaque PR. Sur un projet neuf, la complexité n'achète rien : 100 % partout est plus simple à tenir qu'un barème |
| **C — 100 %, lignes et branches, bloquant** ✅ | Une seule règle, aucune zone grise, aucun arbitrage à faire en revue. Sur un projet greenfield, le coût marginal par ligne est proche de zéro | Retenue |
| **D — 100 % immédiat sur le dépôt actuel** | Cohérence maximale | Bloque 100 % des commits dès demain, y compris ceux qui réparent les 8 chantiers ouverts. Le premier effet serait `--no-verify`, c'est-à-dire la mort du garde-fou |

L'option B était ma recommandation initiale. Elle a été écartée au profit de C sur un argument que je considère comme juste : **le barème est un coût permanent de négociation, le 100 % est un coût unique d'écriture.** Sur un projet qui naît avec la règle, le second est moins cher.

## 4. Décision

> **Nous exigeons 100 % de couverture — lignes et branches — sur tout code Ruby applicatif, et nous rendons ce seuil bloquant sur le projet Rails cible dès son premier commit.**

Trois précisions qui font partie intégrante de la décision :

1. **Le périmètre est `app/` et `lib/`**, tout fichier `.rb` sans exception. Les vues ERB, le JavaScript et les migrations sont hors périmètre de SimpleCov — ils sont couverts par les tests système et le linting, pas par ce seuil.
2. **`# :nocov:` est interdit.** Une exclusion transforme un 100 % en chiffre décoratif. Toute exception exige un ADR nommant le fichier et la raison. Un cop rubocop la refuse.
3. **Le seuil s'accompagne du test de mutation.** 100 % de couverture prouve qu'une ligne a été *exécutée*, jamais qu'elle a été *vérifiée* (voir §5). `mutant-minitest` est obligatoire sur `app/domain/` du projet cible.

### Application au dépôt actuel

Sur `App.Lnclassapp`, la règle est **écrite mais non bloquante**, pour une raison opérationnelle : à 45,8 %, l'activer refuserait le premier commit qui répare `queries-constantes-orm-disparues` — un correctif 🔴🔴 qui rétablit la connexion des élèves et des enseignants. Un garde-fou dont le premier acte est de bloquer une réparation critique enseigne à l'équipe qu'il faut le contourner.

À la place, sur ce dépôt :

| Mécanisme | Valeur | Effet |
|---|---|---|
| Cliquet global | 45 % lignes / 29 % branches | Interdit de reculer ; ne demande rien |
| `minimum_coverage_by_file` | désactivé | Un fichier legacy à 0 % ne bloque pas une PR qui n'y touche pas |
| Objectif affiché | 100 % | Atteint par la migration, pas par le rattrapage |

Le cliquet monte à chaque chantier livré, jamais l'inverse.

## 5. Conséquences

### 🟢 Positives

- **La panne silencieuse redevient impossible.** Un fichier que plus aucun test ne charge fait tomber la CI le jour même, pas six mois plus tard.
- **Aucun arbitrage en revue.** 100 % ne se négocie pas : un reviewer n'a plus à décider si « ce contrôleur mérite un test ». Sur une équipe qui passe de 3 à 13 devs, supprimer une source de débat vaut plus que le chiffre lui-même.
- **Le code mort devient visible.** Un fichier impossible à couvrir est presque toujours un fichier que personne n'appelle. La règle transforme la couverture en détecteur de code mort — exactement le type de problème qui a produit `Orm::ClassroomEssential`.
- **Cadrage des agents.** Un agent à qui l'on dit « 100 %, branches comprises » produit un plan de test avant de produire le code, ce que la phase 4 du workflow exige déjà sans pouvoir le vérifier.

### 🔴 Coûts consentis

- **La couverture mesure l'exécution, pas la vérification — et ce seuil ne corrige pas ce défaut.** Il est consigné ici parce qu'il est le risque principal de cette décision, démontré dans ce dépôt le jour même où elle est prise :
  - `test/domain/policies/classroom_access_policy_test.rb` était **vert**, comptait dans la couverture, et son dépôt de test **ignorait le `teacher_id`** : un test d'autorisation qui ne testait aucune autorisation.
  - `create_course_test.rb` était **vert** grâce à un double définissant `save`, une méthode que l'adaptateur réel n'expose pas. Le code testé lève `NotImplementedError` en production.

  Le chemin le moins coûteux vers 100 % est d'appeler chaque méthode sans rien asserter. **C'est pourquoi `mutant-minitest` n'est pas une recommandation mais une condition de validité de cet ADR.** Sans lui, le seuil produit de la conformité et masque le problème qu'il prétend résoudre : la jauge sature et cesse d'informer.
- **Coût réel sur le boilerplate.** `ApplicationJob`, `ApplicationMailer`, les `raise NotImplementedError` des ports, les `rescue` d'erreurs d'I/O. Chacun demande un test dont la valeur est faible. C'est le prix de l'absence de zone grise, et il est accepté en connaissance de cause.
- **Le dépôt actuel vit avec deux régimes** jusqu'à la migration : règle à 100 % écrite, cliquet à 45 % appliqué. C'est une incohérence assumée et datée, pas un oubli.
- **Le temps de CI augmente.** Le test de mutation sur le domaine se compte en minutes. Il tourne en job séparé, non bloquant sur `feature/*`, bloquant sur `Develop`.

## 6. Notes d'implémentation

### Sur le projet cible — `test/test_helper.rb`

```ruby
# Couverture : 100 %, lignes ET branches. Bloquant. ADR-0024.
unless ENV["COVERAGE"] == "0"
  require "simplecov"

  SimpleCov.start "rails" do
    enable_coverage :branch

    # Hérité du profil "rails" ci-dessus, réécrit explicitement : c'est la ligne
    # dont tout dépend, elle ne doit pas pouvoir disparaître sans qu'on le voie.
    track_files "{app,lib}/**/*.rb"   # un fichier jamais chargé compte comme 0 %

    skip "/test/"
    skip "/config/"
    skip "/vendor/"

    group "Domaine",        "app/domain"
    group "Infrastructure", "app/infrastructure"
    group "Delivery",       [ "app/controllers", "app/helpers" ]

    minimum_coverage line: 100, branch: 100
  end
end
```

`track_files` est la ligne décisive : sans elle, les fichiers qu'aucun test ne charge sont absents du rapport et la couverture affichée monte artificiellement. Sur le dépôt actuel, l'écart est de 90 % (fichiers chargés seuls) contre 62,9 % pour le domaine tous fichiers confondus — le seul écart de `track_files` vaut 27 points.

Elle est **déjà héritée** du profil `rails` (simplecov 1.3.0, `lib/simplecov/profiles/rails.rb:18`). On la réécrit tout de même en clair : c'est l'hypothèse sur laquelle repose la validité de tous les chiffres de cet ADR, et une valeur héritée disparaît sans bruit si le profil change de version.

### Sur le dépôt actuel — cliquet

```ruby
    # Cliquet, pas objectif (ADR-0024). Ne descend jamais ; monte à chaque chantier livré.
    minimum_coverage line: 45, branch: 29
```

### Interdiction de `# :nocov:` — `.rubocop.yml`

```yaml
# ADR-0024 : une exclusion de couverture transforme 100 % en chiffre décoratif.
Lnclass/NoCovForbidden:
  Include:
    - "app/**/*.rb"
    - "lib/**/*.rb"
```

À défaut d'un cop maison, un `grep` en pre-commit suffit et coûte moins cher :

```bash
git diff --cached --name-only -z --diff-filter=ACM -- 'app/*.rb' 'lib/*.rb' \
  | xargs -0 -r grep -nH ':nocov:' && {
    echo "ADR-0024 : '# :nocov:' interdit. Écris le test, ou ouvre un ADR."
    exit 1
  }
```

### Test de mutation — projet cible

```ruby
# Gemfile, group :test
gem "mutant-minitest", require: false
```

```bash
# Bloquant sur Develop uniquement — se compte en minutes.
bundle exec mutant run --integration minitest -- 'UseCases::*' 'Entities::*' 'Policies::*'
```

## 7. Comment vérifier que la décision est respectée

| Ce qu'on vérifie | Comment | Où ça bloque |
|---|---|---|
| Couverture à 100 %, lignes et branches | `minimum_coverage line: 100, branch: 100` — SimpleCov sort en code 2 | CI, projet cible |
| Les fichiers non chargés comptent | `track_files "{app,lib}/**/*.rb"` présent dans `test_helper.rb` | Revue + CI |
| Aucune exclusion | `grep -rn ':nocov:' app/ lib/` doit ne rien retourner | pre-commit + CI |
| Les tests prouvent quelque chose | `mutant run` — un mutant survivant est un test creux | CI sur `Develop`, projet cible |
| Sur le dépôt actuel, pas de régression | `minimum_coverage line: 45, branch: 29` | CI |

Le point 4 est le seul qui vérifie la **qualité** des tests plutôt que leur existence. Les quatre autres se contentent, tous ensemble, de prouver que le code a été exécuté. C'est la limite de cet ADR, et elle est structurelle : aucun seuil de couverture, à aucune valeur, ne peut distinguer un test qui vérifie d'un test qui traverse.
