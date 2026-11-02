# Brief du rédacteur — une leçon de Mathématiques de 1ère A

> Tu rédiges **une leçon**. Tu ne commites rien, tu ne touches à aucun autre fichier. Réponds en 12 lignes au plus (pas de JSON) : fichier écrit, résultat des deux contrôles, points à faire valider par un enseignant.

## À lire d'abord
1. `docs/contenus/prompt-redaction.md` en entier (gabarit en 4 blocs, méthode en étapes, exemple, corrections, figures, types de questions, « Je m'entraîne »).
2. **Modèle de niveau, de longueur et de style** : `docs/contenus/lecons-traitees/tle-a1/mathematiques/suites-numeriques.json` (même série littéraire, v3) ; lis la structure (clés `practice` avec `statement`, `questions`, `hint`, `blank` ; `figures` ; thème ; 4 problèmes), ne recopie pas le contenu.
3. Pour **Dénombrement** et **Généralités sur les fonctions** : la leçon de 1ère C (`1ere-c/mathematiques/denombrement.json`, `generalites-sur-les-fonctions.json`) est le **point de départ** ; décline-la au niveau A : mêmes notions principales, calculs plus simples, exemples concrets, exercices et problèmes allégés (≥ 5 questions quand même, moins de questions rédigées, plus de guidage). Réécris, ne copie pas mot pour mot.
4. Les v1 de `1ere-a1/mathematiques/` (Équations, Dénombrement, Généralités) : **sujet seulement**, à réécrire entièrement.

## Format
- `lnclass.course-tree` version 3, un cours par fichier, `level_name` "1ère", `material_name` "Mathématiques", `series_name` "A", `name` = intitulé de la progression **à l'identique**, `subtitle` = `Leçon N — progression DPFC 2026-2027` (N = rang), `theme` imposé ci-dessous.
- Fichier : `docs/contenus/lecons-traitees/1ere-a1/ et 1ere-a2/mathematiques/<nom>.json` (nom indiqué dans le tableau).
- 3 à 5 fiches selon le programme, 1 exercice par notion (≥ 5 questions), exactement 4 problèmes (≥ 5 questions), un `practice` par notion, ≥ 50 % de questions corrigées automatiquement, corrections qui reprennent les « Étape N » de La méthode (mêmes mots, même numérotation).
- Niveau série A (littéraire) : calculs simples, nombres petits, contextes concrets, pas de démonstration théorique. Noms et lieux ivoiriens, montants en FCFA.

## Progression A et acquis / interdits
1 Équations et inéquations · 2 Dénombrement · 3 Généralités sur les fonctions · 4 Dérivabilité et étude de fonctions · 5 Suites numériques · 6 Statistique · 7 Systèmes d'équations dans ℝ × ℝ.
Une leçon ne s'appuie que sur les leçons de rang inférieur et ne traite aucune notion d'une leçon de rang supérieur (même si elle fait partie du programme général). Acquis du collège et de la 2nde : toujours permis.

| Leçon | Fichier | Acquis | Décor / thème |
|---|---|---|---|
| 1 Équations et inéquations | `equations-et-inequations` | rien | marché · blue |
| 2 Dénombrement | `denombrement` | 1 | école (comités, codes, tirages) · teal |
| 3 Généralités sur les fonctions | `generalites-sur-les-fonctions` | 1, 2 | téléphone, mobile money · burgundy |
| 4 Dérivabilité et étude de fonctions | `derivabilite-et-etude-de-fonctions` | 1 à 3 | production, recettes, football · blue |
| 5 Suites numériques | `suites-numeriques` | 1 à 4 | épargne, population, loyers · teal |
| 6 Statistique | `statistique` | 1 à 5 | notes de classe, enquête de quartier · burgundy |
| 7 Systèmes d'équations dans ℝ × ℝ | `systemes-d-equations-dans` | 1 à 6 | prix au marché, billets · blue |

## Règles de fond
- **Programme officiel ivoirien de 1ère A** ; une notion incertaine n'est pas écrite : « À compléter » + point à faire valider. Aucune valeur numérique ou fait inventé.
- **Figures** : seulement les sortes existantes (`geometry`, `coordinate_plane` droites/points/segments, `number_line`, `stat_chart`, `diagram`). Courbe de fonction, tableau de variations : décrits dans l'énoncé, pas de figure. Une figure n'affiche jamais la réponse du problème qu'elle accompagne.
- Chaque question redonne ses données (aucune dépendance à une autre question ni à une figure absente) ; chaque leurre est expliqué ; pas de `hint`/`blank` hors `practice` ; ne donne pas « −4 » et « -4 » comme deux réponses acceptées ; `fill_blank` : 5 réponses au plus.
- « Je m'entraîne » : 1 à 6 questions par notion, aucune reprise d'une question de l'exercice noté, au moins une question à plusieurs cases (`___` ↔ clés `blank`) et un `hint` dans la leçon.
- LaTeX en `$…$` avec doubles barres obliques inverses dans le JSON.

## Contrôles (racine du dépôt, zéro erreur ET zéro avertissement, 3 tours au plus)
```
ruby script/contenus/valider.rb <fichier.json>
ruby docs/chantiers/contenus-1ere-mathematiques-a/controle-entrainement.rb <fichier.json>
```
Refais toi-même chaque calcul avant de rendre ; écris le fichier sur disque dès qu'il est fini, sans le recopier dans ta réponse.
