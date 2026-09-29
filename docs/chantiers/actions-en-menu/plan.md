# Plan d'exécution — Actions d'un objet dans un menu ⋮

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — menu ⋮ (séquentiel, un seul lot : le composant et ses écrans partagent les locales et le helper)
```

---

## Lot A — Les actions d'un objet passent dans son menu ⋮

- **Couche**       : ui
- **Fichiers**     : `app/helpers/components_helper.rb`
                     `app/views/components/_dropdown.html.erb`
                     `app/javascript/controllers/dropdown_controller.js`
                     `app/views/teams/{drenas/_drena_row,schools/_school_row,schools/_header,series/_series_row,levels/_level_row,materials/_material_row}.html.erb`
                     `app/views/catalog/essentials/show.html.erb` · `app/views/assessment/exercises/show.html.erb`
                     `app/views/catalog/courses/_role_actions.html.erb` · `app/views/design/index.html.erb`
                     `config/locales/teams/*.fr.yml` · `config/locales/catalog/essentials.fr.yml` · `config/locales/assessment/exercises.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/helpers/components_helper_test.rb` · `test/system/teams/row_actions_menu_test.rb` · tests système et contrôleur des écrans convertis (voir [PRD §4](prd.md#4-critères-dacceptation))
- **Done quand**   : sur chaque écran du périmètre, modifier, désactiver ou supprimer passe par le menu ⋮ de l'objet, au bureau comme au téléphone, sans rechargement

---

## Vérification de collision

Un seul lot : pas de collision possible.

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/**` | Lot A |
| `app/helpers/components_helper.rb` | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR : aucun (ni port, ni table, ni contrat)
- [x] UDR-0042 écrite et indexée ; amendements des UDR des écrans touchés
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL à jour sur chaque vue modifiée
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire par le challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop` *(ouverte par le coordinateur)*
- [x] `journal.md` complété
