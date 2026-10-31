# Journal — Les 10 premières leçons de Mathématiques de Tle C et de Tle D

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | 14 leçons distinctes, 20 fichiers : le brief annonçait 15 leçons mais en listait 14 | La liste des rangs C1–C10 et D1–D10 fait foi | Non |
| 2026-10-31 | Leçons communes écrites une fois en C ; en D, problèmes 3 et 4 réécrits au niveau D, notions et exercices de fixation repris | Même cours, exigences d'évaluation différentes | Non |
| 2026-10-31 | « Fonctions exponentielles et fonctions puissances » (C9) et « Fonctions exponentielles et puissances » (D6) gardent chacune le titre de leur progression | La clé de doublon de l'import inclut le nom | Non |
| 2026-10-31 | Aucune sorte de figure nouvelle : courbes, tableaux de variations, solides 3D et coniques décrits par des points, segments et droites ; la dette est notée | Le périmètre de la vague exclut le code | Non |
| 2026-10-31 | Contrôle de « Je m'entraîne » par un script d'orchestrateur (`NotionPractice.errors_for`, cases, doublons) en plus de `valider.rb` | `valider.rb` ne lit pas `practice` | Non |

## Ce qui a dérapé

- Les relectures ont trouvé 3 défauts bloquants, tous corrigés : une conclusion « les deux premières affirmations » qui contredisait les bonnes réponses (Primitives, puis Calcul intégral), et un indice qui donnait la définition du majorant pour le minorant (Suites).
- Fautes répétées d'une leçon à l'autre : étapes de correction renommées ou décalées par rapport à La méthode, leurres non expliqués, questions qui ne redonnent pas leurs données, figure qui affiche les réponses du problème. Le brief des rédacteurs devrait les nommer d'emblée.
- `hint` et `blank` ne sont acceptés que dans `practice` : des rédacteurs les ont mis dans les exercices notés, et le schéma les a refusés.
- Une fausse alerte de relecture (des clés `blank` dites absentes) : le contrôle des `___` a été ajouté au script de l'orchestrateur.

## Ce qu'on a appris sur la codebase

- Deux tests lisaient les leçons v1 de `docs/contenus/lecons-traitees/tle-d/` (`ContentTreeWriterCharacterizationTest`, `RichTextSanitizerTest`) : remplacer `mathematiques/limites-et-continuite.json` par sa version v3 les a cassés. Les 4 fichiers v1 qu'ils lisent sont figés dans `test/fixtures/files/lecons_v1/tle-d/`, pour que les vagues suivantes (Physique-Chimie, SVT de Tle D) ne les cassent plus.

- `valider.rb` normalise déjà « −4 » et « -4 » : les donner tous deux est refusé (`duplicate_accepted`).
- `script/contenus/valider.rb` ne contrôle pas `practice` : les règles de « Je m'entraîne » sont dans `Entities::Catalog::NotionPractice` et le test d'intégration des mathématiques de 3e.

## À faire valider par un enseignant

