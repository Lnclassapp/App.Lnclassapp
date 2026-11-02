# Memo — Les leçons de Physique-Chimie de Tle C et D au format v3

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR #415) |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-physique-chimie` |
| **Programme** | contenus-v3-tous-niveaux (vague T3) |

---

## Le problème

Un élève de Tle C ou D n'a aucune leçon de Physique-Chimie à réviser au format en vigueur : les 10 premières leçons de chaque série sont des fiches vides ou, pour 3 d'entre elles, des fichiers v1 qui ne s'importent plus.

## Pour qui

- **Student** de Tle C ou D, qui révise avant un devoir ou le BAC.
- **Teacher**, qui donne les exercices de la leçon.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T3 du programme `contenus-v3-tous-niveaux` (feuille de route validée le 2026-10-31) : la Tle passe en premier.

## Hors périmètre

- Tout code : les sortes de figures existantes suffisent (`coordinate_plane`, `stat_chart` courbe, `molecule` custom, `diagram`, `geometry`).
- Les leçons au-delà de la 10e de chaque série, les autres matières et niveaux.
- La publication : les leçons restent en brouillon jusqu'à la relecture d'un enseignant.

## Ce que le grill a révélé

Grill court : la feuille de route (D1–D5) et le prompt commun des vagues tranchent l'essentiel.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? La feuille de route annonce 13. | 12 : C6 « Mouvements dans les champs g⃗ et E⃗ uniformes » et D6 « Mouvements dans les champs (g⃗ et E⃗) uniformes » sont la même leçon, comptée deux fois au chiffrage. | 12 leçons écrites, 20 fichiers (un par série). |
| Une leçon commune à C et D : un fichier ou deux ? | Écrite une fois, déclinée en un fichier par série (un cours = une série) ; intitulé et rang de chaque série gardés. | Savon : rang 8 en C, 9 en D ; oscillations : 9 en C, 8 en D. |
| Faut-il une sorte de figure nouvelle (champ, ressort, oscilloscope) ? | Non : trajectoires et vecteurs en repère, courbes x(t) et v(t), molécules en mode custom, schémas fléchés. | Aucun amendement d'ADR, aucun code. |
| Que deviennent les 6 fichiers v1 de Tle C et D ? | Remplacés par le v3 du même intitulé (D4). | Aucun doublon. |
| Valeur de g ? | 9,8 N/kg (programme de Tle), sauf énoncé contraire. | Consigne des rédacteurs ; la relecture refait chaque calcul. |

## Cas limites identifiés

- Série D : pas d'interaction gravitationnelle ni de champ magnétique ; amines et acides α-aminés propres à D.
- Une leçon citant une notion d'une leçon suivante de la progression : interdit (acquis = leçons précédentes et 1ère).
- Calcul faux : la relecture indépendante refait chaque calcul ; pas de livraison tant qu'il en reste un.

## Questions encore ouvertes

- Aucune.
