# Plan d'exécution — Mode sombre de l'application

> PRD : [prd.md](prd.md) · UDR : [UDR-0065](../../decisions/udr/0065-mode-sombre-par-les-tokens.md)

## Graphe

```
Lot A — les tokens en sombre (seul lot : une feuille, un gabarit, leurs tests)
```

Un seul lot : le changement tient dans la feuille de style et le gabarit, et il n'a pas de cas d'usage séparable.

## Lot A — Les tokens en sombre

- **Objectif** : un navigateur en thème sombre reçoit toute l'application en couleurs sombres lisibles ; l'impression reste claire.
- **Fichiers** : `app/assets/stylesheets/application.tailwind.css`, `app/views/layouts/application.html.erb`, `test/design/dark_mode_test.rb`, `test/design/design_tokens_test.rb` (message), `test/system/design_system_test.rb`, captures `docs/design/captures/mode-sombre/`.
- **Dépend de** : rien.
- **Fini quand** : MS-01 à MS-07 passent ; rubocop, suite unitaire, tests système du design system verts ; captures prises.

## Vérification de collision

| Fichier | Lot | Autre chantier qui le touche |
|---|---|---|
| `application.tailwind.css` | A | aucun en cours |
| `layouts/application.html.erb` | A | aucun en cours |
| `test/system/design_system_test.rb` | A | `refonte-homepage` (#145) ajoute un autre test : fusion sans conflit attendue |
| `docs/decisions/udr/README.md`, `docs/chantiers/README.md` | A | `refonte-homepage` (#145) ajoute sa ligne juste au-dessus : conflit d'index trivial à la seconde fusion |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé` *(mené par l'agent, principe tranché par le porteur)*
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(sans objet)*
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0065 ; amendement UDR-0005)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle *(sans objet : un lot)*
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(voir le journal : test du bloc écrit après la feuille, puis rejoué contre la feuille de `Develop` : 5 échecs sur 5)*
- [x] En-tête HITL sur chaque fichier créé dans `app/` *(aucun fichier créé ; en-têtes mis à jour)*
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire : revue du porteur sur téléphone en thème sombre)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert *(en local ; la CI de la PR fait foi)*
- [x] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
