# Memo — Base de leçons : seules les leçons au format complet actuel

| | |
|---|---|
| **Type de cycle** | refactoring |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-06 |
| **Branche** | `chore/base-de-lecons` |
| **Programme** | — |

---

## Le problème

`docs/contenus/lecons-traitees/` mélange 498 fichiers de qualité inégale. Develop et Staging y chargent leurs leçons, et le jeu standard y prend les siennes. Le porteur va vider les bases et les recharger avec des données de qualité. Il veut donc que ce dossier ne contienne que les leçons au format complet actuel (`prompt-redaction.md`, depuis #494) :
- chaque notion a ses 4 blocs et deux exercices (`exercise` et `practice`) ;
- 4 problèmes ;
- 4 sujets de devoir de 4 exercices chacun ;
- `valider.rb` sans erreur.

Inventaire du 2026-11-06 : 169 branches et 459 PR, fermées comprises. Aucune leçon valide n'existe hors de `Develop`. Les versions trouvées sur des branches sont toutes des versions plus anciennes de fichiers de `Develop`.

| Catégorie | Fichiers | Où ils vont |
|---|---:|---|
| Format complet actuel (3ème) | 60 | restent dans `lecons-traitees/` : c'est la base |
| v3 valide, sans les 4 sujets de devoir | 277 | `docs/contenus/a-reprendre/sujets-manquants/` |
| v3 valide, un seul exercice par notion, sans sujets | 80 | `docs/contenus/a-reprendre/exercices-et-sujets-manquants/` |
| Format 1, refusé à l'import (`format_retired`) | 81 | `docs/contenus/a-reprendre/format-v1/` |

Le classement de chaque fichier est dans `classement.tsv` (catégorie, puis chemin relatif à `lecons-traitees/`).

## Pour qui

L'équipe de contenu et le porteur : une base de leçons propre pour recharger Develop, Staging et Demo.

## Décision du porteur (2026-11-06)

« place les 60 deja bonne, puis place les autres dans un dossier que nous traiterons apres », avec l'option « Archiver » : les fichiers restent consultables dans le dépôt, mais ne sont plus chargés.

## Hors périmètre

Mise à niveau des 438 leçons à reprendre (vagues suivantes) ; vidage des bases (décision séparée du porteur).
