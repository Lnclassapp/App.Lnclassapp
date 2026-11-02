# Memo — Les 11 leçons de Français de Première (A, C, D)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-11-01 |
| **Branche** | `feature/contenus-1ere-francais` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P8) |

---

## Le problème

Un élève de 1ère n'a aucune leçon de Français à réviser au format en vigueur : 3 leçons seulement sont rédigées (12 fichiers v1 dans `1ere-a1`, `1ere-a2`, `1ere-c`, `1ere-d`), au format v1 qui ne s'importe plus ; 8 leçons de la progression sont absentes.

## Pour qui

- **Student** de 1ère A, C ou D, qui révise avant une interrogation ou un devoir de Français.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague P8 du programme : la feuille de route est validée (D1 à D5) ; modèles : Français de Tle (PR #427) et de 3ème (PR #373).

## Hors périmètre

- Tout code : le Français n'emploie aucune figure ; aucune sorte nouvelle.
- Les tests : non touchés.
- Les autres matières et niveaux.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 11. A en a 10, C et D 10 (pas de « Groupement de textes romanesques » ; « Les valeurs des temps verbaux » en plus). | Écrites une fois (la dernière en C), déclinées en A1, A2, C et D (40 fichiers). |
| Série A ou A1/A2 ? | Le référentiel de 1ère (`db/seeds/catalog.rb`) a A1, A2, C, D : chaque leçon de A donne un fichier A1 et un fichier A2 (même texte). | Les v1 de `1ere-a1/` et `1ere-a2/` sont remplacées (D4). |
| Les rangs sont-ils les mêmes ? | Non (consignes 2/3, commentaire 3/2, focalisation 5/7, tonalités 7/5, résumé 8/6, argumentation 9/8, implicite 10/9). | Seuls `series_name` et le rang du `subtitle` changent ; aucune leçon ne cite un numéro ni ne s'appuie sur une autre leçon de 1ère. |
| Quels textes supports ? | Comme en 3ème et Tle : écrits pour Lnclass ; œuvres réelles en courtes références paraphrasées. | Aucun extrait long d'œuvre protégée ; faits incertains non écrits et signalés à l'enseignant. |

## Cas limites identifiés

- Œuvres au programme de l'établissement non connues : aucune œuvre unique supposée.
- Règle d'épreuve incertaine : non affirmée, signalée à l'enseignant.

## Questions encore ouvertes

- Aucune.
