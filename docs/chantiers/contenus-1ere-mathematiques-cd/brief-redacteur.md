# Brief du rédacteur — une leçon de Mathématiques de 1ère C / D

> Tu rédiges **une leçon** (et sa déclinaison par série si elle est commune). Tu ne commites rien, tu ne touches à aucun autre fichier. Réponds en 15 lignes au plus (pas de JSON) : fichiers écrits, résultat des deux contrôles, points à faire valider par un enseignant.

## À lire d'abord
1. `docs/contenus/prompt-redaction.md` en entier (le prompt de rédaction : gabarit en 4 blocs, méthode en étapes, exemple, corrections, figures, types de questions, « Je m'entraîne »).
2. Deux leçons de Tle comme **modèle de niveau, de longueur et de style** : `docs/contenus/lecons-traitees/tle-c/mathematiques/limites-et-continuite.json` et `tle-d/mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json` (lis la structure, ne recopie pas leur contenu). Reproduis leur forme : clés `practice` (statement, questions, `hint`, `blank`), `figures`, thème, 4 problèmes, etc.
3. Les v1 de 1ère C/D (`1ere-c/mathematiques/`, `1ere-d/mathematiques/`) pour les 3 premières leçons : **sujet seulement**, à réécrire entièrement, jamais à fusionner.

## Format
- `lnclass.course-tree` version 3, un cours par fichier, `level_name` "1ère", `material_name` "Mathématiques", `series_name` "C" ou "D", `name` = intitulé de la progression **à l'identique**, `subtitle` = `Leçon N — progression DPFC 2026-2027` (N = rang dans la série du fichier, comme les v1), `theme` imposé ci-dessous.
- Dossier : `docs/contenus/lecons-traitees/1ere-c/mathematiques/` ou `1ere-d/mathematiques/`. Nom de fichier : intitulé en minuscules sans accents, non-alphanumériques → un tiret (« Équations et inéquations dans ℝ » → `equations-et-inequations-dans.json`). Un fichier v1 du même nom est remplacé.
- 4 fiches (3 à 6 si le programme l'exige), 1 exercice par notion (≥ 5 questions), exactement 4 problèmes (≥ 5 questions), un `practice` par notion, ≥ 50 % de questions corrigées automatiquement, corrections qui reprennent les « Étape N » de La méthode.
- **Leçon commune C/D** : écris d'abord la version C ; la version D = mêmes notions et mêmes exercices de fixation, avec `series_name`, `subtitle` (rang D) et `name` de la progression D, **problèmes 3 et 4 réécrits au niveau de la série D** (D plus léger : moins de questions rédigées, calculs plus guidés) ; les questions de démonstration sont adaptées. Deux fichiers distincts, jamais un renvoi.
- Décor des énoncés de problèmes : celui imposé ci-dessous (dominante, pas obligation). Noms et lieux ivoiriens, montants en FCFA.

## Acquis et interdits (essentiel)
Une leçon **ne s'appuie que sur les leçons acquises** de sa liste et **ne traite aucune notion d'une leçon interdite** (même si elle fait partie du programme général : elle a sa propre leçon). Acquis du collège et de la 2nde : toujours permis.

Progression C : 1 Équations et inéquations dans ℝ · 2 Angles orientés et trigonométrie · 3 Généralités sur les fonctions · 4 Barycentre · 5 Limites et continuité · 6 Dénombrement · 7 Extension de la notion de limite · 8 Composées de transformations du plan · 9 Dérivation · 10 Orthogonalité de l'espace.
Progression D : 1 Équations et inéquations du second degré dans ℝ · 2 Angles orientés et trigonométrie · 3 Généralités sur les fonctions · 4 Limites et continuité · 5 Dénombrement · 6 Dérivation · 7 Extension de la notion de limite · 8 Barycentre · 9 Étude et représentation graphique d'une fonction · 10 Probabilité.

| Leçon | Fichiers | Acquis | Interdit (autres leçons de la progression) | Décor / thème |
|---|---|---|---|---|
| Équations et inéquations dans ℝ | C1 | rien | toutes les autres | marché · blue |
| Équations et inéquations du second degré dans ℝ | D1 | rien | toutes les autres | champ, terrain · teal |
| Angles orientés et trigonométrie | C2, D2 | Équations (C1 / D1) | Généralités et suivantes | roue, horloge, gbaka · burgundy |
| Généralités sur les fonctions | C3, D3 | Équations, Angles | Barycentre, Limites, Dénombrement, Extension, Dérivation, Composées, Orthogonalité, Étude, Probabilité. **Ne pas s'appuyer sur Angles/trigonométrie** (la 1ère A déclinera cette leçon sans Angles) | téléphone, mobile money · blue |
| Barycentre | C4, D8 | Équations, Angles, Généralités | Limites, Dénombrement, Extension, Dérivation, Composées, Orthogonalité, Étude, Probabilité | atelier, balance, plantation · teal |
| Limites et continuité | C5, D4 | Équations, Angles, Généralités | Barycentre (ne pas l'utiliser), Dénombrement, Extension (limites infinies en l'infini mises à part si le programme les place ici : voir note), Dérivation, tout le reste | burgundy · atelier de couture, pêche |
| Dénombrement | C6, D5 | Équations, Angles, Généralités, Limites. **Ne s'appuyer que sur Équations** (la 1ère A déclinera cette leçon) | Barycentre, Extension, Dérivation, Composées, Orthogonalité, Étude, Probabilité | école (comités, codes, tirages) · blue |
| Extension de la notion de limite | C7, D7 | Équations, Angles, Généralités, Limites, Dénombrement | Barycentre, Dérivation, Composées, Orthogonalité, Étude, Probabilité | transport, production · teal |
| Composées de transformations du plan | C8 | C1 à C7 | Dérivation, Orthogonalité | motifs de pagne, carrelage · burgundy |
| Dérivation | C9, D6 | Équations, Angles, Généralités, Limites, Dénombrement | Extension (non acquise en D), Barycentre, Composées, Orthogonalité, Étude, Probabilité | football, vitesse, coûts · blue |
| Orthogonalité de l'espace | C10 | C1 à C9 | — | chantier, charpente · teal |
| Étude et représentation graphique d'une fonction | D9 | D1 à D8 | Probabilité | plantation, rendement · burgundy |
| Probabilité | D10 | D1 à D9 | — | jeux de société, marché, santé · blue |

Note « Limites et continuité » / « Extension de la notion de limite » : la première traite les limites finies et en l'infini de référence et les opérations usuelles, la continuité ; la seconde traite les formes indéterminées, limites infinies et asymptotes. Si le programme ivoirien de la 1ère répartit autrement, suis le programme et note-le dans « À faire valider ». Pas de dérivée dans ces leçons.

## Règles de fond
- **Programme officiel ivoirien de 1ère C/D** ; une notion incertaine n'est pas écrite : « À compléter » + point à faire valider. Aucune valeur numérique ou fait inventé.
- **Figures** : seules les sortes existantes (`geometry`, `coordinate_plane` droites/points/segments/vecteurs, `number_line`, `stat_chart`, `diagram`). Courbe de fonction, tableau de variations, arbre de probabilités, solide en perspective : **décrits dans l'énoncé**, pas de figure ; note la demande. Une figure ne doit jamais afficher la réponse du problème qu'elle accompagne.
- Chaque question redonne ses données (aucune dépendance à une autre question ni à une figure absente) ; chaque leurre est expliqué ; étapes de correction identiques aux étapes de La méthode (mêmes mots, même numérotation) ; pas de `hint`/`blank` hors `practice` ; ne donne pas « −4 » et « -4 » comme deux réponses acceptées.
- « Je m'entraîne » : 1 à 6 questions par notion, aucune reprise d'une question de l'exercice noté, au moins une question à plusieurs cases (`___` ↔ clés `blank`) et un `hint` dans la leçon.
- LaTeX en `$…$` avec doubles barres obliques inverses dans le JSON.

## Contrôles (depuis la racine du dépôt, jusqu'à zéro erreur ET zéro avertissement, 3 tours au plus)
```
ruby script/contenus/valider.rb <fichier.json>
ruby docs/chantiers/contenus-1ere-mathematiques-cd/controle-entrainement.rb <fichier.json>
```
Refais toi-même chaque calcul de ta leçon avant de rendre ; écris le fichier sur disque dès qu'il est fini, sans le recopier dans ta réponse.
