# Plan d'exécution — Comptes de test sur Staging

> Un seul lot : le changement tient dans le semis et sa doc.

## Graphe

```
Lot A — Staging reçoit les comptes du jeu standard (séquentiel)
```

---

## Lot A — Staging reçoit les comptes du jeu standard

- **Couche**       : infrastructure (semis) + doc
- **Fichiers**     : `db/seeds.rb`
                     `db/seeds/standard.rb`
                     `test/db/seeds/staging_stage_test.rb` *(nouveau, sur le modèle de `develop_stage_test.rb`)*
                     `docs/guide/configuration.md` *(section Develop/Staging du jeu, tableau des variables)*
                     `docs/recette/README.md`
                     `docs/decisions/adr/0124-standard-de-test.md` *(amendement §9, déjà écrit)*
                     `docs/chantiers/comptes-de-test-staging/` *(memo, plan, journal)*
- **Dépend de**    : —
- **Test associé** : `test/db/seeds/staging_stage_test.rb`
- **Done quand**   : `db:seed` en production avec `RAILWAY_ENVIRONMENT_NAME=Staging` crée les 3 établissements, leurs classes et les comptes au PIN 2468, sans activité simulée ni import de leçon du manifeste ; aucun compte équipe sans `STANDARD_TEAM_PIN`, les trois avec ; un second semis ne crée rien ; un contact pris n'est ni modifié ni rattaché ; un échec du jeu est imprimé et journalisé sans lever ; la production (`RAILWAY_ENVIRONMENT_NAME=production`) ne sème toujours aucun jeu.

---

## Vérification de collision

Un seul lot : sans objet.

## Portes de sortie

- [ ] Lot A `Done`
- [ ] Un rôle distinct de l'auteur a exécuté le résultat (tests du lot relancés)
- [ ] Rubocop, tests des fichiers touchés, `bin/ci-quiet` sur le head final : au vert
- [ ] ADR-0124 amendé
- [ ] `journal.md` complété
