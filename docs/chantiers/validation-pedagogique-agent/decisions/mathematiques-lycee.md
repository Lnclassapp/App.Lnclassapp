# Décisions du validateur pédagogique — Mathématiques, lycée (2nde à Terminale)

Sources abrégées :
- **TA** : `docs/chantiers/contenus-tle-mathematiques-a/journal.md` § À faire valider (repris dans `contenus-v3-tous-niveaux/journal.md`, vague T2)
- **TCD** : `docs/chantiers/contenus-tle-mathematiques-cd/journal.md` § À faire valider (repris dans `contenus-v3-tous-niveaux/journal.md`, vague T1)
- **1A** : `docs/chantiers/contenus-1ere-mathematiques-a/journal.md` § À faire valider et `contenus-v3-tous-niveaux/journal.md`, vague P2
- **1CD** : `docs/chantiers/contenus-1ere-mathematiques-cd/journal.md` § À faire valider et `contenus-v3-tous-niveaux/journal.md`, vague P1
- **D12** : `docs/chantiers/lecons-1ere-2nde-debut/journal.md` (§ À trancher, § 2nde, § Vague 2 Mathématiques)
- **D45** : `docs/chantiers/lecons-2nde-4-5/journal.md` § À trancher › Mathématiques
- **TH** : `docs/chantiers/lecons-tle-{c,d,a1,a2}-comme-thales/journal.md` § À trancher
- **RM** : `docs/contenus/README.md`, listes « À faire valider » des sections Tle C, Tle D et Tle A/C/D

Chemins de leçon relatifs à `docs/contenus/lecons-traitees/`. Calculs refaits avec sympy.

