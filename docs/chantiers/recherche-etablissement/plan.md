# Plan d'exécution — Chercher son établissement en tapant son nom

> Un seul lot : le champ remplace les deux listes dans cinq formulaires à la fois ; le couper en lots ferait coexister deux
> sélecteurs d'établissement sur `Develop` (porte « une branche vit moins d'un jour », conventions §3).

## Graphe

```
Lot A — champ « Ton établissement » de bout en bout (séquentiel, une session)
```

---

## Lot A — Recherche d'établissement et champ commun

- **Couche**       : infrastructure (query CQRS) + delivery (contrôleur public, concern hôte) + ui (frame, partial, Stimulus)
- **Fichiers**     : `app/infrastructure/queries/school/school_search_query.rb`
                     `app/controllers/school/school_searches_controller.rb` · `app/controllers/concerns/school_search_field.rb`
                     `app/controllers/concerns/class_picker.rb` et les contrôleurs hôtes (inscription enseignant, compte en attente,
                     rattachement en attente, « Mes établissements »)
                     `app/views/school/school_searches/` · les vues hôtes · `app/javascript/controllers/school/school_search_controller.js`
                     `app/javascript/controllers/classroom/class_picker_controller.js`
                     `config/routes/school.rb` · `config/locales/school/school_searches.fr.yml` *(fichiers partagés)*
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/school/school_search_query_test.rb` (CA-1 à CA-4),
                     `test/controllers/school/school_searches_controller_test.rb` (CA-5, CA-6),
                     tests contrôleur des hôtes (CA-8 à CA-10), `test/javascript/school_search_controller.test.js`,
                     tests système de la cascade élève et de l'inscription enseignant (CA-7, CA-8)
- **Done quand**   : un élève et un enseignant trouvent « Collège Notre-Dame de la Paix » en tapant « ND paix tiassale »,
                     voient sa DRENA à côté, et s'inscrivent ; sans JavaScript, le bouton « Chercher » rend la même liste

---

## Décisions ouvertes

- Aucune avant lancement : la décision D3 du porteur (2026-11-20) tranche le principe ; les points réversibles sont dans `journal.md` § À trancher.

## Vérification de collision

| Fichier partagé | Lot | Autre chantier |
|---|---|---|
| `app/views/classroom/student_registrations/_form.html.erb` | A (une ligne : `after_school:`) | `entree-eleve-unifiee` (entrée de l'inscription élève) : rebase sur `Develop` après sa fusion |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet : aucun port, un seul lot
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur — sous-agents de revue sur le diff final ; challenger empirique à la recette
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert (`bin/ci-quiet`, ligne de preuve dans la PR)
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
