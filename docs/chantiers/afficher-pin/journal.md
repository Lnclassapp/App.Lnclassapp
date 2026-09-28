# Journal — Afficher le code PIN

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Option `reveal: true` de `ui_field`, refusée hors `as: :password` | Libellé, aide et erreur restent ceux du champ ; un nouveau composant aurait dupliqué `ui_field` | Non — UDR-0051, amendement UDR-0005 |
| 2026-09-28 | Icônes heroicons `eye` (PIN masqué) et `eye-slash` (PIN affiché), outline, taille `md` | Précision du porteur | Non — UDR-0051 |
| 2026-09-28 | Au clavier, le focus reste sur le bouton ; au pointeur, il reste dans le champ | « Le focus reste dans le champ » : on n'arrache pas le clavier virtuel au téléphone ; au clavier, on a quitté le champ par Tab et on doit pouvoir rebasculer | Non — UDR-0051 |
| 2026-09-28 | Libellés sous `components.field.reveal` (recherche paresseuse depuis `components/_field`) | Règle d'or n° 3 : `t(".key")` | Non |

## Ce qui a dérapé

- Premier jet de `keepShown` : l'événement `turbo:before-morph-attribute` des icônes remonte jusqu'au bouton. Sans filtre sur `event.target`, les icônes auraient gardé l'état affiché après un 422. Filtré sur le bouton seul.
- Test système : un écouteur `submit` sur `window` ne voit rien, Turbo arrête la propagation au document. Le type envoyé se lit au `turbo:submit-start`.
- Le journal du navigateur (Selenium) est partagé entre les tests du processus et relève les 422 attendus (« Failed to load resource ») : vidé au début de chaque test, les erreurs réseau écartées.

## Ce qu'on a appris sur la codebase

- Le re-rendu 422 d'une page publique (connexion, inscriptions) est un **morphing** Turbo : un attribut posé par Stimulus y est effacé sans que `connect` repasse. Vérifié par mutation : sans la garde `keepShown`, le bouton disparaît après le 422.
- Le 422 dans la modale du profil remplace le contenu du frame : le contrôleur s'y reconnecte normalement.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Remasquer après un délai ou à la perte du focus | Non demandé ; masqué au chargement, avant l'envoi et avant le cache | — |

## Clôture

Livré le 2026-09-28 : 13 champs PIN dans 7 vues et la démo `/design`. Preuves : `test/helpers/components_helper_test.rb`, `test/integration/pin_reveal_fields_test.rb` (dont une garde qui lit les vues : tout `as: :password` porte `reveal: true`), `test/system/identity/pin_reveal_test.rb` (bureau et 390 px), `test/system/design_system_test.rb`.
