# Plan d'exécution — Déploiement continu GitHub → VPS Hostinger

## Graphe

```
Lot A — workflow, deployer.py, garde-fou, docs (seul)
```

---

## Lot A — Déploiement continu

- **Couche**       : outillage (`.github/`, `script/`, `test/guards/`, `config/ci.rb`, `docs/guide/`)
- **Fichiers**     : `.github/workflows/deploiement.yml` · `script/hostinger/deployer.py` · `test/guards/deploiement_workflow_test.rb` · `config/ci.rb` · `docs/guide/configuration.md` · `docs/guide/retour-arriere.md`
- **Dépend de**    : —
- **Test associé** : `test/guards/deploiement_workflow_test.rb` (critères du PRD §4)
- **Done quand**   : garde-fou vert, `deployer.py construction … --dry-run` passe en local, `bin/ci-quiet` vert

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée — sans objet, aucune vue
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli — un seul lot
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/` — aucun fichier dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
