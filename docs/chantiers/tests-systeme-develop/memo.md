# Memo — Tests système en retard sur Develop

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `fix/tests-systeme-develop` |
| **Programme** | — |

---

## Le problème

Trois tests système échouent sur `Develop` (`258ab93b`) ; ils échouent de la même façon en local et sur la CI de la PR #163. Les lots de `reorganisation-equipe-enseignant` ont été mergés dans `Develop` sans exécution de la CI, alors qu'ils changeaient trois comportements décidés :

| Test | Ce qu'il attendait | Ce qui est décidé et codé |
|---|---|---|
| `test/system/design_system_test.rb:365` | une seule liste de navigation par rôle | UDR-0068 §3.1 : une 2ᵉ carte pour l'équipe (Référentiel, Imports), `NavigationHelper::SECONDARY_DESTINATIONS` |
| `test/system/finitions/team_referential_test.rb:17` | retour « Accueil » vers l'accueil de l'équipe | UDR-0068 (« Retour des écrans du référentiel ») : retour « Référentiel » vers `teams_referential_path` |
| `test/system/finitions/classroom_test.rb:56` | un seul « Copier le lien » sur la page de classe | UDR-0069 §3.6 : la carte « Parrainage » de la barre latérale a aussi « Copier le lien » |

## Cause racine

Les tests décrivaient l'ancien comportement. Le code est conforme aux UDR acceptées, et le chantier source les avait déjà amendées.

## Correctif

Les tests sont alignés sur les UDR. Aucun code de l'application ne change.

## Hors périmètre

- Rendre la CI obligatoire sur `Develop` (protection de branche) : c'est une décision du porteur.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le code ou le test est-il faux ? | Le test : chaque comportement est écrit dans une UDR acceptée | Seuls les tests changent |
| Un merge direct sur `Develop` peut-il passer sans CI ? | Oui : la CI ne tourne que sur les PR | Signalé au porteur (hors périmètre) |
