# Memo — Les 10 premières leçons de SVT de 1ère C et D

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-11-01 |
| **Branche** | `feature/contenus-1ere-svt-cd` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P5) |

---

## Le problème

Un élève de 1ère C ou D n'a que 3 leçons de SVT au format v1, qui ne s'importe plus, et aucune pour les 7 autres rangs.

## Pour qui

- **Student** de 1ère C ou D, qui révise avant une interrogation ou un devoir de SVT.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague P5 du programme : la Tle est fusionnée (SVT Tle C et D : #421, #422), le format v3, les figures et « Je m'entraîne » sont livrés.

## Hors périmètre

- Tout code : aucune sorte de figure ni planche nouvelle (gonade, méiose, fécondation, ribosome, globe, sol, chloroplaste, arc réflexe manquent : `diagram` ou texte à la place, signalés au journal).
- Les leçons au-delà des 10 premières, la série A (vague P6), les autres matières et niveaux.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 16 : quatre intitulés sont communs à C et D (méiose, synthèse des protéines, plaques, échanges d'ions). | Écrites une fois dans `1ere-c/`, déclinées dans `1ere-d/` avec la série et le rang de D : 20 fichiers. |
| Les paires proches (C1/D1, C3/D3, C6/D4) ? | Intitulés et rangs différents, même socle. | Deux fichiers distincts, D adapté de C (intitulé de D, exercices adaptés à la série). |
| Que deviennent les 6 v1 du même intitulé ? | Remplacés (D4). | Réécrits en v3 au même nom ; « La gamétogénèse chez les mammifères » et « La gamétogenèse » gardent chacune leur nom de fichier. |
| Qui garantit le fond scientifique ? | Relecture IA indépendante (Opus), puis un enseignant de SVT avant publication. | Points à valider au journal du chantier et du programme. |

## Cas limites identifiés

- Valeur chiffrée incertaine (durées, taux, vitesses) : donnée comme résultat d'expérience de l'énoncé, ou non écrite, et signalée à l'enseignant.
- Leçon déclinée : même contenu, seuls `series_name` et `subtitle` changent.

## Questions encore ouvertes

- Aucune.
