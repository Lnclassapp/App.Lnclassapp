# ADR-XXXX : Un jeu de test standard, un rôle par environnement, des leçons rendues par la machine
<!-- index
titre: Standard de test : jeu standard, rôle des environnements, rendu des leçons
statut: Proposé
problematique: Chaque environnement teste sur des données différentes et l'affichage des leçons n'est vérifié qu'à la main.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-02 |
| **Chantier** | `docs/chantiers/standard-de-test` |
| **Remplace** | — (amende ADR-0122 pour Staging et ADR-0123 pour Develop, sous réserve des décisions ouvertes) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

En novembre 2026, Lnclass a trois jeux de données de test qui ne se recoupent pas :

- en local (`bin/tester-pr --demo`) et en environnement de PR (ADR-0108) : 3 établissements, 63 classes, des milliers d'élèves, et **toutes** les leçons v3 importées par la vraie chaîne ;
- sur Develop (ADR-0122, ADR-0123) : à chaque déploiement, toutes les leçons v3 du programme sont remplacées entières (~350 publiées), avec tentatives, devoirs et lectures effacés ;
- sur Staging : seulement les leçons à sujets en automatique, le reste à la main.

L'affichage des leçons, lui, n'est vérifié qu'à l'œil : 30 leçons sur 347 dans le plan de test des contenus v3. Les défauts connus (formule qui fait défiler la page à 390 px, `**` affichés en clair, figure vide) ne sont gardés que par un test système fabriqué à la main (`long_formulas_test.rb`), sur une leçon synthétique, à une seule largeur.

Le porteur a validé le 2026-11-02 quatre principes : un jeu standard identique partout ; les leçons vérifiées par la machine ; un rôle par environnement ; une preuve de vague. Plus une boucle courte de mise à jour d'un contenu en local.

## 2. Moteurs de décision

- Ne supprimer aucune donnée d'un environnement partagé sans l'accord du porteur.
- Budget CI : aucune tâche > 5 min (ADR-0107), tests système budgétés (`script/ci/system_budget.rb`).
- Un jeu décrit dans le dépôt, relisible, stable quand un fichier de contenu arrive.
- Réutiliser la vraie chaîne d'import (mêmes refus que l'écran Imports), pas un second chemin.
- Pas de nouveau port : `ImportCourseTree` et `ContentTreeWriter` couvrent déjà le remplacement d'une leçon.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Choix implicite des leçons (la première de chaque dossier) | Aucun fichier à maintenir | Le jeu change dès qu'un fichier arrive : pas « identique » |
| **B — Manifeste YAML écrit dans le dépôt** | Relisible, stable, contrôlable par un test | Un fichier à tenir à jour quand une matière gagne sa première v3 — **retenue** |
| C — Une base de données figée (dump) | Recréation exacte et rapide | Se périme à chaque migration ; illisible en revue |
| D — Rendre les 417 fichiers à chaque PR | Couverture totale | ~15 à 20 min : viole ADR-0107 |
| **E — Rendre les fichiers touchés en PR, tout au train en parts de ≤ 5 min** | Couverture totale par train, coût local borné | Un défaut transverse (CSS) sur une leçon non touchée n'est vu qu'au train — **retenue** |
| F — Vider Develop et le recréer au jeu standard | Develop vraiment « identique » | Supprime ~350 leçons et leurs données : décision du porteur, pas d'ici |

## 4. Décision

> **Nous décrivons le jeu de test standard dans un manifeste du dépôt et le chargeons, idempotent, partout où l'on teste ; nous rendons chaque fichier de leçon v3 dans la base de test, à 390 px et sur ordinateur, sur les fichiers touchés en PR et sur tous au train ; nous donnons un rôle à chaque environnement sans rien y supprimer.**

