# Memo — Les 10 premières leçons d'EDHC de 3ème

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers Develop) |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-edhc` |
| **Programme** | `contenus-3e-autres-matieres` (vague 5) |

---

## Le problème

Un élève de 3ème n'a aucune leçon d'EDHC à réviser au format en vigueur : les 10 premières leçons de la progression sont des fiches vides, et les 3 anciennes leçons rédigées sont dans un format retiré qui ne s'importe plus.

## Pour qui

- **Student** de 3ème, qui révise avant une interrogation, un devoir ou le BEPC d'EDHC.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Dernière vague du programme. Elle ne demande aucune sorte de figure à elle : le schéma fléché, la carte de Côte d'Ivoire et la courbe arrivent avec la vague d'Histoire-Géographie, le contrôle et la consigne par matière avec celle de Français.

## Hors périmètre

- Tout code : aucune sorte de figure nouvelle, aucune règle d'import ni de contrôle nouvelle.
- Les leçons au-delà des 10 premières, les autres niveaux, les autres matières.
- Un PDF ou une vue de téléchargement : le livrable est un lot de fichiers prêts à importer, envoyés au porteur.
- L'import, la relecture par l'équipe et la publication.
- Parent, SchoolStaff : rien de nouveau.

## Ce que le grill a révélé

Grill court : le programme a tranché l'essentiel (memo et ADR des figures). Questions propres à la vague :

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| L'EDHC a-t-elle besoin d'une sorte de figure à elle ? | Non : schéma fléché, carte de Côte d'Ivoire et graphique suffisent (ADR des figures, inventaire). | Aucun code. Les fichiers ne se contrôlent qu'une fois la vague 2 fusionnée ; la rédaction peut commencer avant, d'après les formes de l'ADR. |
| Quelle part de questions corrigées automatiquement ? | La moitié au moins par leçon (programme). | Les questions rédigées portent la prise de position et la justification, avec corrigé modèle, barème et critères. |
| Quels textes font foi pour les institutions ? | Ceux en vigueur : Constitution du 8 novembre 2016 et institutions actuelles. | Aucune institution supprimée présentée comme actuelle ; un fait incertain n'est pas écrit, il part dans les points à faire valider. |
| Comment traiter les partis politiques et le scrutin ? | De façon neutre, sans opinion politique. | Aucun parti réel ni personnalité politique nommés en exemple ; situations d'école ou fictives ; chiffres des graphiques fictifs et annoncés comme tels. |
| Les alliances interethniques : quels faits ? | Ceux du programme et des sources reconnues, sans stéréotype. | Seules les alliances sûres sont nommées ; la carte situe les aires culturelles sans hiérarchie entre peuples. |
| Que deviennent les 3 fichiers v1 du même intitulé ? | Ils sont remplacés. | Réécrits en v3 au même nom ; aucun doublon. |

## Cas limites identifiés

- Une figure `diagram` ou `map` tant que la vague 2 n'est pas fusionnée : refusée par le contrôle (sorte inconnue) ; la livraison attend.
- Un identifiant de lieu ou de zone absent du fond `cote_d_ivoire` : refusé (`figure_invalid`) ; les identifiants sont alignés sur ceux livrés par la vague 2.
- Une leçon à moins de 50 % de questions corrigées automatiquement : avertissement, donc non livrée.
- Une question rédigée sans corrigé, barème ou critères : refusée.
- Une question qui demande une opinion politique : interdite ; une prise de position porte sur un comportement civique (payer l'impôt, respecter un bien public), argumentée par la règle.
- Une institution ou une loi citée avec une date ou un nom incertain : non écrite, signalée à l'enseignant.

## Questions encore ouvertes

- Aucune.
