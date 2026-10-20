# Plan d'exécution — Historique de l'élève aux couleurs Wave et Djamo

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [UDR-0090](../../decisions/udr/0090-historique-eleve-carte-bleue-exercices-par-mois.md). Pas d'ADR.
> **Prérequis** : la PR `accueil-eleve` est fusionnée (menu avec « Mon historique »). Petit chantier : une PR, 3 commits ; peut partager une session avec `profil-eleve` et `choix-classe-eleve`, en PR distinctes.

## Graphe

```
Lot 0 — SOCLE ──► Lot A — PAGE ──► Lot B — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure (query) + config
- **Fichiers**     : `app/infrastructure/queries/classroom/student_archive_query.rb` *(`Archive#completed_count`)* · `config/locales/classroom/student_archives.fr.yml` · `test/infrastructure/queries/classroom/student_archive_query_test.rb`
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/infrastructure/queries/classroom/student_archive_query_test.rb` (total au-delà de 200, zéro)
- **Done quand**   : `completed_count` est juste ; les requêtes de la page sont mesurées et notées dans `prd.md` §7

---

## Lot A — Page (CA-1 à CA-6)

- **Couche**       : UI
- **Fichiers**     : `app/views/classroom/student_archives/show.html.erb` · `_month.html.erb` *(nouveau)* · `_result_row.html.erb` *(nouveau)*
                     `test/system/classroom/student_archive_test.rb` · `test/controllers/classroom/student_archives_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/classroom/student_archive_test.rb` (CA-2, CA-3, CA-6 à 390 et 1 280 px) · `student_archives_controller_test.rb` (CA-4, CA-5) · CA-1 est prouvé par `accueil-eleve`
- **Done quand**   : l'historique suit les maquettes, avec et sans exercices, en clair et en sombre

---

## Lot B — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `prd.md` *(§7 « Après »)* · `docs/chantiers/README.md` · index UDR *(par `script/docs/build_index`)* · statut d'UDR-0090
- **Dépend de**    : Lot A
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR
- **Done quand**   : captures envoyées (390 px et ordinateur : avec exercices, vide, sombre), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/infrastructure/queries/classroom/student_archive_query.rb` · `config/locales/classroom/student_archives.fr.yml` | Lot 0 |
| `app/views/classroom/student_archives/**` · leurs tests | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(aucun)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0090 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert *(pureté, rubocop, brakeman verts ; tests rouges hors chantier, voir journal)*
- [ ] PR unique vers `Develop`, référençant chantier + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
