# Plan d'exécution — Interrupteur clair / sombre

> PRD : [prd.md](prd.md) · UDR : [UDR-0065, amendement du 2026-10-03](../../decisions/udr/0065-mode-sombre-par-les-tokens.md)

## Graphe

```
Lot A — l'interrupteur (seul lot)
```

## Lot A — L'interrupteur

- **Objectif** : basculer clair / sombre depuis l'en-tête (lg+) et le profil (sous lg), choix retenu sur l'appareil et rendu par le serveur.
- **Fichiers** : `app/helpers/theme_helper.rb`, `app/views/layouts/application.html.erb`, `app/views/shared/_theme_switch.html.erb`, `app/views/shared/navigation/_header.html.erb`, `app/views/identity/profiles/show.html.erb`, `app/javascript/controllers/theme_controller.js`, `app/assets/stylesheets/application.tailwind.css`, `config/locales/shared/theme_switch.fr.yml`, `config/locales/communication/pages/privacy.fr.yml` ; tests `test/helpers/theme_helper_test.rb`, `test/controllers/theme_preference_test.rb`, `test/design/dark_mode_test.rb`, `test/system/identity/profile_test.rb`.
- **Dépend de** : `mode-sombre` (livré).
- **Fini quand** : IT-01 à IT-05 passent ; suites unitaire et système concernées vertes ; captures prises.

## Vérification de collision

| Fichier | Autre chantier qui le touche |
|---|---|
| `application.tailwind.css`, `layouts/application` | aucun en cours |
| `privacy.fr.yml` | aucun en cours (relecture des juristes à venir) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(sans objet)*
- [x] UDR écrite pour **chaque** vue créée ou modifiée *(amendement de l'UDR-0065)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle *(sans objet)*
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(voir le journal : tests rejoués sans le code, 8 échecs sur 13)*
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(revue du porteur sur téléphone)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert *(en local)*
- [x] PR unique vers `Develop`, référençant chantier + UDR
- [x] `journal.md` clos
