# Memo — Tests système alignés sur le numéro en chiffres de la connexion

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `fix/tests-numero-connexion` |
| **Programme** | — |

---

## Le problème

Le 2026-10-11 (commit `94fc2d0d`, UDR-0060 §3.2), la connexion est passée au numéro en chiffres seuls (`identity--phone-digits`) et a gagné l'aide « code secret à 4 chiffres » sous le champ. Cinq tests système attendaient encore l'ancien affichage et échouaient sur `Develop` :

- `identity/sign_in_test.rb` (à 390 px, `assert_no_text "4 chiffres"`) ;
- `identity/team_invitation_test.rb:62`, `teams/staff_invitation_test.rb:50`, `finitions/public_pages_test.rb:89` et `:100` (numéro prérempli attendu « 01 00 00 00 09 », affiché « 0100000009 »).

Ils rendaient `bin/ci` rouge sur toutes les PR, ce qui empêche la preuve exigée avant fusion (ADR-0069).

## Pour qui

L'équipe : la CI locale doit pouvoir être verte.

## Pourquoi maintenant

Huit PR des pages élève attendent une preuve `bin/ci` ; ces échecs hérités la masquent.

## Hors périmètre

- Aucun changement de l'application : le comportement d'UDR-0060 §3.2 est le bon, seuls les tests suivent.
- `test/system/boucle_pedagogique_test.rb:37` (fenêtre `turbo-frame#modal` introuvable à la ligne 192), aussi rouge sur `Develop` : cause différente, chantier à part.
