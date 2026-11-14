# Corrections à reporter à la main en production

> Leçons de `docs/contenus/lecons-traitees/` corrigées par le validateur pédagogique le 2026-11-14 **et présentes sur `origin/main`** (train de production). Par prudence, elles sont toutes traitées comme publiées : l'équipe ignore une leçon qu'elle n'a pas publiée. Aucune session ne touche la production : l'équipe reporte chaque correction dans l'application (lieu : notion › exercice › question, champ), au format Avant / Après.
>
> Les leçons corrigées absentes d'`origin/main` (6ème, 5ème, 4ème, une partie de 2nde et de 1ère) n'y figurent pas : elles arriveront corrigées par le train suivant.

## Mathématiques, collège (6ème à 3ème)

Seules les leçons de 3ème sont sur `origin/main` ; les leçons de 6ème, 5ème et 4ème modifiées n'y sont pas (rien à reporter pour elles). Les valeurs « Avant » ont été relues sur `origin/main`.

### 3ème · Mathématiques · Calcul littéral (`docs/contenus/lecons-traitees/3eme/mathematiques/calcul-litteral.json`)

- **Lieu** : problème 3 (« Les comptes d'un vendeur de poissons ») › question 6, champ `content`
  - Avant : « Pour $x = 0$ caisse vendue, quelle est la valeur du bénéfice $E = (3x-2)^2 - (x+4)(x-4)$ ? »
  - Après : « Pour $x = 3$ caisses vendues, quelle est la valeur du bénéfice $E = (3x-2)^2 - (x+4)(x-4)$ ? »
- **Lieu** : problème 3 (« Les comptes d'un vendeur de poissons ») › question 6, champ `explanation`
  - Avant : « Méthode. On remplace $x$ par $0$ : $(3 \times 0 - 2)^2 - (0+4)(0-4) = (-2)^2 - 4 \times (-4) = 4 + 16 = 20$. Vérification avec $E = 8x^2 - 12x + 20$ : pour $x = 0$, il reste $20$. Le carré d'un nombre négatif est positif : $(-2)^2 = 4$ et non $-4$. La réponse $-12$ vient de $4 - 16$ : elle oublie que soustraire $4 \times (-4) = -16$ revient à ajouter $16$. »
  - Après : « Méthode. On remplace $x$ par $3$ : $(3 \times 3 - 2)^2 - (3+4)(3-4) = 7^2 - 7 \times (-1) = 49 + 7 = 56$. Vérification avec $E = 8x^2 - 12x + 20$ : $8 \times 9 - 12 \times 3 + 20 = 72 - 36 + 20 = 56$. Les deux calculs donnent $56$ centaines de francs. La réponse $42$ vient de $49 - 7$ : elle oublie que soustraire $7 \times (-1) = -7$ revient à ajouter $7$ ; la réponse $49$ oublie le second produit. »
- **Lieu** : problème 3 (« Les comptes d'un vendeur de poissons ») › question 6, champ `answers` (contenu, dans l'ordre ; la bonne réponse reste la 4e)
  - Avant : « $-12$ » (faux), « $-20$ » (faux), « $12$ » (faux), « $20$ » (juste)
  - Après : « $42$ » (faux), « $-56$ » (faux), « $49$ » (faux), « $56$ » (juste)

### 3ème · Mathématiques · Propriétés de Thalès dans un triangle (`docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json`)

- **Lieu** : notion « Calculer une longueur avec la propriété de Thalès », champ `remember` (une phrase ajoutée à la fin)
  - Avant : « … Chaque rapport compare une longueur du petit triangle $ADE$ à la longueur correspondante du grand triangle $ABC$. Les longueurs des deux triangles sont proportionnelles. »
  - Après : « … Chaque rapport compare une longueur du petit triangle $ADE$ à la longueur correspondante du grand triangle $ABC$. Les longueurs des deux triangles sont proportionnelles. Le rapport $k = \frac{AD}{AB}$ est le coefficient : si $k < 1$, le triangle $ADE$ est une **réduction** du triangle $ABC$ ; si $k > 1$, c'est un **agrandissement**. »
- **Lieu** : notion « Montrer que deux droites ne sont pas parallèles », champ `remember` (une phrase ajoutée)
  - Avant : « … Donc, si $\frac{AD}{AB} \neq \frac{AE}{AC}$, les droites $(DE)$ et $(BC)$ ne sont pas parallèles. Pour comparer deux fractions sans erreur, … »
  - Après : « … Donc, si $\frac{AD}{AB} \neq \frac{AE}{AC}$, les droites $(DE)$ et $(BC)$ ne sont pas parallèles. Cette conséquence s'appelle la **contraposée** de la propriété de Thalès. Pour comparer deux fractions sans erreur, … »

### 3ème · Mathématiques · Vecteurs (`docs/contenus/lecons-traitees/3eme/mathematiques/vecteurs.json`)

- **Lieu** : notion « Reconnaître un parallélogramme avec des vecteurs », champ `remember` (première phrase)
  - Avant : « Dire que $ABCD$ est un parallélogramme (non aplati) équivaut à $\overrightarrow{AB} = \overrightarrow{DC}$. »
  - Après : « Si les points $A$, $B$ et $C$ ne sont pas alignés, dire que $ABCD$ est un parallélogramme équivaut à $\overrightarrow{AB} = \overrightarrow{DC}$. »

### 3ème · Mathématiques · Équations et inéquations dans ℝ (`docs/contenus/lecons-traitees/3eme/mathematiques/equations-et-inequations-dans-r.json`)

- **Lieu** : notion « Résoudre une inéquation du premier degré », champ `remember` (deuxième phrase)
  - Avant : « Si on multiplie ou divise par un nombre **positif**, le sens est conservé ; par un nombre **négatif**, le sens est **inversé**. »
  - Après : « Si on multiplie ou divise par un nombre **strictement positif**, le sens est conservé ; par un nombre **strictement négatif**, le sens est **inversé**. »

## Mathématiques, lycée (2nde à Terminale)

Fichiers modifiés présents sur `origin/main`. Les quatre autres fichiers modifiés (`2nde-c/mathematiques/generalites-sur-les-fonctions.json`, `1ere-c/mathematiques/barycentre.json`, `1ere-c/mathematiques/limites-et-continuite.json`, `1ere-d/mathematiques/limites-et-continuite.json`) ne sont pas sur `origin/main` : ils ne figurent pas ici.

### Tle-A1 · Mathématiques · Statistique à deux variables (`docs/contenus/lecons-traitees/tle-a1/mathematiques/statistique-a-deux-variables.json`)

- **Lieu** : notion « Ajustement affine : la méthode de Mayer », champ remember
  - Avant : « La **méthode de Mayer** s'applique à une série de $n$ points, avec $n$ pair : on range les points par $x$ croissant, on forme deux groupes de même effectif, et on calcule le point moyen $G_1$ du premier groupe et le point moyen $G_2$ du second. La **droite de Mayer** est la droite $(G_1G_2)$. Elle passe aussi par le point moyen $G$ de toute la série, qui est le milieu de $[G_1G_2]$. »
  - Après : « La **méthode de Mayer** : on range les points par $x$ croissant, on les partage en deux groupes, et on calcule le point moyen $G_1$ du premier groupe et le point moyen $G_2$ du second. Dans cette leçon, le nombre $n$ de points est pair : les deux groupes ont le même effectif $\dfrac{n}{2}$. La **droite de Mayer** est la droite $(G_1G_2)$. Elle passe aussi par le point moyen $G$ de toute la série ; avec deux groupes de même effectif, $G$ est le milieu de $[G_1G_2]$. »
- **Lieu** : sujet 3 (« Raisonner et justifier ») › exercice 2 › question 5, champ content
  - Avant : « La méthode de Mayer partage la série en deux groupes de même effectif. Avec 7 points, c'est impossible, car 7 est ___. »
  - Après : « Une série de 8 points est rangée par $x$ croissant. Avec la méthode de Mayer, chacun des deux groupes contient ___ points. »
- **Lieu** : sujet 3 (« Raisonner et justifier ») › exercice 2 › question 5, champ answers
  - Avant : « pair (faux) ; impair (juste) ; multiple de 3 (faux) »
  - Après : « 2 (faux) ; 4 (juste) ; 8 (faux) »
- **Lieu** : sujet 3 (« Raisonner et justifier ») › exercice 2 › question 5, champ explanation
  - Avant : « Étape 1 — Condition : la méthode de Mayer s'applique à une série de $n$ points avec $n$ pair, pour former deux groupes de même effectif. Étape 2 — Vérifier : 7 n'est pas divisible par 2, il est impair, donc on ne peut pas le partager en deux groupes égaux. Dire « pair » serait faux, et être multiple de 3 ne joue aucun rôle : 7 n'est d'ailleurs pas un multiple de 3. »
  - Après : « Étape 1 — Ordonner et partager : on forme deux groupes de même effectif, la première moitié et la seconde moitié des points : $8 \div 2 = 4$ points par groupe. « 8 » oublie de partager la série ; « 2 » est le nombre de groupes, pas leur effectif. »

### Tle-A2 · Mathématiques · Statistique à deux variables (`docs/contenus/lecons-traitees/tle-a2/mathematiques/statistique-a-deux-variables.json`)

Mêmes quatre corrections que la Tle-A1, aux mêmes lieux et avec les mêmes textes avant et après.

- **Lieu** : notion « Ajustement affine : la méthode de Mayer », champ remember
  - Avant : « La **méthode de Mayer** s'applique à une série de $n$ points, avec $n$ pair : on range les points par $x$ croissant, on forme deux groupes de même effectif, […] Elle passe aussi par le point moyen $G$ de toute la série, qui est le milieu de $[G_1G_2]$. »
  - Après : « La **méthode de Mayer** : on range les points par $x$ croissant, on les partage en deux groupes, […] Dans cette leçon, le nombre $n$ de points est pair : les deux groupes ont le même effectif $\dfrac{n}{2}$. […] ; avec deux groupes de même effectif, $G$ est le milieu de $[G_1G_2]$. »
- **Lieu** : sujet 3 (« Raisonner et justifier ») › exercice 2 › question 5, champs content, answers, explanation
  - Avant : « … Avec 7 points, c'est impossible, car 7 est ___. » (pair / **impair** / multiple de 3)
  - Après : « Une série de 8 points est rangée par $x$ croissant. Avec la méthode de Mayer, chacun des deux groupes contient ___ points. » (2 / **4** / 8)

### Tle-A2 · Mathématiques · Probabilité (`docs/contenus/lecons-traitees/tle-a2/mathematiques/probabilite.json`)

- **Lieu** : notion « Dénombrer les cas possibles », champ remember
  - Avant : « Une **combinaison simple** est un groupe de $2$ éléments choisis parmi $n$, **sans tenir compte de l'ordre** et sans répétition : leur nombre est […] »
  - Après : « Un **groupe de $2$ éléments** choisis parmi $n$, **sans tenir compte de l'ordre** et sans répétition (une combinaison de $2$ éléments), se compte ainsi : le nombre de ces groupes est […] »

### Tle-D · Mathématiques · Probabilité conditionnelle et variable aléatoire (`docs/contenus/lecons-traitees/tle-d/mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json`)

- **Lieu** : notion « Probabilité conditionnelle », champ remember
  - Avant : « La probabilité de $B$ sachant $A$ est $P_A(B) = \dfrac{P(A \cap B)}{P(A)}$. »
  - Après : « La probabilité de $B$ sachant $A$ est $P_A(B) = \dfrac{P(A \cap B)}{P(A)}$ (on la note aussi $P(B/A)$). »

### 2nde-A · Mathématiques · Calcul numérique (`docs/contenus/lecons-traitees/2nde-a/mathematiques/calcul-numerique.json`)

- **Lieu** : notion « Racines carrées simples » › Je m'entraîne › question 1, champ explanation
  - Avant : « Étape 3 — Calculer : $\sqrt{16} = 4$, donc $\sqrt{32} = 4\sqrt{2}$. L'écriture $16\sqrt{2}$ oublie de prendre la racine de 16. »
  - Après : « Étape 3 — Calculer : $\sqrt{16} = 4$, donc $\sqrt{32} = 4\sqrt{2}$. Les leurres : $16\sqrt{2}$ oublie de prendre la racine de 16 ; $8\sqrt{2}$ vaut $\sqrt{128}$ ; $2\sqrt{16}$ vaut $2 \times 4 = 8$, soit $\sqrt{64}$, et non $\sqrt{32}$. »

## Physique-Chimie

Fichiers modifiés présents sur `origin/main`. Pour un champ `remember` long, seule la phrase changée est citée.

### 1ere-c · Physique-Chimie · Généralités sur les composés organiques

(`docs/contenus/lecons-traitees/1ere-c/physique-chimie/generalites-sur-les-composes-organiques.json`)

- **Lieu** : notion « Reconnaître un composé organique et ses éléments », champ remember
  - Avant : « Exemples : le sucre, l'huile de cuisine, le gaz de cuisine, le bois. »
  - Après : « Exemples : le sucre (saccharose), le butane du gaz de cuisine ; l'huile de cuisine et le bois sont des mélanges de composés organiques. »

### 1ere-d · Physique-Chimie · Généralités sur les composés organiques

(`docs/contenus/lecons-traitees/1ere-d/physique-chimie/generalites-sur-les-composes-organiques.json`)

- **Lieu** : notion « Reconnaître un composé organique et ses éléments », champ remember
  - Avant : « Exemples : le sucre, l'huile de cuisine, le gaz de cuisine, le bois. »
  - Après : « Exemples : le sucre (saccharose), le butane du gaz de cuisine ; l'huile de cuisine et le bois sont des mélanges de composés organiques. »

### tle-c · Physique-Chimie · Champ magnétique

(`docs/contenus/lecons-traitees/tle-c/physique-chimie/champ-magnetique.json`)

- **Lieu** : notion « Aimants et superposition de champs », champ remember
  - Avant : « La composante horizontale du champ terrestre est $B_H \approx 2 \times 10^{-5}$ T (donnée de l'énoncé). »
  - Après : « La composante horizontale du champ terrestre $B_H$ vaut quelques $10^{-5}$ T selon le lieu : on prend la valeur donnée par l'énoncé (ici $2 \times 10^{-5}$ T). »

### tle-c · Physique-Chimie · Fabrication d'un savon

(`docs/contenus/lecons-traitees/tle-c/physique-chimie/fabrication-d-un-savon.json`)

- **Lieu** : notion « Les corps gras : les triglycérides » › exercice 2 (« Acides gras et triglycérides : formules et masses molaires ») › question 1, champ content
  - Avant : « Le beurre de karité contient surtout de l'oléine, triglycéride de l'acide oléique $\text{C}_{17}\text{H}_{33}\text{COOH}$. Laquelle de ces formules est celle de l'oléine ? »
  - Après : « Le beurre de karité contient de l'oléine, triglycéride de l'acide oléique $\text{C}_{17}\text{H}_{33}\text{COOH}$. Laquelle de ces formules est celle de l'oléine ? »
- **Lieu** : problème 2 (« Fabriquer un savon au laboratoire du lycée »), champ statement
  - Avant : « Au laboratoire d'un lycée, des élèves fabriquent un savon à partir de tristéarine (modèle du beurre de karité, riche en acide stéarique) et de soude. Masses molaires : tristéarine 890, soude 40, stéarate de sodium 306 g/mol. »
  - Après : « Au laboratoire d'un lycée, des élèves fabriquent un savon à partir de tristéarine (modèle simplifié du beurre de karité, qui contient de l'acide stéarique et de l'acide oléique) et de soude. Masses molaires : tristéarine 890, soude 40, stéarate de sodium 306 g/mol. »

### tle-d · Physique-Chimie · Fabrication d'un savon

(`docs/contenus/lecons-traitees/tle-d/physique-chimie/fabrication-d-un-savon.json`)

- **Lieu** : notion « Les corps gras : les triglycérides » › exercice 2 (« Acides gras et triglycérides : formules et masses molaires ») › question 1, champ content
  - Avant : « Le beurre de karité contient surtout de l'oléine, triglycéride de l'acide oléique $\text{C}_{17}\text{H}_{33}\text{COOH}$. Laquelle de ces formules est celle de l'oléine ? »
  - Après : « Le beurre de karité contient de l'oléine, triglycéride de l'acide oléique $\text{C}_{17}\text{H}_{33}\text{COOH}$. Laquelle de ces formules est celle de l'oléine ? »
- **Lieu** : problème 2 (« Fabriquer un savon au laboratoire du lycée »), champ statement
  - Avant : « Au laboratoire d'un lycée, des élèves fabriquent un savon à partir de tristéarine (modèle du beurre de karité, riche en acide stéarique) et de soude. Masses molaires : tristéarine 890, soude 40, stéarate de sodium 306 g/mol. »
  - Après : « Au laboratoire d'un lycée, des élèves fabriquent un savon à partir de tristéarine (modèle simplifié du beurre de karité, qui contient de l'acide stéarique et de l'acide oléique) et de soude. Masses molaires : tristéarine 890, soude 40, stéarate de sodium 306 g/mol. »


## SVT

Seuls ces six fichiers modifiés sont sur `origin/main` ; les autres leçons de SVT corrigées (1ère A1/A2, 2nde A, 2nde C, 4ème, 6ème) n'y sont pas (rien à reporter pour elles).

### 1ère D · SVT · La gamétogénèse (`docs/contenus/lecons-traitees/1ere-d/svt/la-gametogenese.json`)

- **Lieu** : notion « L'ovogenèse : de l'ovogonie à l'ovocyte II », champ remember
  - Avant : « L'**ovogenèse** est la formation des gamètes femelles dans l'**ovaire**. Elle est **discontinue** : elle commence avant la naissance, s'arrête, puis reprend à la puberté. **Avant la naissance**, les **ovogonies** ($2n$) se multiplient par mitoses ; cette multiplication est finie à la naissance. Elles deviennent des **ovocytes I** ($2n$, 2 chromatides par chromosome), dont la méiose se **bloque en prophase I**. **De la naissance à la puberté**, l'ovaire garde un stock d'ovocytes I bloqués. **À partir de la puberté**, à chaque cycle, un ovocyte I reprend sa méiose. La division I, **inégale**, donne un gros **ovocyte II** ($n$, 2 chromatides) et un petit **globule polaire**. L'ovocyte II se bloque en **métaphase II** et il est libéré à l'**ovulation**. Il n'y a pas de différenciation. »
  - Après : « L'**ovogenèse** est la formation des gamètes femelles dans l'**ovaire**. Elle est **discontinue** : elle commence avant la naissance, s'arrête, puis reprend à la puberté. **Avant la naissance**, les **ovogonies** ($2n$) se multiplient par mitoses ; cette multiplication est finie à la naissance. Elles deviennent des **ovocytes I** ($2n$, 2 chromatides par chromosome), dont la méiose se **bloque en prophase I**. **De la naissance à la puberté**, l'ovaire garde un stock d'ovocytes I bloqués. **À partir de la puberté**, à chaque cycle, un ovocyte I (un seul chez la femme, plusieurs chez la truie ou la lapine) reprend sa méiose. La division I, **inégale**, donne un gros **ovocyte II** ($n$, 2 chromatides) et un petit **globule polaire**. L'ovocyte II se bloque en **métaphase II** et il est libéré à l'**ovulation**. Il n'y a pas de différenciation. »

### 1ère C · SVT · La gamétogénèse chez les mammifères (`docs/contenus/lecons-traitees/1ere-c/svt/la-gametogenese-chez-les-mammiferes.json`)

- **Lieu** : notion « L'ovogenèse : de l'ovogonie à l'ovocyte II », champ remember
  - Avant : « L'**ovogenèse** est la formation des gamètes femelles dans l'**ovaire**. Elle est **discontinue** : elle commence avant la naissance, s'arrête à des stades précis, puis reprend à partir de la puberté. **Avant la naissance** : les **ovogonies** ($2n$) se multiplient par mitoses ; cette multiplication est terminée à la naissance. Elles grossissent et deviennent des **ovocytes I** ($2n$, chromosomes à 2 chromatides), entourés de cellules folliculaires. Leur méiose commence, puis se **bloque en prophase I**. **De la naissance à la puberté** : l'ovaire contient un stock d'ovocytes I bloqués. **À partir de la puberté**, à chaque cycle, un ovocyte I reprend la méiose. La division I, **inégale**, donne un gros **ovocyte II** ($n$, 2 chromatides), qui garde presque tout le cytoplasme, et un petit **globule polaire**. L'ovocyte II commence la division II et se bloque en **métaphase II** ; il est libéré à l'**ovulation**. Il n'y a pas de différenciation. »
  - Après : « L'**ovogenèse** est la formation des gamètes femelles dans l'**ovaire**. Elle est **discontinue** : elle commence avant la naissance, s'arrête à des stades précis, puis reprend à partir de la puberté. **Avant la naissance** : les **ovogonies** ($2n$) se multiplient par mitoses ; cette multiplication est terminée à la naissance. Elles grossissent et deviennent des **ovocytes I** ($2n$, chromosomes à 2 chromatides), entourés de cellules folliculaires. Leur méiose commence, puis se **bloque en prophase I**. **De la naissance à la puberté** : l'ovaire contient un stock d'ovocytes I bloqués. **À partir de la puberté**, à chaque cycle, un ovocyte I (un seul chez la femme, plusieurs chez la lapine ou la truie) reprend la méiose. La division I, **inégale**, donne un gros **ovocyte II** ($n$, 2 chromatides), qui garde presque tout le cytoplasme, et un petit **globule polaire**. L'ovocyte II commence la division II et se bloque en **métaphase II** ; il est libéré à l'**ovulation**. Il n'y a pas de différenciation. »
- **Lieu** : notion « L'ovogenèse : de l'ovogonie à l'ovocyte II » › exercice 1 (« Suivre l'ovogenèse dans l'ovaire ») › question 3, champ explanation
  - Avant : « Étape 1 — Situer : on place chaque état dans la vie de la femelle. La multiplication est terminée à la naissance. Les ovocytes I attendent, bloqués en prophase I, jusqu'à la puberté. À partir de la puberté, un ovocyte I par cycle reprend la méiose. »
  - Après : « Étape 1 — Situer : on place chaque état dans la vie de la femelle. La multiplication est terminée à la naissance. Les ovocytes I attendent, bloqués en prophase I, jusqu'à la puberté. À partir de la puberté, à chaque cycle, un ovocyte I (ou plusieurs, selon l'espèce) reprend la méiose. »

### Tle C · SVT · L'infection de l'organisme par le VIH (`docs/contenus/lecons-traitees/tle-c/svt/l-infection-de-l-organisme-par-le-vih.json`)

- **Lieu** : notion « Le VIH et ses cellules cibles », champ remember
  - Avant : « Le **VIH** (virus de l'immunodéficience humaine) est un **rétrovirus** : son matériel génétique est de l'**ARN** et il porte une enzyme, la **transcriptase inverse**. De l'extérieur vers l'intérieur : une **enveloppe**, qui porte les glycoprotéines **gp120** et **gp41** ; une **matrice protéique** ; une **capside**, qui renferme l'**ARN viral** et la transcriptase inverse. Un virus n'a pas de métabolisme propre : il ne se multiplie que dans une cellule vivante (parasite intracellulaire). Le VIH reconnaît ses cellules par complémentarité : sa **gp120** se fixe sur le récepteur membranaire **CD4**. Les cellules qui portent CD4, les **lymphocytes T4** (LT4) en premier, sont les **cellules cibles**. Les hématies, les lymphocytes B et les lymphocytes T8 n'ont pas CD4 : le VIH ne s'y fixe pas. Les LT4 coordonnent la réponse immunitaire : quand le VIH les détruit, les défenses s'affaiblissent. »
  - Après : « Le **VIH** (virus de l'immunodéficience humaine) est un **rétrovirus** : son matériel génétique est de l'**ARN** et il porte une enzyme, la **transcriptase inverse**. De l'extérieur vers l'intérieur : une **enveloppe**, qui porte les glycoprotéines **gp120** et **gp41** ; une **matrice protéique** ; une **capside**, qui renferme l'**ARN viral** et la transcriptase inverse. Un virus n'a pas de métabolisme propre : il ne se multiplie que dans une cellule vivante (parasite intracellulaire). Le VIH reconnaît ses cellules par complémentarité : sa **gp120** se fixe sur le récepteur membranaire **CD4**. Les cellules qui portent CD4, les **lymphocytes T4** (LT4) en premier, mais aussi les macrophages, sont les **cellules cibles**. Les hématies, les lymphocytes B et les lymphocytes T8 n'ont pas CD4 : le VIH ne s'y fixe pas. Les LT4 coordonnent la réponse immunitaire : quand le VIH les détruit, les défenses s'affaiblissent. »
- **Lieu** : notion « Le VIH et ses cellules cibles » › exemple › étape 3
  - Avant : « Conclure : seuls les LT4 sont des cellules cibles : la gp120 se fixe sur CD4, le virus entre et se multiplie ; sur les deux autres cultures, il ne se fixe pas. »
  - Après : « Conclure : parmi ces cultures, seuls les LT4 sont des cellules cibles : la gp120 se fixe sur CD4, le virus entre et se multiplie ; sur les deux autres cultures, il ne se fixe pas. »
- **Lieu** : notion « Le VIH et ses cellules cibles » › exercice 1 (« Le VIH et ses cellules cibles ») › question 3, champ explanation
  - Avant : « Étape 1 — Repérer : le virus se fixe grâce à sa gp120, sur un récepteur de la cellule. Étape 2 — Vérifier : seuls les LT4 portent CD4 ; les LT8 portent CD8, les lymphocytes B et les hématies n'ont pas CD4. Étape 3 — Conclure : seule la culture de LT4 est une culture de cellules cibles : le virus y entre et s'y multiplie. Étape 4 — Déduire : l'infection des LT4 affaiblit la coordination de la réponse immunitaire. Penser que tout globule blanc est une cible est l'erreur tentante : il faut regarder le récepteur. »
  - Après : « Étape 1 — Repérer : le virus se fixe grâce à sa gp120, sur un récepteur de la cellule. Étape 2 — Vérifier : parmi ces cellules, seuls les LT4 portent CD4 ; les LT8 portent CD8, les lymphocytes B et les hématies n'ont pas CD4. Étape 3 — Conclure : seule la culture de LT4 est une culture de cellules cibles : le virus y entre et s'y multiplie. Étape 4 — Déduire : l'infection des LT4 affaiblit la coordination de la réponse immunitaire. Penser que tout globule blanc est une cible est l'erreur tentante : il faut regarder le récepteur. »
- **Lieu** : problème 1 (« Pourquoi le VIH n'infecte-t-il que certaines cellules ? ») › question 2, champ explanation
  - Avant : « Méthode : 1. Repérer la différence entre les cultures : seul le type de cellule change. 2. Formuler une hypothèse qui explique cette différence : la fixation du virus dépend d'un récepteur. 3. Vérifier : c'est cohérent avec la gp120 qui reconnaît CD4 (notion 1). 4. Conclure : seuls les LT4 ont le récepteur. L'hypothèse du noyau est fausse : les LT8 et les lymphocytes B ont aussi un noyau. »
  - Après : « Méthode : 1. Repérer la différence entre les cultures : seul le type de cellule change. 2. Formuler une hypothèse qui explique cette différence : la fixation du virus dépend d'un récepteur. 3. Vérifier : c'est cohérent avec la gp120 qui reconnaît CD4 (notion 1). 4. Conclure : parmi ces cellules, seuls les LT4 ont le récepteur. L'hypothèse du noyau est fausse : les LT8 et les lymphocytes B ont aussi un noyau. »

### Tle D · SVT · L'infection de l'organisme par le VIH (`docs/contenus/lecons-traitees/tle-d/svt/l-infection-de-l-organisme-par-le-vih.json`)

- **Lieu** : notion « Le VIH et ses cellules cibles », champ remember
  - Avant : « Le **VIH** (virus de l'immunodéficience humaine) est un **rétrovirus** : son matériel génétique est de l'**ARN** et il porte une enzyme, la **transcriptase inverse**. De l'extérieur vers l'intérieur : une **enveloppe**, qui porte les glycoprotéines **gp120** et **gp41** ; une **matrice protéique** ; une **capside**, qui renferme l'**ARN viral** et la transcriptase inverse. Un virus n'a pas de métabolisme propre : il ne se multiplie que dans une cellule vivante (parasite intracellulaire). Le VIH reconnaît ses cellules par complémentarité : sa **gp120** se fixe sur le récepteur membranaire **CD4**. Les cellules qui portent CD4, les **lymphocytes T4** (LT4) en premier, sont les **cellules cibles**. Les hématies, les lymphocytes B et les lymphocytes T8 n'ont pas CD4 : le VIH ne s'y fixe pas. Les LT4 coordonnent la réponse immunitaire : quand le VIH les détruit, les défenses s'affaiblissent. »
  - Après : « Le **VIH** (virus de l'immunodéficience humaine) est un **rétrovirus** : son matériel génétique est de l'**ARN** et il porte une enzyme, la **transcriptase inverse**. De l'extérieur vers l'intérieur : une **enveloppe**, qui porte les glycoprotéines **gp120** et **gp41** ; une **matrice protéique** ; une **capside**, qui renferme l'**ARN viral** et la transcriptase inverse. Un virus n'a pas de métabolisme propre : il ne se multiplie que dans une cellule vivante (parasite intracellulaire). Le VIH reconnaît ses cellules par complémentarité : sa **gp120** se fixe sur le récepteur membranaire **CD4**. Les cellules qui portent CD4, les **lymphocytes T4** (LT4) en premier, mais aussi les macrophages, sont les **cellules cibles**. Les hématies, les lymphocytes B et les lymphocytes T8 n'ont pas CD4 : le VIH ne s'y fixe pas. Les LT4 coordonnent la réponse immunitaire : quand le VIH les détruit, les défenses s'affaiblissent. »
- **Lieu** : notion « Le VIH et ses cellules cibles » › exemple › étape 3
  - Avant : « Conclure : seuls les LT4 sont des cellules cibles : la gp120 se fixe sur CD4, le virus entre et se multiplie ; sur les deux autres cultures, il ne se fixe pas. »
  - Après : « Conclure : parmi ces cultures, seuls les LT4 sont des cellules cibles : la gp120 se fixe sur CD4, le virus entre et se multiplie ; sur les deux autres cultures, il ne se fixe pas. »
- **Lieu** : notion « Le VIH et ses cellules cibles » › exercice 1 (« Le VIH et ses cellules cibles ») › question 3, champ explanation
  - Avant : « Étape 1 — Repérer : le virus se fixe grâce à sa gp120, sur un récepteur de la cellule. Étape 2 — Vérifier : seuls les LT4 portent CD4 ; les LT8 portent CD8, les lymphocytes B et les hématies n'ont pas CD4. Étape 3 — Conclure : seule la culture de LT4 est une culture de cellules cibles : le virus y entre et s'y multiplie. Étape 4 — Déduire : l'infection des LT4 affaiblit la coordination de la réponse immunitaire. Penser que tout globule blanc est une cible est l'erreur tentante : il faut regarder le récepteur. »
  - Après : « Étape 1 — Repérer : le virus se fixe grâce à sa gp120, sur un récepteur de la cellule. Étape 2 — Vérifier : parmi ces cellules, seuls les LT4 portent CD4 ; les LT8 portent CD8, les lymphocytes B et les hématies n'ont pas CD4. Étape 3 — Conclure : seule la culture de LT4 est une culture de cellules cibles : le virus y entre et s'y multiplie. Étape 4 — Déduire : l'infection des LT4 affaiblit la coordination de la réponse immunitaire. Penser que tout globule blanc est une cible est l'erreur tentante : il faut regarder le récepteur. »
- **Lieu** : problème 1 (« Pourquoi le VIH n'infecte-t-il que certaines cellules ? ») › question 2, champ explanation
  - Avant : « Méthode : 1. Repérer la différence entre les cultures : seul le type de cellule change. 2. Formuler une hypothèse qui explique cette différence : la fixation du virus dépend d'un récepteur. 3. Vérifier : c'est cohérent avec la gp120 qui reconnaît CD4 (notion 1). 4. Conclure : seuls les LT4 ont le récepteur. L'hypothèse du noyau est fausse : les LT8 et les lymphocytes B ont aussi un noyau. »
  - Après : « Méthode : 1. Repérer la différence entre les cultures : seul le type de cellule change. 2. Formuler une hypothèse qui explique cette différence : la fixation du virus dépend d'un récepteur. 3. Vérifier : c'est cohérent avec la gp120 qui reconnaît CD4 (notion 1). 4. Conclure : parmi ces cellules, seuls les LT4 ont le récepteur. L'hypothèse du noyau est fausse : les LT8 et les lymphocytes B ont aussi un noyau. »

### Tle D · SVT · La reproduction chez les spermaphytes (`docs/contenus/lecons-traitees/tle-d/svt/la-reproduction-chez-les-spermaphytes.json`)

- **Lieu** : notion « La formation du grain de pollen et du sac embryonnaire », champ remember
  - Avant : « Une fleur d'angiosperme porte les **étamines** (une **anthère** au bout d'un filet), organes mâles, et le **pistil** (stigmate, style, **ovaire** qui contient les **ovules**), organe femelle. Les cellules du corps de la plante sont **diploïdes** : $2n$ chromosomes. Dans l'anthère, une **cellule mère de pollen** ($2n$) subit la **méiose** et donne 4 **microspores** ($n$). Chacune fait une **mitose** et devient un **grain de pollen** à 2 cellules : une cellule végétative et une cellule reproductrice. Dans l'ovule, la **cellule mère du sac embryonnaire** ($2n$) subit la méiose et donne 4 **macrospores** ($n$) dont 3 dégénèrent. La dernière fait 3 mitoses et forme le **sac embryonnaire** à 8 noyaux ($n$), dont l'**oosphère** (gamète femelle) et 2 **noyaux polaires**. La méiose réduit le nombre de chromosomes de $2n$ à $n$ ; les mitoses le conservent. »
  - Après : « Les **spermaphytes** sont les plantes à graines : les **angiospermes**, dont la graine est enfermée dans un fruit, et les gymnospermes (comme le pin), à graines nues ; la leçon étudie les angiospermes. Une fleur d'angiosperme porte les **étamines** (une **anthère** au bout d'un filet), organes mâles, et le **pistil** (stigmate, style, **ovaire** qui contient les **ovules**), organe femelle. Les cellules du corps de la plante sont **diploïdes** : $2n$ chromosomes. Dans l'anthère, une **cellule mère de pollen** ($2n$) subit la **méiose** et donne 4 **microspores** ($n$). Chacune fait une **mitose** et devient un **grain de pollen** à 2 cellules : une cellule végétative et une cellule reproductrice. Dans l'ovule, la **cellule mère du sac embryonnaire** ($2n$) subit la méiose et donne 4 **macrospores** ($n$) dont 3 dégénèrent. La dernière fait 3 mitoses et forme le **sac embryonnaire** à 8 noyaux ($n$), dont l'**oosphère** (gamète femelle) et 2 **noyaux polaires**. La méiose réduit le nombre de chromosomes de $2n$ à $n$ ; les mitoses le conservent. »

### Tle D · SVT · Le réflexe conditionnel (`docs/contenus/lecons-traitees/tle-d/svt/le-reflexe-conditionnel.json`)

- **Lieu** : notion « Réflexes conditionnels, dressage et apprentissage », champ remember
  - Avant : « Les réflexes conditionnels interviennent dans la vie de tous les jours. Le **dressage** d'un animal consiste à établir des réflexes conditionnels : un signal d'abord neutre (sifflet, ordre) est associé de façon répétée à une récompense, et le **renforcement** l'entretient. Chez l'**Homme**, beaucoup d'**habitudes** et d'apprentissages reposent en partie sur des réflexes conditionnels : saliver à la sonnerie de la cantine, freiner à un signal sonore, acquérir des gestes ou des réactions par l'**éducation**. Ces réflexes permettent d'**anticiper** et de s'adapter à l'environnement. Ils ne résument pas le comportement humain : l'Homme possède aussi la pensée, la mémoire et le langage. »
  - Après : « Les réflexes conditionnels interviennent dans la vie de tous les jours. Le **dressage** d'un animal repose en grande partie sur des réflexes conditionnels : un signal d'abord neutre (sifflet, ordre) est associé de façon répétée à une récompense, et le **renforcement** l'entretient. Chez l'**Homme**, beaucoup d'**habitudes** et d'apprentissages reposent en partie sur des réflexes conditionnels : saliver à la sonnerie de la cantine, freiner à un signal sonore, acquérir des gestes ou des réactions par l'**éducation**. Ces réflexes permettent d'**anticiper** et de s'adapter à l'environnement. Ils ne résument pas le comportement humain : l'Homme possède aussi la pensée, la mémoire et le langage. »

## Français

Aucun fichier présent sur `origin/main` n'a été modifié : les douze leçons de Français corrigées (6ème, 5ème, 4ème, 1ère Rythme et Focalisation) n'existent pas encore sur `main`.

## Histoire-Géographie

Corrections du validateur pédagogique sur les leçons déjà sur `origin/main`. Les leçons absentes de main (2nde « La planète Terre », 4ème « La mise en place des peuples ») ont aussi été corrigées, mais ne sont pas listées ici.

### Tle · Histoire-Géographie · Géographie — Les fondements du développement économique de la Côte d'Ivoire (`docs/contenus/lecons-traitees/tle/histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json`)

- **Lieu** : notion « Expliquer les fondements politiques et institutionnels », champ pitfall
  - Avant : « Ne confonds pas l'UEMOA et la CEDEAO. L'UEMOA (1994) compte huit États qui partagent le franc CFA ; la CEDEAO (1975) est une communauté plus large, qui compte des pays dont la monnaie est différente, comme le Nigeria et le Ghana. Ne confonds pas non plus le libéralisme (l'initiative privée) et la planification (les objectifs fixés par l'État) : la Côte d'Ivoire a combiné les deux. »
  - Après : « Ne confonds pas l'UEMOA et la CEDEAO. L'UEMOA (créée en 1994, huit États depuis 1997) partage le franc CFA ; la CEDEAO (1975) est une communauté plus large, qui compte des pays dont la monnaie est différente, comme le Nigeria et le Ghana. Ne confonds pas non plus le libéralisme (l'initiative privée) et la planification (les objectifs fixés par l'État) : la Côte d'Ivoire a combiné les deux. »

### Tle · Histoire-Géographie · Histoire — De la fin de la guerre froide vers un monde multipolaire (`docs/contenus/lecons-traitees/tle/histoire-geographie/histoire-de-la-fin-de-la-guerre-froide-vers-un-monde-multipolaire.json`)

- **Lieu** : notion « L'émergence d'un monde multipolaire », champ remember
  - Avant : « Un monde est **multipolaire** quand plusieurs pôles (États ou groupes d'États) comptent dans les décisions mondiales. Les États-Unis restent puissants, mais d'autres pôles montent : l'**Union européenne** (traité de Maastricht en vigueur en 1993, euro en 2002, élargissement vers l'Est en 2004), la **Chine** (réformes depuis 1978, OMC en 2001), la **Russie** (héritière de l'URSS, puissance nucléaire) et les **pays émergents**, à forte croissance. Le **BRIC** (Brésil, Russie, Inde, Chine), terme créé en 2001, devient les **BRICS** avec l'Afrique du Sud (invitée fin 2010, au sommet de 2011) : c'est un groupe de dialogue économique. Les **organisations régionales** renforcent les États : Union africaine (2002), CEDEAO (1975), ASEAN (1967), Mercosur (1991). L'Afrique, avec 54 États, est à la fois un acteur et un partenaire recherché par plusieurs pôles. »
  - Après : « Un monde est **multipolaire** quand plusieurs pôles (États ou groupes d'États) comptent dans les décisions mondiales. Les États-Unis restent puissants, mais d'autres pôles montent : l'**Union européenne** (traité de Maastricht en vigueur en 1993, euro en 2002, élargissement vers l'Est en 2004), la **Chine** (réformes depuis 1978, OMC en 2001), la **Russie** (héritière de l'URSS, puissance nucléaire) et les **pays émergents**, à forte croissance. Le **BRIC** (Brésil, Russie, Inde, Chine), terme créé en 2001, devient les **BRICS** avec l'Afrique du Sud (invitée fin 2010, au sommet de 2011) : c'est un groupe de dialogue économique, élargi à d'autres pays depuis 2024. Les **organisations régionales** renforcent les États : Union africaine (2002), CEDEAO (1975), ASEAN (1967), Mercosur (1991). L'Afrique, avec 54 États, est à la fois un acteur et un partenaire recherché par plusieurs pôles. »
- **Lieu** : sujet 3 (« Sujet 3 · Expliquer, justifier et comparer ») › exercice 1 (« Exercice 1 »), champ statement
  - Avant : « Document : texte écrit pour Lnclass à partir de la leçon. Dans les années 1980, l'économie planifiée de l'URSS fonctionne mal : pénuries, retard technologique, dépenses très lourdes de la course aux armements et de la guerre d'Afghanistan. En mars 1985, Gorbatchev lance la perestroïka et la glasnost et dialogue avec les États-Unis. Ces réformes libèrent la contestation dans les pays du bloc de l'Est. »
  - Après : « Document : texte écrit pour Lnclass à partir de la leçon. Dans les années 1980, l'économie planifiée de l'URSS fonctionne mal : pénuries, retard technologique, dépenses très lourdes de la course aux armements et de la guerre d'Afghanistan. Arrivé au pouvoir en mars 1985, Gorbatchev lance la perestroïka et la glasnost et dialogue avec les États-Unis. Ces réformes libèrent la contestation dans les pays du bloc de l'Est. »

### Tle · Histoire-Géographie · Géographie — Les problèmes de développement économique de la Côte d'Ivoire (`docs/contenus/lecons-traitees/tle/histoire-geographie/geographie-les-problemes-de-developpement-economique-de-la-cote-d-ivoire.json`)

- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux », champ remember
  - Avant : « La **déforestation** est la disparition de la forêt. Le couvert forestier ivoirien est passé d'environ 16 millions d'hectares en 1900 à environ 12 en 1960, puis à environ 3 en 2015 (ordres de grandeur couramment cités (documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt)). Ses causes sont humaines et économiques : extension des plantations de cacao et de café, exploitation du bois, croissance des villes. Ses conséquences : érosion des sols, perte de **biodiversité** (diversité des espèces vivantes), pluies plus irrégulières, baisse des rendements. Les **déséquilibres régionaux** sont les écarts de développement entre régions : Abidjan et le sud concentrent la population, les industries, les ports et les meilleures routes ; le nord, le nord-ouest et le nord-est sont moins équipés et connaissent plus de pauvreté. Ces écarts alimentent l'**exode rural**, le départ des habitants des campagnes vers les villes, surtout Abidjan. »
  - Après : « La **déforestation** est la disparition de la forêt. Le couvert forestier ivoirien est passé d'environ 16 millions d'hectares en 1900 à environ 8 en 1990, puis à environ 3 en 2015 (ordres de grandeur couramment cités (documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt)). Ses causes sont humaines et économiques : extension des plantations de cacao et de café, exploitation du bois, croissance des villes. Ses conséquences : érosion des sols, perte de **biodiversité** (diversité des espèces vivantes), pluies plus irrégulières, baisse des rendements. Les **déséquilibres régionaux** sont les écarts de développement entre régions : Abidjan et le sud concentrent la population, les industries, les ports et les meilleures routes ; le nord, le nord-ouest et le nord-est sont moins équipés et connaissent plus de pauvreté. Ces écarts alimentent l'**exode rural**, le départ des habitants des campagnes vers les villes, surtout Abidjan. »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › exemple, champ steps/2 (étape 2)
  - Avant : « Décrire : le couvert forestier passe d'environ 12 millions d'hectares en 1960 à environ 3 en 2015 (ordres de grandeur couramment cités), soit une perte d'environ 9 millions d'hectares. »
  - Après : « Décrire : le couvert forestier passe d'environ 8 millions d'hectares en 1990 à environ 3 en 2015 (ordres de grandeur couramment cités), soit une perte d'environ 5 millions d'hectares. »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux », champ pitfall
  - Avant : « Ne confonds pas cause et conséquence. L'érosion des sols est une conséquence de la déforestation, pas sa cause. Contre-exemple chiffré : si la forêt passe d'environ 12 à environ 3 millions d'hectares, elle perd environ 9 millions d'hectares, soit les trois quarts (9 ÷ 12 = 0,75). Cette perte vient des défrichements (la cause) ; l'érosion s'ensuit (la conséquence). »
  - Après : « Ne confonds pas cause et conséquence. L'érosion des sols est une conséquence de la déforestation, pas sa cause. Contre-exemple chiffré : si la forêt passe d'environ 16 à environ 8 millions d'hectares, elle perd environ 8 millions d'hectares, soit la moitié (8 ÷ 16 = 0,5). Cette perte vient des défrichements (la cause) ; l'érosion s'ensuit (la conséquence). »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › exercice noté 1 (« Déforestation et déséquilibres régionaux ») › question 2, champ content
  - Avant : « Le couvert forestier ivoirien est passé d'environ 12 millions d'hectares en 1960 à environ 3 millions d'hectares en 2015 (ordres de grandeur couramment cités, documents REDD+ ; les valeurs varient selon la définition de la forêt). Quelle perte cela représente-t-il, en millions d'hectares ? »
  - Après : « Le couvert forestier ivoirien est passé d'environ 8 millions d'hectares en 1990 à environ 3 millions d'hectares en 2015 (ordres de grandeur couramment cités, documents REDD+ ; les valeurs varient selon la définition de la forêt). Quelle perte cela représente-t-il, en millions d'hectares ? »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › exercice noté 1 (« Déforestation et déséquilibres régionaux ») › question 2, champ explanation
  - Avant : « Étape 2 — Décrire ses manifestations avec une donnée : perte = 12 − 3 = 9 millions d'hectares, soit les trois quarts de la forêt de 1960. »
  - Après : « Étape 2 — Décrire ses manifestations avec une donnée : perte = 8 − 3 = 5 millions d'hectares, soit plus de la moitié de la forêt de 1990. »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › exercice noté 1 (« Déforestation et déséquilibres régionaux ») › question 2, champ answers/0/content
  - Avant : « 9 »
  - Après : « 5 »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › entraînement › question 5, champ explanation
  - Avant : « Étape 2 — Décrire ses manifestations avec une donnée datée et sourcée : le couvert forestier passe d'environ 12 millions d'hectares (1960) à environ 3 (2015). Les autres chiffres concernent d'autres sujets. »
  - Après : « Étape 2 — Décrire ses manifestations avec une donnée datée et sourcée : le couvert forestier passe d'environ 8 millions d'hectares (1990) à environ 3 (2015). Les autres chiffres concernent d'autres sujets. »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › entraînement › question 5, champ answers/2/content
  - Avant : « Le couvert forestier passe d'environ 12 millions d'hectares en 1960 à environ 3 en 2015 »
  - Après : « Le couvert forestier passe d'environ 8 millions d'hectares en 1990 à environ 3 en 2015 »
- **Lieu** : notion « Analyser les problèmes environnementaux et les déséquilibres régionaux » › exercice noté 2 (« Forêt, causes et écarts entre régions ») › question 1, champ explanation
  - Avant : « Étape 2 — Décrire ses manifestations avec une donnée datée et sourcée : la perte vaut 16 − 3 = 13 millions d'hectares entre 1900 et 2015. Se tromper de période, par exemple prendre 12 − 3 = 9 pour 1960-2015, donne la perte d'une autre période et non celle demandée. »
  - Après : « Étape 2 — Décrire ses manifestations avec une donnée datée et sourcée : la perte vaut 16 − 3 = 13 millions d'hectares entre 1900 et 2015. Se tromper de période, par exemple prendre 8 − 3 = 5 pour 1990-2015, donne la perte d'une autre période et non celle demandée. »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation »), champ statement
  - Avant : « Document 1 : courbe du couvert forestier de la Côte d'Ivoire, en millions d'hectares, en ordres de grandeur : environ 16 en 1900, 12 en 1960, 3 en 2015 (ordres de grandeur couramment cités, documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt ; trois points inégalement espacés, 1900, 1960 et 2015, sur un axe régulier). Document 2 : texte écrit pour Lnclass. À Abidjan, de nombreux jeunes arrivés des campagnes travaillent dans le commerce de rue, sans contrat, et vivent dans des quartiers précaires. Réponds aux questions. »
  - Après : « Document 1 : courbe du couvert forestier de la Côte d'Ivoire, en millions d'hectares, en ordres de grandeur : environ 16 en 1900, 8 en 1990, 3 en 2015 (ordres de grandeur couramment cités, documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt ; trois points inégalement espacés, 1900, 1990 et 2015, sur un axe régulier). Document 2 : texte écrit pour Lnclass. À Abidjan, de nombreux jeunes arrivés des campagnes travaillent dans le commerce de rue, sans contrat, et vivent dans des quartiers précaires. Réponds aux questions. »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 1, champ content
  - Avant : « Le couvert forestier ivoirien est passé d'environ 16 millions d'hectares en 1900 à environ 12 millions en 1960 (ordres de grandeur couramment cités, documents REDD+). Quelle perte cela représente-t-il, en millions d'hectares ? »
  - Après : « Le couvert forestier ivoirien est passé d'environ 16 millions d'hectares en 1900 à environ 8 millions en 1990 (ordres de grandeur couramment cités, documents REDD+). Quelle perte cela représente-t-il, en millions d'hectares ? »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 1, champ explanation
  - Avant : « Étape 1 — Localiser et lire la donnée : la courbe descend de 16 à 12. Étape 2 — Décrire avec une donnée : perte = 16 − 12 = 4 millions d'hectares entre 1900 et 1960. »
  - Après : « Étape 1 — Localiser et lire la donnée : la courbe descend de 16 à 8. Étape 2 — Décrire avec une donnée : perte = 16 − 8 = 8 millions d'hectares entre 1900 et 1990. »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 1, champ answers/0/content
  - Avant : « 4 »
  - Après : « 8 »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 2, champ content
  - Avant : « Le couvert forestier est passé d'environ 12 millions d'hectares en 1960 à environ 3 millions en 2015 (ordres de grandeur couramment cités, documents REDD+). Quel pourcentage de la forêt de 1960 a disparu ? »
  - Après : « Le couvert forestier est passé d'environ 16 millions d'hectares en 1900 à environ 8 millions en 1990 (ordres de grandeur couramment cités, documents REDD+). Quel pourcentage de la forêt de 1900 a disparu en 1990 ? »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 2, champ explanation
  - Avant : « Étape 2 — Décrire avec une donnée : perte = 12 − 3 = 9 millions d'hectares. Part perdue = 9 ÷ 12 = 0,75, soit 75 %. Les trois quarts de la forêt de 1960 ont disparu en 2015. »
  - Après : « Étape 2 — Décrire avec une donnée : perte = 16 − 8 = 8 millions d'hectares. Part perdue = 8 ÷ 16 = 0,5, soit 50 %. La moitié de la forêt de 1900 avait disparu en 1990. »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 4 (« Exercice 4 »), champ statement
  - Avant : « Document : texte écrit pour Lnclass. Le couvert forestier ivoirien est passé d'environ 12 millions d'hectares en 1960 à environ 3 millions en 2015 (ordres de grandeur couramment cités, documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt). Abidjan concentre les industries et le port, alors que le nord est moins équipé. Pour répondre aux problèmes, on parle de diversification, de transformation locale et de reboisement. Réponds aux questions. »
  - Après : « Document : texte écrit pour Lnclass. Le couvert forestier ivoirien est passé d'environ 16 millions d'hectares en 1900 à environ 8 millions en 1990, puis à environ 3 millions en 2015 (ordres de grandeur couramment cités, documents de la stratégie nationale REDD+ ; les valeurs varient selon la définition de la forêt). Abidjan concentre les industries et le port, alors que le nord est moins équipé. Pour répondre aux problèmes, on parle de diversification, de transformation locale et de reboisement. Réponds aux questions. »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 4 (« Exercice 4 ») › question 1, champ content
  - Avant : « Le couvert forestier est passé d'environ 12 millions d'hectares en 1960 à environ 3 millions en 2015 (ordres de grandeur couramment cités, documents REDD+). Quel pourcentage du couvert de 1960 reste en 2015 ? »
  - Après : « Le couvert forestier est passé d'environ 8 millions d'hectares en 1990 à environ 3 millions en 2015 (ordres de grandeur couramment cités, documents REDD+). Quelle perte cela représente-t-il entre 1990 et 2015, en millions d'hectares ? »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 4 (« Exercice 4 ») › question 1, champ explanation
  - Avant : « Étape 2 — Décrire avec une donnée datée et sourcée : 3 ÷ 12 × 100 = 25 %, il reste le quart du couvert de 1960. Les trois quarts disparus (9 ÷ 12 = 75 %) ne sont pas la part restante : répondre 75 serait donner la part perdue et non celle qui reste. »
  - Après : « Étape 2 — Décrire avec une donnée datée et sourcée : 8 − 3 = 5 millions d'hectares perdus entre 1990 et 2015. Calculer 16 − 8 = 8 donnerait la perte d'une autre période (1900-1990), et non celle demandée. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier ») › exercice 3 (« Exercice 3 ») › question 4, champ content
  - Avant : « Si la forêt passe d'environ 12 à environ 3 millions d'hectares (ordres de grandeur couramment cités), elle perd les trois quarts de sa superficie. »
  - Après : « Si la forêt passe d'environ 16 à environ 8 millions d'hectares (ordres de grandeur couramment cités), elle perd la moitié de sa superficie. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier ») › exercice 3 (« Exercice 3 ») › question 4, champ explanation
  - Avant : « Étape 2 — Décrire avec une donnée : la perte vaut 12 − 3 = 9 millions d'hectares ; 9 ÷ 12 = 0,75, soit les trois quarts. L'affirmation est vraie. Dire la moitié ou le quart viendrait d'un mauvais rapport entre la perte et la superficie de départ. »
  - Après : « Étape 2 — Décrire avec une donnée : la perte vaut 16 − 8 = 8 millions d'hectares ; 8 ÷ 16 = 0,5, soit la moitié. L'affirmation est vraie. Dire le quart ou les trois quarts viendrait d'un mauvais rapport entre la perte et la superficie de départ. »
- **Lieu** : sujet 4 (« Sujet 4 · Bilan de la leçon ») › exercice 2 (« Exercice 2 ») › question 5, champ content
  - Avant : « Le couvert forestier est passé d'environ 16 millions d'hectares en 1900 à environ 12 millions en 1960 (ordres de grandeur couramment cités, documents REDD+). Quel pourcentage du couvert de 1900 avait disparu en 1960 ? »
  - Après : « Le couvert forestier est passé d'environ 16 millions d'hectares en 1900 à environ 8 millions en 1990 (ordres de grandeur couramment cités, documents REDD+). Quel pourcentage du couvert de 1900 avait disparu en 1990 ? »
- **Lieu** : sujet 4 (« Sujet 4 · Bilan de la leçon ») › exercice 2 (« Exercice 2 ») › question 5, champ explanation
  - Avant : « Étape 2 — Décrire avec une donnée datée et sourcée : la perte vaut 16 − 12 = 4 millions d'hectares ; 4 ÷ 16 × 100 = 25 %. Calculer 4 ÷ 12 donnerait 33 %, ce qui rapporterait la perte à la mauvaise superficie, celle de 1960 au lieu de celle de 1900. »
  - Après : « Étape 2 — Décrire avec une donnée datée et sourcée : la perte vaut 16 − 8 = 8 millions d'hectares ; 8 ÷ 16 × 100 = 50 %. Calculer 8 ÷ 8 donnerait 100 %, ce qui rapporterait la perte à la mauvaise superficie, celle de 1990 au lieu de celle de 1900. »
- **Lieu** : figure 3 (courbe du couvert forestier), champ description
  - Avant : « Courbe du couvert forestier de la Côte d'Ivoire, en millions d'hectares, en ordres de grandeur couramment cités : environ 16 en 1900, 12 en 1960, 3 en 2015. Les trois points sont inégalement espacés (1900, 1960, 2015) sur un axe régulier. La courbe descend nettement : la forêt a fortement reculé depuis 1900. Valeurs arrondies, variables selon la définition de la forêt. »
  - Après : « Courbe du couvert forestier de la Côte d'Ivoire, en millions d'hectares, en ordres de grandeur couramment cités : environ 16 en 1900, 8 en 1990, 3 en 2015. Les trois points sont inégalement espacés (1900, 1990, 2015) sur un axe régulier. La courbe descend nettement : la forêt a fortement reculé depuis 1900. Valeurs arrondies, variables selon la définition de la forêt. »
- **Lieu** : exercice 3 (« Forêt, jeunesse et urbanisation ») › question 2, champ answers/0/content
  - Avant : « 75 »
  - Après : « 50 »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 4 (« Exercice 4 ») › question 1, champ answers/0/content
  - Avant : « 25 »
  - Après : « 5 »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 4 (« Exercice 4 ») › question 1, champ unit
  - Avant : « % »
  - Après : « M ha »
- **Lieu** : sujet 4 (« Sujet 4 · Bilan de la leçon ») › exercice 2 (« Exercice 2 ») › question 5, champ answers/0/content
  - Avant : « 25 »
  - Après : « 50 »
- **Lieu** : figure 3 (courbe du couvert forestier), champ params/labels/1
  - Avant : « 1960 »
  - Après : « 1990 »
- **Lieu** : figure 3 (courbe du couvert forestier), champ params/series/1
  - Avant : « 12 »
  - Après : « 8 »

### Tle · Histoire-Géographie · Géographie — Les fondements de l'économie de la France (`docs/contenus/lecons-traitees/tle/histoire-geographie/geographie-les-fondements-de-l-economie-de-la-france.json`)

- **Lieu** : notion « Expliquer le choix du nucléaire à partir d'un document statistique », champ remember
  - Avant : « La France a très peu de pétrole et de gaz. Quand le **premier choc pétrolier** éclate en 1973 (forte hausse du prix du pétrole), elle choisit en 1974 de construire un grand nombre de **centrales nucléaires**, exploitées par EDF, pour produire son électricité avec moins de pétrole importé. Résultat : la part du nucléaire dans la production d'électricité passe d'environ 8 % en 1973 à environ 75 % en 1990, puis reste proche de 71 % en 2019 (source : RTE et EDF, ordres de grandeur). Le pays compte 56 réacteurs en service en 2019 (source : EDF). Le nucléaire réduit la dépendance au pétrole, mais l'uranium est importé. Un **document statistique** se lit avec méthode : titre, **source**, **dates**, **unité**. Un écart entre deux pourcentages se donne en **points de pourcentage**. »
  - Après : « La France a très peu de pétrole et de gaz. Quand le **premier choc pétrolier** éclate en 1973 (forte hausse du prix du pétrole), elle choisit en 1974 de construire un grand nombre de **centrales nucléaires**, exploitées par EDF, pour produire son électricité avec moins de pétrole importé. Résultat : la part du nucléaire dans la production d'électricité passe d'environ 8 % en 1973 à environ 75 % en 1990, puis reste proche de 71 % en 2019 (source : RTE et EDF, ordres de grandeur). Le pays compte 58 réacteurs en service en 2019 (source : EDF). Le nucléaire réduit la dépendance au pétrole, mais l'uranium est importé. Un **document statistique** se lit avec méthode : titre, **source**, **dates**, **unité**. Un écart entre deux pourcentages se donne en **points de pourcentage**. »
- **Lieu** : notion « Expliquer le choix du nucléaire à partir d'un document statistique » › exercice noté 2 (« Lire et calculer sur un document statistique ») › question 4, champ content
  - Avant : « En 2019, la France compte 56 ___ nucléaires en service (source : EDF). »
  - Après : « En 2019, la France compte 58 ___ nucléaires en service (source : EDF). »
- **Lieu** : notion « Expliquer le choix du nucléaire à partir d'un document statistique » › exercice noté 2 (« Lire et calculer sur un document statistique ») › question 4, champ explanation
  - Avant : « Étape 2 — Relever : le chiffre utile est 56, avec sa source et sa date. Le pays compte 56 réacteurs en service en 2019 selon EDF. Ne confonds pas ce nombre de réacteurs avec la part de 71 % du nucléaire dans la production d'électricité. »
  - Après : « Étape 2 — Relever : le chiffre utile est 58, avec sa source et sa date. Le pays compte 58 réacteurs en service en 2019 selon EDF. Ne confonds pas ce nombre de réacteurs avec la part de 71 % du nucléaire dans la production d'électricité. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier ») › exercice 4 (« Exercice 4 ») › question 5, champ explanation
  - Avant : « Étape 2 — Relever : la valeur de 2019 est environ 71 %. Étape 3 — Écarter : 8 % est la valeur de 1973, 75 % celle de 1990 et 56 est le nombre de réacteurs en service en 2019, non un pourcentage. »
  - Après : « Étape 2 — Relever : la valeur de 2019 est environ 71 %. Étape 3 — Écarter : 8 % est la valeur de 1973, 75 % celle de 1990 et 58 est le nombre de réacteurs en service en 2019, non un pourcentage. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier ») › exercice 4 (« Exercice 4 ») › question 5, champ answers/3/content
  - Avant : « Environ 56 % »
  - Après : « Environ 58 % »

### Tle · Histoire-Géographie · Histoire — L'accession de l'Algérie à l'indépendance (`docs/contenus/lecons-traitees/tle/histoire-geographie/histoire-l-accession-de-l-algerie-a-l-independance.json`)

- **Lieu** : exercice 4 (« L'accession de l'Algérie à l'indépendance (1954-1962) : commentaire de document ») › question 6, champ explanation
  - Avant : « Corrigé modèle : L'Algérie, conquise à partir de 1830, est une colonie de peuplement où les musulmans ont moins de droits que les colons. Des courants nationalistes apparaissent : Messali Hadj réclame l'indépendance, Ferhat Abbas l'égalité, les oulémas défendent l'identité arabe et musulmane. Le 8 mai 1945, des manifestations à Sétif et Guelma sont suivies de violences et d'une répression ; le bilan humain est discuté. Le 1er novembre 1954, le FLN et l'ALN lancent la guerre, qui s'internationalise (ONU en 1955, bases arrière au Maroc et en Tunisie). Le 13 mai 1958, de Gaulle revient au pouvoir ; le GPRA est proclamé ; en 1959, de Gaulle propose l'autodétermination, malgré l'opposition de l'OAS. Les accords d'Évian (18 mars 1962), les référendums et la proclamation du 5 juillet 1962 mènent à l'indépendance, avec le départ des rapatriés et le sort difficile des harkis. Barème : inégalités et courants (1,5), Sétif et Guelma (1), 1954 et internationalisation (1,5), 1958 et 1959 (1,5), Évian et indépendance (1,5), conséquences (0,5), organisation et neutralité (0,5). »
  - Après : « Corrigé modèle : L'Algérie, conquise à partir de 1830, est une colonie de peuplement où les musulmans ont moins de droits que les colons. Des courants nationalistes apparaissent : Messali Hadj réclame l'indépendance, Ferhat Abbas l'égalité, les oulémas défendent l'identité arabe et musulmane. Le 8 mai 1945, des manifestations à Sétif et Guelma sont suivies de violences et d'une répression ; le bilan humain est discuté. Le 1er novembre 1954, le FLN et l'ALN lancent la guerre, qui s'internationalise (ONU en 1955, bases arrière au Maroc et en Tunisie). Après la crise du 13 mai 1958, de Gaulle revient au pouvoir ; le GPRA est proclamé ; en 1959, de Gaulle propose l'autodétermination, malgré l'opposition de l'OAS. Les accords d'Évian (18 mars 1962), les référendums et la proclamation du 5 juillet 1962 mènent à l'indépendance, avec le départ des rapatriés et le sort difficile des harkis. Barème : inégalités et courants (1,5), Sétif et Guelma (1), 1954 et internationalisation (1,5), 1958 et 1959 (1,5), Évian et indépendance (1,5), conséquences (0,5), organisation et neutralité (0,5). »

### 2nde · Histoire-Géographie · Histoire — Les méthodes d'étude de l'histoire (`docs/contenus/lecons-traitees/2nde/histoire-geographie/histoire-les-methodes-d-etude-de-l-histoire.json`)

- **Lieu** : sujet 4 (« Sujet 4 · Bilan : sources, critique et repères chronologiques ») › exercice 4 (« Exercice 4 ») › question 3, champ answers
  - Avant : « [{"content": "histoire", "correct": true}] »
  - Après : « [{"content": "histoire", "correct": true}, {"content": "Antiquité", "correct": true}] »
- **Lieu** : sujet 4 (« Sujet 4 · Bilan : sources, critique et repères chronologiques ») › exercice 4 (« Exercice 4 ») › question 3, champ explanation
  - Avant : « Méthode : 1) Rappeler la distinction. 2) Avant l'écriture : préhistoire. 3) Après : histoire. »
  - Après : « Méthode : 1) Rappeler la distinction. 2) Avant l'écriture : préhistoire. 3) Après : histoire, dont la première période est l'Antiquité ; les deux réponses sont acceptées. »

## EDHC et Philosophie

Fichiers modifiés présents sur `origin/main` seulement. Les leçons de 4ème EDHC et la leçon de 1ère Philosophie « La période antique », corrigées aussi, ne sont pas sur `origin/main`.

### 3ème · EDHC · Le civisme fiscal (`docs/contenus/lecons-traitees/3eme/edhc/le-civisme-fiscal.json`)

- **Lieu** : notion « Distinguer l'impôt et la taxe », champ remember
  - Avant : « Une **taxe** est une somme payée en **échange d'un service ou d'un usage précis**, par exemple la place occupée au marché ou l'enlèvement des ordures. »
  - Après : « Une **taxe** est une somme obligatoire **liée à un service ou à un usage précis**, par exemple la place occupée au marché ou l'enlèvement des ordures ; son montant n'est pas forcément égal au coût du service. »
- **Lieu** : notion « Distinguer l'impôt et la taxe » › exercice 2 (« Classer des paiements en impôt, taxe ou don ») › question 3, champ content
  - Avant : « Une somme payée en échange d'un service précis rendu à celui qui paie s'appelle une ___. »
  - Après : « Une somme obligatoire liée à un service ou à un usage précis s'appelle une ___. »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 1, champ statement
  - Avant : « Elle rappelle qu'un impôt est un prélèvement obligatoire versé à l'État ou à une collectivité pour financer les dépenses publiques, et qu'une taxe est payée en échange d'un service ou d'un usage précis. »
  - Après : « Elle rappelle qu'un impôt est un prélèvement obligatoire versé à l'État ou à une collectivité pour financer les dépenses publiques, et qu'une taxe est une somme obligatoire liée à un service ou à un usage précis. »
- **Lieu** : sujet 1 (« Sujet 1 · Les savoirs de base ») › exercice 1 › question 4 › proposition 2, champ content
  - Avant : « Somme payée en échange d'un service précis »
  - Après : « Somme obligatoire liée à un service précis »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier ») › exercice 1 › question 2 › proposition 1, champ content
  - Avant : « La taxe est payée en échange d'un service précis, l'impôt n'a pas de contrepartie directe »
  - Après : « La taxe est liée à un service précis, l'impôt n'a pas de contrepartie directe »

