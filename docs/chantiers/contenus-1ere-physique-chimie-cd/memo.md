# Memo — Les leçons de Physique-Chimie de 1ère C et D au format v3

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-01 |
| **Branche** | `feature/contenus-1ere-physique-chimie-cd` |
| **Programme** | contenus-v3-tous-niveaux (vague P3) |

---

## Le problème

Un élève de 1ère C ou D n'a aucune leçon de Physique-Chimie à réviser au format en vigueur : les 10 premières leçons de chaque série sont des fiches vides ou, pour 6 d'entre elles, des fichiers v1 qui ne s'importent plus.

## Pour qui

- **Student** de 1ère C ou D, qui révise avant un devoir ou le BAC blanc.
- **Teacher**, qui donne les exercices de la leçon.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague P3 du programme `contenus-v3-tous-niveaux`, après la Tle (modèle : `contenus-tle-physique-chimie`, PR #415).

## Hors périmètre

- Tout code : les sortes de figures existantes suffisent.
- Les leçons au-delà de la 10e de chaque série, les autres matières, niveaux et la série A.
- La publication : les leçons restent en brouillon jusqu'à la relecture d'un enseignant.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence |
|---|---|---|
| Combien de leçons ? La feuille de route annonce 13. | 13 intitulés mais 12 contenus : C1 « Travail et puissance… translation » et D1 « …d'une force constante… » sont la même notion. | 12 leçons écrites, 20 fichiers (10 par série), chaque intitulé gardé. |
| « Énergie potentielle » (C8) et « Énergie potentielle de pesanteur » (D6) : une leçon ? | Deux leçons : la série C traite aussi l'énergie potentielle élastique, la D seulement la pesanteur. | Deux contenus distincts. |
| Acquis d'une leçon commune dont l'ordre diffère entre C et D ? | Seuls les acquis communs aux deux ordres sont permis (ex. Énergie cinétique : pas de rotation ; Énergie mécanique : pesanteur seulement). | Consigne aux rédacteurs. |
| Que deviennent les 6 fichiers v1 de 1ère C/D ? | Remplacés par le v3 du même intitulé (D4). | Aucun doublon. |
| Valeur de g ? | 10 N/kg sauf énoncé contraire (ou 9,8 si précisé dans l'énoncé). | Consigne ; la relecture refait chaque calcul. |

## Cas limites identifiés

- Une leçon citant une notion d'une leçon suivante : interdit (acquis = leçons précédentes des deux séries, 2nde et 3ème).
- Calcul faux : la relecture Opus refait chaque calcul ; pas de livraison tant qu'il en reste un.
- Notion douteuse au regard du programme : « À compléter » et point à valider au journal du programme.

## Questions encore ouvertes

- Aucune.
