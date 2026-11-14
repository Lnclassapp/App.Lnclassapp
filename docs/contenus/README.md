# Contenus pédagogiques — copie figée

Les leçons de Lnclass vivent dans le dépôt public [`Lnclassapp/App.Lnclassapp-contenus`](https://github.com/Lnclassapp/App.Lnclassapp-contenus) (ADR-0134, chantier `contenus-depot-dedie`) : leçons, leçons à reprendre, progressions DPFC, prompts de rédaction et leur mode d'emploi. Ce dossier n'en garde que la **copie figée** des leçons relues, lue par Develop et Staging au pré-déploiement, le jeu standard, la démo, la CI et `bin/apercu-lecon`.

| Fichier | Rôle |
|---|---|
| `lecons-traitees/<niveau>-<série>/<matière>/*.json` | Copie de `lecons/` du dépôt de contenus, à la version nommée par `VERSION` |
| `VERSION` | Dépôt, SHA, date, nombre de fichiers et empreinte de la copie ; écrit par l'outil, jamais à la main |

## Règles

- **On ne corrige jamais une leçon ici.** On la corrige dans le dépôt de contenus (skill `/lecon`, PR vers `main`), puis on synchronise. La CI refuse une copie qui ne correspond plus à `VERSION` (`ruby script/contenus/synchroniser.rb --verifier`).
- **Synchroniser** : dans une PR applicative vers `Develop`, depuis un clone propre du dépôt de contenus au SHA voulu :

  ```bash
  ruby script/contenus/synchroniser.rb ../App.Lnclassapp-contenus           # valide chaque leçon, copie, écrit VERSION
  ruby script/contenus/synchroniser.rb ../App.Lnclassapp-contenus --forcer  # seulement pour revenir à une version plus ancienne
  ```

  Une seule leçon refusée par `script/contenus/valider.rb` et rien n'est copié.
- **Contrôler une leçon** : `ruby script/contenus/valider.rb <fichier>`, depuis l'application (il lit les règles du domaine), quel que soit le dépôt du fichier.
- **Production** : jamais par cette copie ; `/publier-prod` prépare, un membre de l'équipe importe dans Imports, en création seule.

Les deux progressions lues par des tests (Physique-Chimie, SVT) sont des fixtures : `test/fixtures/files/contenus/`.