### Tle A1 · Philosophie · Progrès et bonheur (`docs/contenus/lecons-traitees/tle-a1/philosophie/progres-et-bonheur.json`)

- **Lieu** : notion « Qu'est-ce que le bonheur ? », champ remember
  - Avant : « Pour Épicure (« Lettre à Ménécée », vers 300 av. J.-C.), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
  - Après : « Pour Épicure (« Lettre à Ménécée »), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
- **Lieu** : notion « Qu'est-ce que le bonheur ? » › exercice 1 (« Distinguer plaisir, désirs et bonheur ») › question 5, champ content
  - Avant : « Dans la « Lettre à Ménécée », Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
  - Après : « Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier sur le progrès et le bonheur ») › exercice 3 › question 4, champ explanation
  - Avant : « Il ne s'agit ni d'Épicure, dont la « Lettre à Ménécée » date d'environ 300 av. J.-C., ni de Kant. »
  - Après : « Il ne s'agit ni d'Épicure, qui a vécu de 341 à 270 av. J.-C., ni de Kant. »

### Tle A2 · Philosophie · Progrès et bonheur (`docs/contenus/lecons-traitees/tle-a2/philosophie/progres-et-bonheur.json`)

- **Lieu** : notion « Qu'est-ce que le bonheur ? », champ remember
  - Avant : « Pour Épicure (« Lettre à Ménécée », vers 300 av. J.-C.), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
  - Après : « Pour Épicure (« Lettre à Ménécée »), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
