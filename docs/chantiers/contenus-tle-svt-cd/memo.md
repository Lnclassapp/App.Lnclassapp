# Memo — Les 10 premières leçons de SVT de Terminale C et D

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-svt-cd` |
| **Programme** | `contenus-v3-tous-niveaux` (vague T4) |

---

## Le problème

Un élève de Terminale C ou D n'a aucune leçon de SVT à réviser au format en vigueur : 14 des 20 premières leçons des deux progressions sont des fiches vides, et les 6 leçons rédigées sont au format v1, qui ne s'importe plus.

## Pour qui

- **Student** de Tle C ou D, qui révise avant une interrogation, un devoir ou le BAC de SVT.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T4 du programme : la feuille de route est validée (D1 à D5), le format v3, les figures et « Je m'entraîne » sont livrés en 3ème.

## Hors périmètre

- Tout code : aucune sorte de figure, planche ou partie nouvelle (neurone, synapse, sarcomère, mitochondrie, fleur manquent : texte ou `diagram` à la place, signalés au journal).
- Les leçons au-delà des 10 premières, les séries A1 et A2 (vague T5), les autres matières et niveaux.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.
- Parent, SchoolStaff : rien de nouveau.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 17 : trois intitulés sont communs à C et D (hérédité d'un caractère, système de défense, VIH). | Écrites une fois dans `tle-c/`, déclinées dans `tle-d/` avec la série et le rang de D : 20 fichiers. |
| Une leçon commune peut-elle s'appuyer sur une leçon de Tle propre à une série ? | Non : les acquis diffèrent (C1 n'existe pas en D, D1-D3 pas en C). | Les rédacteurs des leçons communes ne s'appuient que sur le programme de 1ère et sur les leçons communes précédentes. |
| Une figure demande-t-elle une sorte nouvelle ? | Non : planches existantes (appareil génital féminin, VIH, frottis sanguin), courbes, schémas fléchés, carte de Côte d'Ivoire. | Aucun code, aucun amendement d'ADR ; les schémas absents sont décrits en texte et listés comme besoin. |
| Que deviennent les 6 fichiers v1 du même intitulé ? | Remplacés (D4). | Réécrits en v3 au même nom ; aucun doublon. |
| Qui garantit le fond scientifique ? | Relecture IA indépendante (Opus), puis un enseignant de SVT avant publication. | Points à valider au journal du chantier et du programme. |

## Cas limites identifiés

- Un arbre généalogique : aucune sorte ne le dessine exactement ; décrit en texte (générations, individus numérotés) si `diagram` `tree` le fausse.
- Une valeur chiffrée incertaine (rendement en ATP, taux hormonaux, profondeur des gisements) : présentée comme résultat d'expérience de l'énoncé, ou non écrite, et signalée à l'enseignant.
- Une leçon commune déclinée : même contenu, seuls `series_name` et `subtitle` changent.

## Questions encore ouvertes

- Aucune.
