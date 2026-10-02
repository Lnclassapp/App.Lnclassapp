# Journal — Fonctions de l’espace élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | FAQ construite tout de suite, avant le reste du chantier (commit `189d7f92`) | Demande du porteur | UDR-0061 §3.1, acceptée |
| 2026-10-02 | Quatre pages publiques ajoutées : Mission, Protection des données, CGU, CGV ; entité « Lnclass Côte d'Ivoire » | Demande du porteur (Q15, Q16) | UDR-0063 |
| 2026-10-02 | Jours de séance : une ligne par jour, clé composite vers `teacher_classrooms` ; « rendu en retard » lu, jamais stocké | Un seul état « non renseigné », aucune cascade nouvelle, une seule vérité | ADR-0072 |
| 2026-10-02 | Lot R redéfini : pas d'anonymisation automatique ; archive pour l'élève et l'établissement ; suppression sur demande dans les 30 jours | Porteur | Amendement de l'ADR-0036 retiré ; PRD amendé |
| 2026-10-02 | Suppression d'un compte réservée à l'équipe `admin` ; elle efface aussi les tentatives de connexion du compte et de son numéro | Relecture sécurité : matrice de l'ADR-0038 ; le numéro et l'IP restaient, et un numéro repris héritait du verrou | ADR-0038 appliqué, pas amendé |
| 2026-10-02 | Bloc « Cours » trié par matière puis nom | `courses` n'a pas de position de programme | non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Assets non recompilés** : `yarn build` peut sortir en 0 sans compiler ; les tests système du lot B ont échoué sur un JS périmé. Compiler avec `node esbuild.config.mjs` et `npx @tailwindcss/cli`.
- **Course au morphing** : après `turbo_stream.refresh`, un test qui clique « Assigner » peut atteindre l'ancien bouton avant le remplacement. Attendre la nouvelle forme (`find_link` ou `find_button`) avant de cliquer.
- **Bascule après « Retirer »** : le stream d'archivage reconstruisait la bascule sans savoir si l'enseignant avait ses jours ; il réassignait sans modale, donc sans date, jusqu'au rechargement. Corrigé à l'intégration du lot C.
- **Garde de policy inatteignable** : un `before_action` qui doublait `allow_roles :team` laissait une branche non couverte (SimpleCov à 2469 / 2470). Il est redevenu utile avec la restriction à `admin`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- L'enseignant n'atteint un exercice, depuis sa classe, que par les **cours assignés** (page classe → cours → fiche → bascule). Retirer l'assignation de cours casse ce chemin : le grill ne l'avait pas vu (UDR-0062 §3.4, question ouverte).
- Cinq écrans portent des bascules de cours ou de fiche, pas deux : UDR-0013, 0028, 0029, 0030, et la carte « Cours assignés » de 0011 et 0027.
- Les purges des tentatives de connexion et des codes périmés (ADR-0036 §6) ne sont pas dans `config/recurring.yml`, et l'anonymisation d'un compte n'a pas de use case : la politique de protection des données ne peut pas les promettre.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
