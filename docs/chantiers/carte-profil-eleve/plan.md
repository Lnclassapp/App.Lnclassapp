# Plan d'exécution — Carte de profil de l'élève dans la barre latérale

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — carte de profil de l'élève (seul lot, pas de socle)
```

---

## Lot A — Carte de profil de l'élève

- **Couche**       : infrastructure (lecture du shell) + ui
- **Fichiers**     : `app/views/shared/navigation/_sidebar.html.erb` · `app/helpers/navigation_helper.rb`
                     `app/infrastructure/queries/identity/shell_user_query.rb` · `config/locales/shared/navigation.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/views/shared/navigation/sidebar_test.rb` (CA-1 à CA-4) · `test/system/identity/student_sidebar_profile_card_test.rb` (CA-5, CA-6) · `test/helpers/navigation_helper_test.rb` · `test/infrastructure/queries/identity/shell_user_query_test.rb`
- **Done quand**   : sur ordinateur, la barre latérale de l'élève commence par sa carte, à la hauteur de celle de l'enseignant ; le téléphone est identique

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| tous | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet
- [x] UDR écrite pour **chaque** vue créée ou modifiée — UDR-0132 §3.1 amendée
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet
- [x] Chaque critère d'acceptation a son test, rouge sans le code (6 rouges sur 7, le 7e garde les adultes)
- [x] En-tête HITL sur chaque fichier créé dans `app/` — aucun fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