- **Lieu** : notion « Qu'est-ce que le bonheur ? » › exercice 1 (« Distinguer plaisir, désirs et bonheur ») › question 5, champ content
  - Avant : « Dans la « Lettre à Ménécée », Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
  - Après : « Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier sur le progrès et le bonheur ») › exercice 3 › question 4, champ explanation
  - Avant : « Il ne s'agit ni d'Épicure, dont la « Lettre à Ménécée » date d'environ 300 av. J.-C., ni de Kant. »
  - Après : « Il ne s'agit ni d'Épicure, qui a vécu de 341 à 270 av. J.-C., ni de Kant. »

### Tle C · Philosophie · Progrès et bonheur (`docs/contenus/lecons-traitees/tle-c/philosophie/progres-et-bonheur.json`)

- **Lieu** : notion « Qu'est-ce que le bonheur ? », champ remember
  - Avant : « Pour Épicure (« Lettre à Ménécée », vers 300 av. J.-C.), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
  - Après : « Pour Épicure (« Lettre à Ménécée »), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
- **Lieu** : notion « Qu'est-ce que le bonheur ? » › exercice 1 (« Distinguer plaisir, désirs et bonheur ») › question 5, champ content
  - Avant : « Dans la « Lettre à Ménécée », Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
  - Après : « Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier sur le progrès et le bonheur ») › exercice 3 › question 4, champ explanation
  - Avant : « Il ne s'agit ni d'Épicure, dont la « Lettre à Ménécée » date d'environ 300 av. J.-C., ni de Kant. »
  - Après : « Il ne s'agit ni d'Épicure, qui a vécu de 341 à 270 av. J.-C., ni de Kant. »