1. **Manifeste** `db/seeds/standard/jeu.yml` : 2 établissements (un lycée, un collège), une classe par niveau-série (une classe pleine de 40 élèves, les autres de 3), comptes fictifs par rôle (direction, enseignant dont un dans les deux établissements, élève par classe, équipe) avec le PIN de test, et **un fichier v3 par dossier niveau-série et par matière**. Un test refuse un fichier absent, non v3, ou un couple niveau-matière qui a du v3 et n'est pas dans le manifeste.
2. **Seed** `db/seeds/standard.rb` : joué en développement (`bin/tester-pr --demo`) et en environnement de PR à la place de `demo/trois_etablissements` + `demo/lecons_completes`, qui restent derrière `--tout-contenu`.
3. **Test d'affichage** `test/system/catalog/lesson_rendering_test.rb` : importe chaque fichier par `ImportCourseTree`, publie dans la base de test, visite la page élève à 390 px et sur ordinateur et échoue sur : import refusé, `scrollWidth > innerWidth`, `**` dans le texte rendu, figure déclarée non visible. Liste des fichiers : `LECONS=` (explicite), sinon les fichiers v3 changés depuis `origin/Develop`, sinon (train, `LECONS=tout`) tous, découpés par `LECONS_PART=i/n`. Hors budget de 15 s par dérogation nommée ; au train, une tâche dédiée en parts de ≤ 5 min.
4. **Rôles** : production inchangée. Staging : le chargement automatique ajoute les leçons v3 **absentes** (mode `:create_only`), ne remplace pas les présentes. Develop : le chargement se limite au jeu standard, **sans supprimer** les leçons déjà là (décision ouverte n° 1 du memo ; la remise à zéro de Develop est une décision séparée du porteur).
5. **Aperçu** `bin/apercu-lecon <fichier> [--suivre]` : `valider.rb`, puis import seul avec `replace: :lesson`, publication, affichage de l'adresse ; refusé si `Rails.env` n'est pas `development`.
6. **Preuve de vague** `bin/preuve-vague <dossier>` : `valider.rb` + test d'affichage sur le dossier + captures d'une leçon par matière dans `tmp/preuves/`, jamais commitées.

## 5. Conséquences

### 🟢 Positives

- Une PR, Develop et le poste du porteur parlent des mêmes comptes et des mêmes leçons.
- Chaque fichier v3 est rendu par la machine au moins une fois par train ; ceux d'une PR, dans la PR.
- Boucle de rédaction : une commande, quelques secondes.
- `bin/tester-pr --demo` charge ~46 leçons au lieu de ~417.

### 🔴 Coûts consentis

- Le manifeste se maintient à la main : une matière qui reçoit sa première v3 doit y être ajoutée (le test le rappelle).
- Une tâche CI de plus au train (~15 à 20 min de calcul, en parts) et une dérogation au budget système.
- Un défaut transverse sur une leçon non touchée n'est vu qu'au train.
- Tant que Develop n'est pas remis à zéro, il porte le jeu standard **et** les ~350 leçons anciennes : il n'est pas strictement identique au local.
- L'environnement de PR perd le jeu volumineux par défaut (listes longues : une seule classe pleine).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/automatic_load_stage.rb (extension prévue)
# develop  → mode :lesson, fichiers restreints au manifeste du jeu standard
# staging  → mode :create_only pour les fichiers v3 sans sujets ; :exercises pour ceux à sujets (ADR-0122)
# production, pr, inconnu → rien
```

```yaml
# db/seeds/standard/jeu.yml (forme)
etablissements:
  - { nom: "Standard — Lycée", type: lycee, classes: [2nde-a, 2nde-c, 1ere-a1, 1ere-a2, 1ere-c, 1ere-d, tle-a1, tle-a2, tle-c, tle-d] }
  - { nom: "Standard — Collège", type: college, classes: [6eme, 5eme, 4eme, 3eme] }
lecons:
  tle-d/mathematiques: <fichier>.json
```

## 7. Comment vérifier que la décision est respectée

- `test/db/seeds/standard_manifest_test.rb` : le manifeste nomme un v3 existant par couple niveau-série-matière qui en a.
- `test/db/seeds/standard_seed_test.rb` : deux chargements → mêmes comptes, aucun doublon.
- `test/domain/entities/catalog/automatic_load_stage_test.rb` : Develop restreint au manifeste ; Staging `:create_only` ; production rien.
- `test/system/catalog/lesson_rendering_test.rb` avec des fichiers piégés (débordement, `**`, figure vide, import refusé) : rouge sur chacun.
- `.github/workflows/ci.yml` : chaque part du rendu des leçons a `timeout-minutes: 5`.
