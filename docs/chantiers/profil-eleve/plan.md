# Plan d'exécution — Profil de l'élève aux couleurs Wave et Djamo

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [UDR-0089](../../decisions/udr/0089-profil-eleve-carte-bleue-lignes-a-toucher-et-se-deconnecter.md). Pas d'ADR.
> **Prérequis** : la PR `accueil-eleve` est fusionnée. Petit chantier : une PR, 3 commits ; peut partager une session avec `historique-eleve` et `choix-classe-eleve`, en PR distinctes.

## Graphe

```
Lot 0 — SOCLE ──► Lot A — PAGE ET FENÊTRES ──► Lot B — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure (query) + config
- **Fichiers**     : `app/infrastructure/queries/identity/profile_query.rb` *(`school_name` pour l'élève)* · `config/locales/identity/profiles.fr.yml` · `test/infrastructure/queries/identity/profile_query_test.rb`
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/infrastructure/queries/identity/profile_query_test.rb` (établissement de l'élève, nil sans classe)
- **Done quand**   : `school_name` est juste pour l'élève, inchangé pour les autres rôles

---

## Lot A — Page et fenêtres (CA-1 à CA-8)

- **Couche**       : UI
- **Fichiers**     : `app/views/identity/profiles/{show,_information}.html.erb`
                     `app/views/identity/profile_{names,photos,pins,contacts}/edit.html.erb`
                     `test/system/identity/profile_test.rb` · `test/controllers/identity/profiles_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/identity/profile_test.rb` (CA-1 à CA-6 à 390 et 1 280 px) · `profile_{photo,pin,contact}_test.rb` relancés (CA-7) · `profiles_controller_test.rb` (CA-8)
- **Done quand**   : le profil élève suit les maquettes, fenêtres comprises, en clair et en sombre

---

## Lot B — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `docs/chantiers/README.md` · index UDR *(par `script/docs/build_index`)* · statut d'UDR-0089
- **Dépend de**    : Lot A
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR
- **Done quand**   : captures envoyées (390 px et ordinateur : profil avec et sans photo, chaque fenêtre, sombre), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/infrastructure/queries/identity/profile_query.rb` · `config/locales/identity/profiles.fr.yml` | Lot 0 |
| `app/views/identity/profile*/**` · leurs tests | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(aucun)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0089 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