| Leçon | Point à valider |
|---|---|
| Nombres complexes (C, D) | racines n-ièmes absentes ; linéarisation (Euler) non traitée ; racine carrée d'un complexe non réel et équations à coefficients complexes au programme de D leçon 8 ? affixe de vecteur, milieu, distance en leçon 8 ou 10 (D) ? problème 4 D (courant alternatif, i au lieu de j, module = valeur maximale). |
| Exponentielles (C, D) | fonctions puissances x^α au programme ; lim (e^x−1)/x = 1 citée ; primitive en D sans intégrale ; modèle logistique en bac C. |
| Primitives (C, D) | formes u'/u², u'/√u en D ; cos(ax+b) par formule directe ; distance par différence de positions avant le calcul intégral ; niveau bac (1 question rédigée en C, 0 en D). |
| Limites (C, D) | gendarmes avec cos x / x ; sin x / x et prolongement par continuité écartés ; dérivée donnée dans des problèmes ; forme de la définition de l'asymptote oblique. |
| Logarithmes (C, D) | ln(−u) au lieu de ln/u/ ; log de base a ; puissances entières 1,05^n avant les suites. |
| Dérivabilité (C, D) | inégalité des accroissements finis absente ; dérivée de la réciproque au programme de D ? fonctions trigonométriques évitées. |
| Limites (C, D) | théorème de la bijection avec signe de f' avant la leçon Dérivabilité ; asymptote oblique et théorème de la bijection dans Limites plutôt que Dérivabilité ? |
| Logarithmes (C, D) | capital C0·q^n (suite géométrique donnée toute faite avant la leçon Suites en D) ; logarithme de base a ; primitive de ln en bac C. |
| Dérivabilité (C, D) | dérivée de la bijection réciproque en D ; niveau bac du problème 4 D ; « branche parabolique de direction y = x » employé ? |
| Divisibilité (C) | nombres premiers et décomposition absents ; ax + by = c, ax ≡ b [n], restes de puissances dans cette leçon ? forme du bac C (QCM vs rédaction) ; balance à poids relatifs. |
| Barycentre (C) | réductions de αMA²+βMB² et MA·MB, Apollonius via (A,1),(B,−k²) ; droite de niveau u·AM = c avec Apollonius ; distance point-droite écartée ; niveau du bac C. |
| Géométrie de l'espace (C) | produit vectoriel absent ; distance point-plan par formule ; distance point-droite, sphères, angles non traités ; barèmes du bac C. |
| Coniques (C) | tangentes absentes ; changement d'origine et complétion des carrés au programme ? directrices x = ±a²/c ; ellipse d'axe focal Oy et x² = 2py seulement mentionnées. |
| Barycentre (C) | cas σ = 0 (MA² − MB² = k) attendu ? vocabulaire « droite de niveau », « cercle d'Apollonius ». Divisibilité : formulation du critère par 11 ; inverse modulo n au programme ? |
| Géométrie de l'espace (C) | produit vectoriel, distance point-droite et sphère absents ; niveau bac du problème 4. |
| Coniques (C) | problèmes 3-4 sans question rédigée (« montrer que… ») acceptable au bac ? complétion des carrés et directrices de l'hyperbole au programme ? |
| Probabilité (D) | fonction de répartition non traitée ; loi binomiale B(n ; p) et V(X) = Σp x² − E(X)² ; Bayes non nommée ; tolérances d'arrondi ; niveau bac D du problème 4. |
| Suites (D) | somme géométrique, comparaison, gendarmes, passage à la limite u_{n+1}=f(u_n) au programme ? niveaux des problèmes 3 et 4 proches ; notation décimale « 5,25 ». |
| Calcul intégral (D) | volume de révolution non traité ; intégrales de t·e^(−t), x·ln x, x·sin x en Tle D ? q′ admise au problème 4 ; barème de la question rédigée ; dette : tracé de courbe. |
| Suites (D) | récurrence au programme de Tle D ou réservée à C ? passage à la limite et « monotone bornée ⇒ convergente » exigibles ou admis ? définition de la convergence intuitive ou « à partir d'un certain rang » ? |
| Complexes et géométrie (D) | similitudes directes non traitées ; ensembles (z−a)/(z−b) réel/imaginaire pur en D ? caractérisation équilatéral e^{±iπ/3} ; niveau et barème du problème 4. |
| Probabilité (D) | notation P_A(B) ou P(B/A) des manuels ivoiriens ? E(X)=np et V(X)=np(1−p) exigibles ? |
| Calcul intégral (D) | intégration par parties et inégalité de la moyenne au programme de D ? primitives de sin et cos acquises (∫ x sin x) ? problème 4 bac : 6 QCM sur 7, assez ? |
| Complexes et géométrie (D) | arg(z−a)=θ et /z−a/ ≤ r au programme de D ? notation e^{iθ} acquise à la leçon 8 ? |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Sorte de figure « courbe de fonction » (`coordinate_plane` ne trace que points, segments, droites) | Pas de code dans la vague | À ouvrir (figures mathématiques du lycée) |
| Sorte « tableau de variations » et « tableau de loi » | Idem | Idem |
| Sorte « solide / repère de l'espace » : Géométrie analytique de l'espace et Primitives sont sans figure | Idem | Idem |
| Sorte « conique » (ellipse, hyperbole, parabole tracées) | Idem | Idem |
