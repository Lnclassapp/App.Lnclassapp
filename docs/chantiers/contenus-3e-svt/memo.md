# Memo — Les 10 premières leçons de SVT de 3ème et leurs planches

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-svt` |
| **Programme** | `contenus-3e-autres-matieres` (vague 3) |

---

## Le problème

Un élève de 3ème n'a aucune leçon de SVT à réviser au format en vigueur : les 10 premières leçons de la progression sont des fiches vides, et les 3 anciennes leçons rédigées sont dans un format retiré. La SVT s'apprend sur des schémas légendés (appareil digestif, cœur, frottis sanguin, profil de sol…) : aucune figure de l'application n'en dessine.

## Pour qui

- **Student** de 3ème, qui révise avant une interrogation, un devoir ou le BEPC de SVT ; qui apprend à légender un schéma.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Troisième vague du programme : la vague 2 livre le schéma fléché, la frise et la courbe dont la SVT a aussi besoin ; il ne manque que la planche légendée.

## Hors périmètre

- Les planches de Physique-Chimie (dynamomètre, électrolyseur, eudiomètre) : vague 4, qui les ajoute sans changer le module commun des planches.
- Toute autre sorte de figure : `timeline`, `diagram`, `stat_chart` en courbe viennent de la vague 2, réutilisées telles quelles.
- Les leçons au-delà des 10 premières, les autres niveaux.
- Une planche interactive (curseur, glisser-déposer d'étiquettes) : la planche est un dessin fixe (ADR, aucun réglable).
- Parent, SchoolStaff : rien de nouveau.

## Ce que le grill a révélé

Grill court : le programme, l'ADR et l'UDR (acceptés) ont tranché l'essentiel. Questions propres à la vague, tranchées par le porteur dans sa commande de vague ou par l'ADR :

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui garantit qu'une planche est juste scientifiquement ? | Un enseignant de SVT relit sur captures ; une relecture IA indépendante relit les leçons. | Captures de chaque planche en noms et en numéros, au téléphone et sur ordinateur, envoyées au porteur ; jamais commitées. |
| Comment la vague 4 ajoute-t-elle ses planches sans rouvrir le module ? | Un dessin par planche, dans des fichiers séparés ; le module commun ne connaît que la liste. | Le module commun ne change pas quand une planche s'ajoute ; seule la liste des planches s'allonge. |
| Les parties de chaque planche ne sont fixées par l'ADR que pour l'appareil digestif. | Chaque planche déclare ses parties (ADR §4.2). | La vague fixe les parties des 7 autres planches, avec le vocabulaire du programme ivoirien ; même liste côté serveur et côté navigateur (test). |
| Une planche en numéros montre-t-elle la légende ? | Non (UDR) : l'élève doit légender. | Les exercices « légender le schéma » utilisent les numéros ; la fiche de cours utilise les noms. |
| La vague 2 modifie les mêmes fichiers du domaine. | Tant qu'elle n'est pas fusionnée, rien n'y est touché. | Dessin et rédaction d'abord ; le domaine, la liste blanche et la consigne de rédaction après la fusion de la vague 2. |
| Que faire d'une leçon qui veut un schéma absent de l'inventaire (ex. glande salivaire en coupe) ? | L'inventaire de l'ADR fait foi ; une planche nouvelle est un amendement. | Pas de planche hors liste ; le reste passe par `diagram` ou par le texte. |

## Cas limites identifiés

- Une planche dont une partie citée n'existe pas : refusée à l'import et au contrôle ; côté navigateur, rien n'est dessiné et la description reste.
- Une partie citée deux fois dans les étiquettes : refusée.
- Douze étiquettes sur une planche au téléphone : les étiquettes se répartissent à gauche et à droite sans se chevaucher.
- Une partie surlignée sans étiquette : surlignée quand même (teinte et contour).
- Une planche en numéros : aucune légende, les numéros suivent l'ordre des étiquettes de la leçon.
- Un élève daltonien : la partie surlignée se lit par son contour épais, pas seulement par la teinte.
- Sans JavaScript : la description de la planche suffit à faire l'exercice.

## Questions encore ouvertes

- Aucune.
