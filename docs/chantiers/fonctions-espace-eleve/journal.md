# Journal — Fonctions de l’espace élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | FAQ construite tout de suite, avant le reste du chantier (commit `189d7f92`) | Demande du porteur | UDR-0061 §3.1, acceptée |
| 2026-10-02 | Quatre pages publiques ajoutées : Mission, Protection des données, CGU, CGV ; entité « Lnclass Côte d'Ivoire » | Demande du porteur (Q15, Q16) | UDR-0063 |
| 2026-10-02 | Jours de séance : une ligne par jour, clé composite vers `teacher_classrooms` ; « rendu en retard » lu, jamais stocké | Un seul état « non renseigné », aucune cascade nouvelle, une seule vérité | ADR-0072 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

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