### Tle D · Philosophie · Progrès et bonheur (`docs/contenus/lecons-traitees/tle-d/philosophie/progres-et-bonheur.json`)

- **Lieu** : notion « Qu'est-ce que le bonheur ? », champ remember
  - Avant : « Pour Épicure (« Lettre à Ménécée », vers 300 av. J.-C.), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
  - Après : « Pour Épicure (« Lettre à Ménécée »), le bonheur est un plaisir stable : l'absence de douleur dans le corps et de trouble dans l'âme (la tranquillité, ou *ataraxie*). »
- **Lieu** : notion « Qu'est-ce que le bonheur ? » › exercice 1 (« Distinguer plaisir, désirs et bonheur ») › question 5, champ content
  - Avant : « Dans la « Lettre à Ménécée », Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
  - Après : « Épicure appelle désirs ___ ceux qui ne sont ni naturels ni nécessaires, comme la gloire à tout prix. »
- **Lieu** : sujet 3 (« Sujet 3 · Raisonner et justifier sur le progrès et le bonheur ») › exercice 3 › question 4, champ explanation
  - Avant : « Il ne s'agit ni d'Épicure, dont la « Lettre à Ménécée » date d'environ 300 av. J.-C., ni de Kant. »
  - Après : « Il ne s'agit ni d'Épicure, qui a vécu de 341 à 270 av. J.-C., ni de Kant. »

### 3ème · EDHC · Les institutions juridictionnelles (`docs/contenus/lecons-traitees/3eme/edhc/les-institutions-juridictionnelles.json`)

- **Lieu** : problème 4 (« Contester une décision de l'administration ») › question 5, champ explanation
  - Avant : « Barème : 1 point par critère, 4 points au plus. »
  - Après : « Barème : 1 point pour la position, 1 pour le recours au juge, 1 pour l'indépendance du juge, 0,5 pour l'égalité devant la justice, 0,5 pour la clarté (total 4 points). »


