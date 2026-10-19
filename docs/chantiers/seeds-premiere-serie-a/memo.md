# Memo — Référentiel de développement : séries de la 1ère (abandonné, hypothèse « A, C et D » réfutée)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | abandonné (2026-10-19) |
| **Ouvert le** | 2026-10-11 |
| **Branche** | `feature/seeds-premiere-serie-a` |
| **Programme** | — |

---

> **Abandonné le 2026-10-19.** Vérification du porteur sur le terrain : la 1ère a bien les séries **A1 et A2** (avec C et D), pas une série « A » seule. Le référentiel de développement et de test (1ère × A1, A2, C, D ; 77 et 38 classes) et les ADR-0030 et ADR-0034 sont donc justes. Aucun code ne change. C'est le référentiel réel de Develop, créé à l'écran, qui lie à tort la 1ère à « A » : l'équipe le corrige à l'écran (séries A1 et A2 pour la 1ère). Le reste de ce memo décrit l'hypothèse de départ, réfutée.

## Le problème

Le référentiel qui démarre pleins les environnements de développement et de test lie la 1ère aux séries **A1, A2, C et D**. Le référentiel réel de l'environnement Develop, créé à l'écran par l'équipe, ne lie la 1ère qu'aux séries **A, C et D** : A1 et A2 n'existent qu'en Terminale.

Deux écarts en découlent :

1. Les cours de 1ère A, tels que l'équipe les importe aujourd'hui, sont **refusés à l'import en développement** (« Cette série n'est pas proposée pour ce niveau »), alors qu'ils passent sur Develop une fois le lien créé.
2. Le nombre de classes générées pour un lycée n'est pas le même : le référentiel de développement en donne 77 (public) et 38 (privé), parce qu'il compte quatre séries en 1ère ; avec trois séries, le barème donnerait 71 et 35.

La décision d'origine (qui fixe la 1ère à quatre séries et chiffre les totaux de classes) a été prise avant que l'équipe ne crée son référentiel : c'est elle qui est dépassée, pas un comportement défaillant.

## Pour qui

- **Team** : elle crée le référentiel à l'écran et importe les contenus ; elle doit pouvoir répéter ses imports en développement avec le même résultat que sur Develop.
- **Développeurs et testeurs** : leur référentiel de départ doit ressembler à celui de l'équipe.
- Aucun changement visible pour Student, Teacher, Parent ni SchoolStaff.

## Pourquoi maintenant

Les fichiers de contenu de 1ère viennent d'être alignés sur la série A (fusion de A1 et A2) et l'import de ces cours est en cours à l'équipe. Tant que le référentiel de développement dit autre chose, développement et test ne reproduisent pas ce que l'équipe voit.

## Hors périmètre

- La Terminale (A1, A2, C, D) et la 2nde (A, C) : inchangées.
- Le référentiel de Develop, de Staging et de production : l'équipe le tient à l'écran, aucune donnée n'y est modifiée par ce chantier.
- Le barème de classes lui-même (nombre de classes par série et par niveau) : il suit les séries liées, il ne change pas.
- Les fichiers de contenu et les progressions : déjà corrigés.
- La série E de la Philosophie : elle n'existe pas dans le référentiel, ni avant ni après.

## Ce que le grill a révélé

> Rempli après la session de questions adverses.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Avec trois séries en 1ère, un lycée public passe de 77 à 71 classes et un lycée privé de 38 à 35. Est-ce voulu, ou la 1ère A doit-elle recevoir plus de classes ? | 71 et 35 : le barème par série ne change pas. | Les totaux attendus changent partout où ils sont écrits (décisions d'origine, tests, budgets de performance). Aucun changement de barème dans ce chantier. |
| Les tests ont leur propre taxonomie fixe (1ère = A1, A2, C, D) et une dizaine citent les totaux 77 et 38. On change seulement le référentiel de développement, ou tout ? | Tout aligner. | Le périmètre couvre le référentiel de développement, la taxonomie des tests et les tests qui citent les totaux. Diff plus large, plus aucun test ne décrit un référentiel disparu. |
| Une base de développement déjà remplie garde les anciens liens 1ère × A1 et A2, car le référentiel de départ n'efface rien. Comment les traite-t-on ? | Nettoyage automatique (et non une simple consigne de réinitialisation). | Le référentiel doit retirer lui-même ces liens. Il faut écrire le cas où le lien est déjà utilisé : voir la question ouverte. |
| Dans une base déjà remplie, ces liens sont presque toujours utilisés par des classes et des cours. Que fait le nettoyage ? | Réponse initiale : supprimer aussi leurs classes et leurs cours. **Contestée** : toutes les liaisons de la base interdisent la suppression, donc il faut vider à la main 16 tables dépendantes. Question rouverte, fermée sans réponse. | Point ouvert. Recommandation : laisser le lien utilisé, avec un avertissement qui invite à réinitialiser la base ; ne nettoyer que les liens inutilisés. |

## Cas limites identifiés

- Une base de développement existante contient des classes d'écoles de démonstration et des cours liés à 1ère × A1 et A2 : le nettoyage ne peut pas supprimer ces liens tant qu'ils servent.
- Le référentiel de démarrage s'exécute plusieurs fois et ne doit rien casser : le nettoyage doit être idempotent.
- Les établissements de démonstration ordonnent leurs séries par un ordre fixe qui cite A1 et A2 : il doit rester valable avec la série A seule en 1ère.
- Les écrans de l'équipe affichent le total de classes du barème : il passe de 77 à 71 en développement.

## Questions encore ouvertes

- **Que fait le nettoyage d'un lien 1ère × A1 ou A2 encore utilisé ?** Laisser avec un avertissement (recommandé), supprimer en cascade 16 tables (gros lot destructif), ou arrêter le démarrage.
- Le garde-fou « tous les couples niveau–série des fichiers de leçons existent dans le référentiel de développement » est-il dans ce chantier ? Non posée.
- Comment documenter le changement : amendement daté des deux décisions d'origine (usage du dépôt), non tranché avec l'équipe.
