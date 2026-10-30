# Memo — Les 10 premières leçons de Physique-Chimie de 3ème, tracé optique, molécule et planches de PC

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-physique-chimie` |
| **Programme** | `contenus-3e-autres-matieres` (vague 4) |

---

## Le problème

Un élève de 3ème n'a aucune leçon de Physique-Chimie à réviser au format en vigueur : les 10 premières leçons de la progression sont des fiches vides, et les 4 anciennes leçons rédigées sont dans un format retiré. Pour les écrire, il manque des figures : rien ne dessine la marche des rayons à travers une lentille ni le défaut d'un œil, rien ne dessine une molécule d'alcane, et aucune planche ne montre un dynamomètre, un électrolyseur ou un eudiomètre.

## Pour qui

- **Student** de 3ème, qui révise avant une interrogation, un devoir ou le BEPC de Physique-Chimie, et fait varier une lentille ou une chaîne carbonée pour comprendre.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague 4 du programme : les sortes partagées (schéma fléché, courbe, planches) arrivent avec les vagues 2 et 3 ; la Physique-Chimie ajoute les deux sortes qui lui sont propres et ses trois planches, puis rédige ses leçons.

## Hors périmètre

- Les sortes livrées par d'autres vagues (`timeline`, `map`, `diagram`, `stat_chart` courbe, module `plate`) : réutilisées telles quelles, jamais modifiées ici.
- Les planches de SVT ; toute planche, sorte ou mode non listé par l'ADR des figures de 3ème.
- Les leçons au-delà des 10 premières, les autres niveaux, les autres matières.
- Un PDF ou une vue de téléchargement ; l'import lui-même (règles inchangées).
- Parent, SchoolStaff : rien de nouveau.

## Ce que le grill a révélé

Grill court : le cadrage du programme, l'ADR et l'UDR des figures de 3ème (acceptés) ont tranché l'essentiel ; le porteur a demandé d'avancer sans reposer de question. Questions propres à la vague, tranchées d'après ces décisions :

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle convention pour le tracé optique : distance ou abscisse algébrique ? | La leçon donne des distances positives (`object_distance`, `focal`) ; le dessin calcule en algébrique, comme le programme : OA = −distance, f' = ±focale, 1/OA' − 1/OA = 1/f'. | Une seule formule dans le module, OA' et γ affichés signés ; la leçon écrit les mêmes conventions dans ses méthodes. |
| Objet placé au foyer objet d'une lentille convergente ? | L'image est rejetée à l'infini. | Le dessin trace les rayons parallèles et affiche « image à l'infini » au lieu d'une valeur ; cas testé. |
| Que montre le mode œil si la correction ne convient pas au défaut (convergente sur un myope) ? | Le dessin reste juste : le point de convergence s'éloigne encore de la rétine. | Pas de refus au contrôle ; la leçon s'en sert comme contre-exemple. |
| Quelles parties pour les trois planches de PC ? L'ADR nomme les planches, pas leurs parties. | Celles que demandent les leçons 1 et 6 : dynamomètre (anneau, ressort, graduation, index, crochet, corps suspendu), électrolyseur (générateur, anode, cathode, électrolyte, tubes et gaz), eudiomètre (tube gradué, électrodes, étincelle, cuve, gaz). | Liste fermée écrite dans le plan, identique domaine ↔ module (test de parité). |
| Valeur de g ? | 10 N/kg, sauf quand l'énoncé du programme en donne une autre (9,8 N/kg). | Consigne des rédacteurs ; la relecture refait chaque calcul. |
| Que deviennent les 4 anciennes leçons du même intitulé ? | Remplacées. | Les 4 fichiers v1 sont réécrits en v3 au même nom ; aucun doublon. |
| Comment avancer pendant que les vagues 2 et 3 modifient les mêmes fichiers du domaine ? | Les fichiers partagés ne sont touchés qu'après la fusion de la vague 2 (puis de la 3 pour les planches). | Les modules de rendu, leurs tests et la rédaction partent d'abord ; le lot du domaine attend. |

## Cas limites identifiés

- Objet au foyer (image à l'infini), objet entre foyer et lentille (image virtuelle, droite, agrandie), lentille divergente (image toujours virtuelle).
- Curseur qui amène `object_distance` égale à `focal` : pas de division par zéro, l'affichage passe à « à l'infini ».
- Molécule `custom` dont un carbone a 5 liaisons, ou un hydrogène 2 : refus `figure_invalid`.
- Curseur `carbons` à 1 (méthane : pas de liaison C–C) et à 10 (décane : la chaîne tient dans 640 unités).
- Planche citant une partie absente : refus `figure_invalid` ; planche inconnue du module : état `error`, description visible.
- Calcul faux dans une leçon (poids, travail, puissance, énergie, OA') : la relecture IA refait chaque calcul ; pas de livraison tant qu'il en reste un.

## Questions encore ouvertes

- Aucune.