| Source | Leçon (fichier) | Point | Décision | Justification |
|---|---|---|---|---|
| TA | `tle-a1/…/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json`, `tle-a2/…` (idem) | f′ = (ad − bc)/(cx + d)² sans démonstration | Confirmé | Formule exacte (sympy) ; en série A, la formule donnée suffit. |
| TA | idem | Signe et factorisation du trinôme supposés acquis | Confirmé | Acquis de 1ère A, leçon 1 (notion « Signe d'un trinôme et inéquations du second degré »). |
| TA | idem | Limites à gauche et à droite | Confirmé | Notation x → x₀⁻ / x₀⁺ définie correctement dans la notion « Valeur interdite et asymptote verticale ». |
| TA | `tle-a2/…/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Extremums d'un polynôme de degré 3 en A2 | Confirmé | Acquis de 1ère A, leçon 4 (notion « Étudier un polynôme de degré 2 ou 3 »). |
| TA | `tle-a1/…/probabilite-et-variable-aleatoire.json` | Variance et écart-type absents | Confirmé | Absence sans erreur : l'espérance suffit au jeu équitable. |
| TA | idem | Espérance du gain algébrique, « jeu équitable si E(X) = 0 » | Confirmé | Définition usuelle ; exemple de la fiche : (1/6)×500 + (5/6)×(−100) = 0 (sympy). |
| TA | idem | Niveau et barème du problème 4 | Confirmé | Deux rédigées de 3 et 2 points, 3 critères chacune : conforme à `prompt-redaction.md`. |
| TA | `tle-a1/…/primitives-et-calcul-integral.json` | Primitive de 1/x² et valeur moyenne non traitées | Confirmé | Absence sans erreur. |
| TA | idem | Aire avec deux unités différentes | Confirmé | 1 u.a. = 10 m × 5 m = 50 m² ; conversions justes. |
| TA | idem | Signe du trinôme par Δ ; barèmes | Confirmé | Δ acquis en 1ère A ; rédigées de 2 à 4 points, 3 à 5 critères. |
| TA | `tle-a1/…/fonction-logarithme-neperien.json`, `tle-a2/…` | Définition de ln (A1 : primitive de 1/x ; A2 : admise) | Confirmé | En A1, Primitives (leçon 3) précède ln (leçon 4) ; l'A2 n'a pas de leçon Primitives. |
| TA | idem | Limites en 0⁺ et +∞ | Confirmé | −∞ et +∞ : exactes. |
| TA | idem | e² cité avant la leçon exp | Confirmé | e est défini dans la leçon (ln e = 1) ; e² n'en est qu'une puissance, ln(e²) = 2. |
| TA | `tle-a2/…/fonction-logarithme-neperien.json` | (ln u)′ en A2 | Confirmé | Formule exacte ; dérivation acquise en 1ère A (leçon 4). |
| TA | idem (A1, A2) | ln 2 ≈ 0,7 ou 0,69 ; ln 3 ≈ 1,1 ; ln 10 ≈ 2,3 | Confirmé | 0,693 ; 1,099 ; 2,303. Avec ces arrondis, chaque seuil entier n trouvé (4, 5, 7, 4, 5) est celui des valeurs exactes. |
| TA | idem | Problème bac x − ln x | Confirmé | (x − ln x)′ = 1 − 1/x, minimum 1 en x = 1. |
| TA | `tle-a1/…/fonction-exponentielle-neperienne.json`, `tle-a2/…` | Limites en ±∞ | Confirmé | +∞ et 0 : exactes. |
| TA | idem | (e^u)′ avec u polynôme | Confirmé | Exemple (e^{x²−4x})′ = (2x − 4)e^{x²−4x} exact. |
| TA | idem | Inéquations e^x ≥ k | Confirmé | Cas k ≤ 0 traité (toujours vraie / aucune solution). |
| TA | idem | Modèle N₀e^{kt} | Confirmé | Doublement : t = ln 2 / 0,35 ≈ 1,98 ≈ 2 h ; « modèle » présenté comme exemple. |
| TA | idem | Aucune figure | Confirmé | Dette technique (sorte « courbe »), pas une erreur de contenu. |
| TA | `tle-a1/…/statistique-a-deux-variables.json`, `tle-a2/…` | Moindres carrés, covariance, corrélation non traités | Confirmé | Absence sans erreur ; Mayer suffit à l'ajustement en série A. |
| TA | idem | Mayer réservée aux effectifs pairs | Corrigé | La méthode s'applique aussi à un effectif impair (groupes de tailles voisines) : la fiche disait le contraire et une question tenait « impossible avec 7 points » pour juste. Fiche : « dans cette leçon, n est pair » ; question remplacée (8 points → 4 par groupe). |
| TA | idem | Vocabulaire interpolation / prévision | Confirmé | Estimation dans l'intervalle observé, prévision hors de lui : usage exact et constant. |
| TA | `tle-a1/…/suites-numeriques.json`, `tle-a2/…` | Somme géométrique au programme A | Confirmé | Déjà en 1ère A, leçon 5 (notion « Calculer une somme de termes consécutifs »). |
| TA | idem | uₙ₊₁ = a·uₙ + b et limite d'une suite géométrique non traitées | Confirmé | Absence sans erreur. |
| TA | `tle-a1/…/systemes-d-equations-lineaires-dans.json`, `tle-a2/…` | Changement d'inconnue X = ln x, Y = ln y | Confirmé | ln est acquis (A1 leçon 4, A2 leçon 3, avant Systèmes) ; X = 1, Y = 2 donne x = e, y = e². |
| TA | idem | Niveau de calcul du problème bac | Confirmé | Systèmes 2 × 2 à coefficients entiers, rédigées de 3 points. |
| TA | `tle-a2/…/probabilite.json` | « 2 parmi n » = n(n − 1)/2 sans C(n, p) | Corrigé | Formule exacte, mais la fiche appelait « combinaison simple » un groupe de 2 seulement : reformulé en « groupe de 2 éléments (une combinaison de 2 éléments) ». |
| TA | idem | Arbre qui mêle hasard et choix | Confirmé | L'arbre sert ici à dénombrer (chaque niveau = un choix), pas à pondérer des probabilités. |
| TA | idem | Niveau bac du problème 4 | Confirmé | Équiprobabilité, contraire, réunion : attendus de la série A2. |
| TCD | `tle-c/…/nombres-complexes.json`, `tle-d/…/nombres-complexes.json` | Racines n-ièmes absentes ; linéarisation non traitée | Confirmé | Absences sans erreur ; Moivre et Euler traités pour les puissances. |
| TCD | `tle-d/…/nombres-complexes.json` | Racine carrée d'un complexe non réel, équations à coefficients complexes en D (leçon 8) | Confirmé | Contenu de la leçon « Nombres complexes » des Tle C et D ; méthode x² − y² = p, 2xy = q, x² + y² = \|Δ\| exacte. |
| TCD | idem | Affixe de vecteur, milieu, distance en leçon 8 | Confirmé | Bases de la leçon 8, réemployées en leçon 10. |
| TCD | `tle-d/…/nombres-complexes-et-geometrie-du-plan.json` | Problème courant alternatif : i au lieu de j, module = valeur maximale | Confirmé | Leçon de maths, notation i ; l'énoncé pose que le module est la valeur maximale (amplitude). I = 50/(3 + 4i) = 6 − 8i, \|I\| = 10 (sympy). |
| TCD | `tle-c/…/fonctions-exponentielles-et-fonctions-puissances.json`, `tle-d/…/fonctions-exponentielles-et-puissances.json` | Fonctions puissances x^α au programme | Confirmé | Dans l'intitulé DPFC de la leçon (C9, D6). |
| TCD | idem | lim (e^x − 1)/x = 1 citée | Confirmé | Exacte, justifiée dans la fiche comme nombre dérivé de exp en 0. |
| TCD | `tle-d/…/fonctions-exponentielles-et-puissances.json` | Primitive en D sans intégrale | Confirmé | Primitives (D4) précède Exponentielles (D6) ; le calcul intégral vient en D9. |
| TCD | `tle-c/…/fonctions-exponentielles-et-fonctions-puissances.json` | Modèle logistique en bac C | Confirmé | Le fichier actuel n'a plus de modèle logistique. |
| TCD | `tle-c/…/primitives.json`, `tle-d/…/primitives.json` | Formes u′/u², u′/√u en D | Confirmé | Formes usuelles du tableau des primitives. |
| TCD | idem | cos(ax + b) par formule directe | Confirmé | Primitive (1/a)·sin(ax + b) exacte. |
| TCD | `tle-d/…/primitives.json` | Distance par différence de positions avant le calcul intégral | Confirmé | v(t) = 12t² − 6t + 30 > 0 (Δ < 0) : la différence des positions est bien la distance ; d(2) = 80 km. |
| TCD | idem (C, D) | Niveau bac : 1 rédigée en C, 0 en D | Confirmé | `prompt-redaction.md` : en Mathématiques, les rédigées restent rares. |
| TCD | `tle-c/…/limites-et-continuite.json`, `tle-d/…` | Gendarmes avec cos x / x | Confirmé | \|cos x\| ≤ 1 acquis de 1ère (Angles orientés et trigonométrie). |
| TCD | idem | sin x / x et prolongement par continuité écartés | Confirmé | Absences sans erreur. |
| TCD | idem | Dérivée donnée dans des problèmes | Confirmé | Dérivabilité vient après Limites (C4, D3) : donner f′ évite d'anticiper. |
| TCD | idem | Forme de la définition de l'asymptote oblique | Confirmé | lim (f(x) − (ax + b)) = 0, a ≠ 0 : définition usuelle. |
| TCD | idem | Théorème de la bijection avec le signe de f′ avant Dérivabilité | Confirmé | Signe de f′ et variations acquis en 1ère (Dérivation, C9 / D6). |
| TCD | idem | Asymptote oblique et bijection dans Limites plutôt que Dérivabilité | Confirmé | Continuité et valeurs intermédiaires sont l'objet de « Limites et continuité » : rattachement cohérent. |
| TCD | `tle-c/…/fonctions-logarithmes.json`, `tle-d/…` | ln(−u) au lieu de ln\|u\| | Confirmé | La fiche donne ln\|u\|, puis ln(−u) si u < 0 : égalité exacte. |
| TCD | idem | Logarithme de base a | Confirmé | Seul le logarithme décimal est traité ; absence sans erreur. |
| TCD | `tle-c/…/fonctions-logarithmes.json` | Puissances entières 1,05^n avant les suites | Confirmé | Puissances acquises du collège ; C(n) = 100 000 × 1,05^n est donné dans l'énoncé. |
| TCD | `tle-d/…/fonctions-logarithmes.json` | Capital C₀·qⁿ avant la leçon Suites en D | Confirmé | Formule donnée toute faite (50 000 × 1,06^n) ; aucune notion de suite requise. |
| TCD | `tle-c/…/fonctions-logarithmes.json` | Primitive de ln en bac C | Confirmé | Primitives (C6) précède Logarithmes (C7) ; contrôle par dérivation. |
| TCD | `tle-c/…/derivabilite-et-etude-de-fonctions.json`, `tle-d/…` | Inégalité des accroissements finis absente | Confirmé | Absence sans erreur. |
| TCD | `tle-d/…/derivabilite-et-etude-de-fonctions.json` | Dérivée de la bijection réciproque en D | Confirmé | (f⁻¹)′(y₀) = 1/f′(f⁻¹(y₀)) si f′ ≠ 0, tangente verticale sinon : exact. |
| TCD | idem (C, D) | Fonctions trigonométriques évitées | Confirmé | Choix de périmètre sans erreur. |
| TCD | `tle-d/…/derivabilite-et-etude-de-fonctions.json` | Niveau bac du problème 4 D | Confirmé | Étude complète d'une fonction rationnelle, une rédigée de 2 points. |
| TCD | `tle-c/…/derivabilite-et-etude-de-fonctions.json` | « Branche parabolique de direction y = x » | Confirmé | Vocabulaire usuel ; x + √x : quotient → 1 et différence → +∞ (sympy). |
| TCD | `tle-c/…/divisibilite-dans.json` | Nombres premiers et décomposition absents | Confirmé | Absence sans erreur. |
| TCD | idem | ax + by = c, ax ≡ b [n], restes de puissances dans cette leçon | Confirmé | Seule leçon d'arithmétique des 10 premières de Tle C. |
| TCD | idem | Forme du bac C (QCM ou rédaction) | Confirmé | Règle Lnclass : au moins la moitié corrigée automatiquement. |
| TCD | idem | Balance à poids relatifs | Confirmé | PGCD(391 ; 136) = 17 divise 34 ; la convention « négatif = autre plateau » est écrite. |
| TCD | idem | Formulation du critère par 11 | Confirmé | Somme alternée des chiffres depuis la droite : exact. 4 713 ≡ 5, 10^2025 ≡ 10 [11], 52c4 divisible pour c = 1. |
| TCD | idem | Inverse modulo n au programme | Confirmé | Non enseigné dans la fiche ; absence sans erreur. |
| TCD | `tle-c/…/barycentre-et-lignes-de-niveaux.json` | Réductions αMA² + βMB², MA·MB ; Apollonius via (A,1), (B,−k²) | Confirmé | Relation MA² − k²MB² = (1 − k²)MG² + GA² − k²GB² vérifiée (sympy). |
| TCD | idem | Droite de niveau u·AM = c | Confirmé | Droite perpendiculaire à u, équation a(x − x_A) + b(y − y_A) = c exacte. |
| TCD | idem | Distance point-droite écartée ; niveau du bac C | Confirmé | Absence sans erreur ; une rédigée de 3 points. |
| TCD | idem | Cas σ = 0 (MA² − MB² = k) | Confirmé | La fiche traite la somme nulle : pas de barycentre, vecteur constant. |
| TCD | idem | Vocabulaire « droite de niveau », « cercle d'Apollonius » | Confirmé | Intitulé DPFC « Barycentre et lignes de niveaux ». |
| TCD | `tle-c/…/geometrie-analytique-de-l-espace.json` | Produit vectoriel, distance point-droite, sphères, angles absents | Confirmé | Absences sans erreur. |
| TCD | idem | Distance point-plan par formule | Confirmé | \|ax₀ + by₀ + cz₀ + d\| / √(a² + b² + c²) : exacte. |
| TCD | idem | Barèmes et niveau du problème 4 | Confirmé | Deux rédigées de 3 et 2 points, 3 à 4 critères. |
| TCD | `tle-c/…/coniques.json` | Tangentes absentes | Confirmé | Absence sans erreur. |
| TCD | idem | Changement d'origine et complétion des carrés | Confirmé | Méthode juste : (x − 2)²/16 − (y + 1)²/9 = 1 donne c = 5, foyers (7 ; −1) et (−3 ; −1). |
| TCD | idem | Directrices x = ±a²/c | Confirmé | Formule exacte ; ex. x = 2 + 16/5 = 5,2 ; ellipse foyer (1 ; 0), directrice x = 4, e = 1/2 donne 3x² + 4y² = 12. |
| TCD | idem | Ellipse d'axe focal Oy et x² = 2py seulement mentionnées | Confirmé | Choix de périmètre sans erreur. |
| TCD | idem | Problèmes 3-4 sans question rédigée | Confirmé | Le problème 4 a une rédigée de 3 points ; règle « rédigées rares » respectée. |
| TCD | `tle-d/…/probabilite-conditionnelle-et-variable-aleatoire.json` | Fonction de répartition non traitée ; Bayes non nommée | Confirmé | Absences sans erreur. |
| TCD | idem | V(X) = Σpᵢxᵢ² − E(X)² | Confirmé | Formule de König-Huygens ; exemple 1,3 − 0,49 = 0,81. |
| TCD | idem | E(X) = np, V(X) = np(1 − p) | Confirmé | Exacts pour la loi binomiale. |
| TCD | idem | Tolérances d'arrondi ; niveau bac D du problème 4 | Confirmé | `valider.rb` sans erreur ; deux rédigées de 2 points. |
| TCD | idem | Notation P_A(B) ou P(B/A) | Corrigé | Les deux notations ont cours : la fiche ajoute « on la note aussi P(B/A) ». |
| TCD | `tle-d/…/suites-numeriques.json` | Somme géométrique, comparaison, gendarmes, passage à la limite | Confirmé | Contenu juste, attendu en Tle D. |
| TCD | idem | Niveaux des problèmes 3 et 4 proches | Confirmé | Les deux restent au niveau de la série. |
| TCD | idem | Notation décimale « 5,25 » | Confirmé | c₁ = 0,75 × 3 + 3 = 5,25 ; virgule décimale française. |
| TCD | idem | Récurrence en Tle D | Confirmé | Raisonnement attendu au bac D ivoirien sur les suites. |
| TCD | idem | « Monotone bornée ⇒ convergente » ; définition de la convergence | Confirmé | Énoncé exact ; définition « à partir d'un certain rang » juste. |
| TCD | `tle-d/…/calcul-integral.json` | Volume de révolution non traité | Confirmé | Absence sans erreur. |
| TCD | idem | t·e^(−t), x·ln x, x·sin x ; intégration par parties ; primitives de sin et cos | Confirmé | IPP au programme de la leçon ; primitives de sin et cos acquises (Primitives, D4). |
| TCD | idem | q′ admise au problème 4 ; barème de la rédigée ; 6 QCM sur 7 | Confirmé | Rédigée de 3 points, 3 critères ; règle « au moins la moitié automatique ». |
| TCD | idem | Inégalité de la moyenne | Confirmé | Absente ou citée sans erreur. |
| TCD | `tle-d/…/nombres-complexes-et-geometrie-du-plan.json` | Similitudes directes non traitées | Confirmé | Elles relèvent de la série C. |
| TCD | idem | Ensembles (z − a)/(z − b) réel / imaginaire pur | Confirmé | Contenu juste (alignement, angle droit). |
| TCD | idem | Caractérisation de l'équilatéral par e^{±iπ/3} | Confirmé | Exacte ; exemple vérifié : AB = AC = BC = 2. |
| TCD | idem | arg(z − a) = θ et \|z − a\| ≤ r | Confirmé | Demi-droite privée de A, disque fermé : exacts. |
| TCD | idem | Notation e^{iθ} acquise à la leçon 8 | Confirmé | Notion « Passer à la forme trigonométrique et exponentielle » de la leçon 8. |
| TCD | idem | Niveau et barème du problème 4 | Confirmé | Rédigées de 3 points, 3 critères. |
| RM (Tle D, v1) | `tle-d/…/limites-et-continuite.json`, `…/derivabilite-et-etude-de-fonctions.json` | Asymptotes non traitées ; IAF et dérivées successives absentes ; explications de plus de 400 caractères | Confirmé | Les v1 sont remplacées par les v3 : asymptotes traitées (Limites), IAF absente sans erreur, `valider.rb` sans erreur. |
| RM (Tle C, v1) | `tle-c/…/barycentre-et-lignes-de-niveaux.json` | Leibniz et Apollonius : place dans la leçon | Confirmé | Ce sont les lignes de niveau de l'intitulé DPFC. |
| RM (Tle C, v1) | `tle-c/…/divisibilite-dans.json` | Euclide : b non nul, dernier reste non nul | Confirmé | La fiche pose deux entiers non nuls ; PGCD = dernier reste non nul. |
| 1A | `1ere-a1/…/equations-et-inequations.json`, `1ere-a2/…` | Second degré au programme de 1ère A | Confirmé | Contenu de la leçon 1 de 1ère A ; formules exactes. |
| 1A | idem | Somme/produit, bicarrées, quotients, valeur absolue non traités | Confirmé | Absences sans erreur. |
| 1A | `1ere-a1/…/denombrement.json`, `1ere-a2/…` | Arrangements, combinaisons, C_n^p, 0! = 1 | Confirmé | Définitions et convention exactes ; réemployées en Tle A1 (probabilités). |
| 1A | idem | Niveau de C₁₂³ et du complémentaire | Confirmé | C₁₂³ = 220 (sympy) ; calcul faisable à la main. |
| 1A | `1ere-a1/…/generalites-sur-les-fonctions.json`, `1ere-a2/…` | Périodicité absente ; composée ; domaine d'un quotient | Confirmé | Parité et composée traitées ; absence de périodicité sans erreur. |
| 1A | idem | Sens de variation par f(b) − f(a) | Confirmé | La dérivation vient en leçon 4 : méthode adaptée. |
| 1A | `1ere-a1/…/derivabilite-et-etude-de-fonctions.json`, `1ere-a2/…` | Nombre dérivé sans notation de limite ; dérivées usuelles limitées ; degré 3 et Δ ; modèles fictifs | Confirmé | Définition par le taux d'accroissement exacte ; périmètre adapté à la série A ; modèles marqués fictifs. |
| 1A | `1ere-a1/…/suites-numeriques.json`, `1ere-a2/…` | Sommes arithmétique/géométrique ; convention u₀ ; données fictives | Confirmé | Formules exactes (N = n + 1 termes de u₀ à uₙ). |
| 1A | `a-reprendre/sujets-manquants/1ere-a1/mathematiques/statistique.json` (A1, A2) | Variance, écart type, médiane, effectifs cumulés | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1A | `a-reprendre/sujets-manquants/1ere-a1/mathematiques/systemes-d-equations-dans.json` (A1, A2) | Inéquations à deux inconnues ; déterminant sans Cramer | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `1ere-c/…/equations-et-inequations-dans.json` | Valeur absolue, systèmes, équations irrationnelles non traités | Confirmé | La leçon traite désormais les équations se ramenant au second degré ; les autres absences sont sans erreur. |
| 1CD | `1ere-d/…/equations-et-inequations-du-second-degre-dans.json` | Bicarrées et fractions absentes en D | Confirmé | Absence sans erreur. |
| 1CD | `1ere-c/…/angles-orientes-et-trigonometrie.json`, `1ere-d/…` | Formules d'addition, de duplication, équations trigonométriques | Confirmé | Traitées (notion 4) ; formules exactes. |
| 1CD | `1ere-c/…/generalites-sur-les-fonctions.json`, `1ere-d/…` | Périodicité, composée, fonctions majorée/minorée | Confirmé | Périodicité et composée traitées ; le reste absent sans erreur. |
| 1CD | `1ere-c/…/barycentre.json` | Découpage en cinq notions ; coefficients négatifs | Confirmé | Contenu juste ; somme nulle traitée (pas de barycentre). |
| 1CD | `a-reprendre/sujets-manquants/1ere-d/mathematiques/barycentre.json` | Coefficients négatifs et somme nulle en D | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `1ere-c/…/limites-et-continuite.json`, `1ere-d/…` | Partage avec « Extension » ; TVI et prolongement absents | Confirmé | Absences sans erreur ; la suite de la notion relève de la leçon « Extension ». |
| 1CD | `1ere-d/…/denombrement.json` | Binôme, Pascal, 2ⁿ absents ; 0! = 1 | Confirmé | Convention exacte ; absences sans erreur. |
| 1CD | `a-reprendre/sujets-manquants/1ere-c/mathematiques/denombrement.json` | Même point en C | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-c/…/extension-de-la-notion-de-limite.json`, `1ere-d/…` | Asymptote oblique ; irrationnelles et quantité conjuguée | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-c/…/composees-de-transformations-du-plan.json` | Rotations et homothéties de même centre ; aires en k² | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-c/…/derivation.json`, `1ere-d/…` | Composée absente ; √x en 0 ; dérivée seconde | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-c/…/orthogonalite-de-l-espace.json` | Trois perpendiculaires ; distances ; figure en perspective | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-d/…/etude-et-representation-graphique-d-une-fonction.json` | Asymptote oblique ; modèles agronomiques fictifs | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD | `a-reprendre/sujets-manquants/1ere-d/…/probabilite.json` | Probabilité conditionnelle, loi binomiale ; card(A), C_n^p | Hors base | Leçon dans a-reprendre, le validateur passera à son retour (processus). |
| 1CD (P1) | 1ère C et D, toutes | Figures de courbes, tableaux, arbres, solides absentes ; modèles fictifs ; barèmes | Confirmé | Dette technique, pas une erreur ; rédigées de 2 à 4 points, 2 à 5 critères. |
| D12 | `1ere-c/…/angles-orientes-et-trigonometrie.json`, `1ere-d/…` | Sens des aiguilles d'une montre = sens indirect | Confirmé | Sens direct = sens inverse des aiguilles ; exemples cohérents (4 h : −120°, mesure principale π/2 à 9 h). |
| D12 | 1ère, sujets 3 et 4 | Questions rédigées, barème | Confirmé | 2 à 4 points, 2 à 5 critères : conforme à `prompt-redaction.md`. |
| D12 | `1ere-c/…/generalites-sur-les-fonctions.json`, `1ere-d/…` | Variations par le signe de f(b) − f(a), sans dérivée | Confirmé | Dérivation vient plus tard (C9, D6) : méthode adaptée. |
| D12 | `1ere-c/…/barycentre.json` (notion 4), `1ere-c/…/limites-et-continuite.json` et `1ere-d/…` (notions 1 et 3) | « Je m'entraîne » d'un seul type (`numeric`) | Corrigé | La 3e question devient un QCM à leurres expliqués : deux types par bloc, comme le demande la règle. |
| D12 | `1ere-d/…/denombrement.json` | Formules d'origine de 41 à 49 caractères non coupées | Confirmé | Rendu à 390 px vert (journal) ; sans effet sur le fond. |
| D12 | `1ere-a1/…/suites-numeriques.json`, `1ere-a2/…` | Décompte « dernier rang − premier rang + 1 » | Confirmé | Exact. |
| D12 | idem | Un sujet commence au mois 1 au lieu de u₀ | Confirmé | Le premier rang est écrit dans l'énoncé ; somme de u₁ à u₁₀ = 55 000 (sympy). |
| D12 | 1ère et 2nde, toutes | Contextes ivoiriens et chiffres fictifs | Confirmé | Données d'énoncé, présentées comme modèles ou exemples. |
| D12 | `2nde-a/…/calcul-numerique.json`, `…/denombrement.json` | Racines carrées simples, tableau à double entrée, diagramme ; produits sans factorielle ; card(A) ; unités en `numeric` | Confirmé | Contenus justes et de niveau 2nde A. |
| D12 | `2nde-a/…/calcul-numerique.json` | Distracteur 2√16 | Corrigé | Leurre bien faux (2√16 = 8 = √64 ≠ √32), mais non expliqué dans « Je m'entraîne » : corrigé complété. |
| D12 | 2nde C, Mathématiques | Thème de couleur | Confirmé | Choix d'affichage, sans effet sur le fond. |
| D12 | `2nde-c/…/utilisation-des-symetries-et-translations.json`, `…/vecteurs-et-points-du-plan.json`, `…/ensemble-des-nombres-reels.json` | Symétrie axiale limitée aux axes ; composition exclue ; colinéarité, déterminant, valeur absolue, encadrements | Confirmé | Périmètres justes et sans notion des leçons suivantes. |
| D45 | `2nde-a/…/equations-et-inequations-dans.json` | Tableau de signes d'un quotient et d'un produit de 3 facteurs ; S = ∅ ou ℝ ; réunion d'intervalles ; produits sans Δ | Confirmé | Règles exactes ; le discriminant n'est pas au programme de 2nde. |
| D45 | `2nde-a/…/generalites-sur-les-fonctions.json` | « Croissante » sans inégalité formelle | Confirmé | Définition par lecture (« la courbe monte ») juste et adaptée à la 2nde A. |
| D45 | idem | Factorisation donnée 2x² − 3x − 2 = (2x + 1)(x − 2) ; équation à quotient ; racine, valeur absolue, parité absentes ; variations sur 7 points | Confirmé | Factorisation exacte (sympy) ; absences sans erreur. |
| D45 | `2nde-c/…/generalites-sur-les-fonctions.json` | Sens de variation par f(b) − f(a) sans taux de variation | Confirmé | Méthode exacte. |
| D45 | idem | Trinômes factorisés x² − 6x + 5, x² − 4x + 3 proches de la leçon 6 | Confirmé | Seuls f(b) − f(a) et l'équation produit (acquis de 3ème) servent ; rien de la leçon 6. |
| D45 | idem | Parité, égalité de fonctions, résolutions graphiques non traitées | Confirmé | Absences sans erreur. |
| D45 | idem | Modèles fictifs hors contexte (antécédent −3 pour des spectateurs) | Corrigé | Trois énoncés donnaient un sens concret à des valeurs absurdes (spectateurs, heures d'entraînement, points d'un joueur sur ℝ) : contexte retiré, fonction étudiée pour elle-même. |
| D45 | idem | Différence de buts par journée tracée en ligne continue | Corrigé | Une grandeur par journée n'existe pas entre deux journées (« négative entre les journées 1 et 3 », « image de 7 au milieu de [DE] ») : remplacée par la température d'une chambre froide en fonction du temps, grandeur continue ; mêmes points et réponses. |
| D45 | `2nde-c/…/droites-et-plans-de-l-espace.json` | Théorème du toit et critère de parallélisme de deux plans | Confirmé | Énoncés exacts. |
| D45 | idem | Orthogonalité non traitée ; section hexagonale en QCM ; cube décrit sans figure | Confirmé | Une section de cube peut être un hexagone (3 à 6 côtés) ; absence sans erreur. |
| TH | Tle C, D, A1, A2, Mathématiques | Lectures graphiques sans tolérance | Confirmé | Constructions à coordonnées entières : la lecture est exacte. |
| TH | idem | Valeurs illustratives des énoncés | Confirmé | Données fictives présentées comme exemples ou modèles. |
