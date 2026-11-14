# Journal — Leçons 4 et 5 de la 2nde

> Contenu seul (pas de memo ni d'UDR). Demande du porteur : chaque matière à 5 leçons. Suite du chantier `lecons-1ere-2nde-debut` (leçons 1 à 3).

## Périmètre

Leçons 4 et 5 de la progression DPFC 2026-2027, format v3 complet (4 blocs, « Je m'entraîne » et 2 exercices par notion, 4 problèmes, 4 sujets de devoir) :

| Matière | Série | Leçon 4 | Leçon 5 |
|---|---|---|---|
| Français | A, C (commun) | Les outils de l'argumentation | Groupement de textes poétiques |
| Mathématiques | A | Équations et inéquations dans ℝ | Généralités sur les fonctions |
| Mathématiques | C | Généralités sur les fonctions | Droites et plans de l'espace |
| Physique-Chimie | A, C (commun) | Actions mécaniques ou forces | Classification périodique des éléments chimiques |
| SVT | A | La production de la matière organique | Le changement climatique |
| SVT | C | Le devenir des substances absorbées par la plante verte | Les relations entre les êtres vivants dans un écosystème |
| Histoire-Géographie | commune | Géographie — La planète terre | Histoire — La méthodologie de la dissertation, du commentaire de document et de la situation d'évaluation |

14 leçons distinctes, 18 fichiers. Généralités sur les fonctions est écrite séparément en A et en C (programmes différents).

## Méthode

Un rédacteur par leçon (6 en parallèle au plus), puis une relecture IA indépendante qui refait chaque calcul (sympy en Mathématiques et Physique-Chimie). Contrôle hors dépôt : `valider.rb` sur la leçon et sur chaque sujet mis à la place des problèmes, format Thalès, aucune formule en ligne de 40 caractères ou plus (débordement à 390 px, leçon du correctif #573).

## Ce qui a dérapé

- **Limite d'usage atteinte** en cours de vague : 9 agents (rédacteurs et relecteurs) coupés ensemble, repris après la remise à zéro sans rien perdre des fichiers déjà écrits.
- **Scratchpad partagé** : deux rédacteurs de SVT ont pris le même sous-dossier ; l'un a réécrit ses scripts à l'identique. Les fichiers livrés n'en ont pas souffert (relus ensuite). À retenir : un sous-dossier par leçon, nommé dans la consigne.
- **La relecture a trouvé des défauts dans chaque leçon** (3 à 31 corrections) : distracteurs incohérents, figures `number_line` dessinant une borne finie sur un intervalle infini, témoin d'expérience inversé, « amidon transporté par la sève élaborée », vers faux de 9 syllabes dans un sonnet d'octosyllabes, zone tempérée « entre l'équateur et les pôles ». Tous corrigés ; aucun calcul faux en Mathématiques ni en Physique-Chimie.
- **Sorte `solid`** : elle ne dessine que pyramides et cônes, sans nom de sommet ; les exercices sur le cube (Droites et plans de l'espace) sont sans figure. Demande de sorte nouvelle possible (cube ou pavé à sommets nommés).

## À trancher

Options prudentes appliquées ; un enseignant de la matière relit avant publication. Partout : les valeurs chiffrées des énoncés (mesures, prix, données d'expérience, relevés) sont fictives.

### Français (A et C)

- **Les outils de l'argumentation** : « Convaincre ou persuader » et « Le plan d'un texte argumentatif » (plans dialectique et thématique) retenues comme notions probables ; quatre types d'arguments (autorité, exemple, logique, analogie), le témoignage classé comme exemple, l'ad hominem traité comme une erreur ; « pourtant » et « mais » en opposition même après « il est vrai que », « certes… mais », « bien que », « même si » en concession ; la question rhétorique citée comme procédé.
- **Groupement de textes poétiques** : deux quatrains du domaine public (Hugo, « Demain, dès l'aube » ; Verlaine, « Il pleure dans mon cœur »), vérifiés mot à mot, le reste écrit pour Lnclass ; règle classique du e muet (-es compté devant voyelle, sauf en fin de vers) ; une rime masculine et une rime féminine ne riment pas ensemble ; rimes pour l'oreille d'orthographes différentes ; diérèse et synérèse non traitées ; noms des vers (hexasyllabe à alexandrin) employés ; la comparaison sert de repère de lecture.

### Mathématiques

- **2nde A, Équations et inéquations dans ℝ** : tableau de signes d'un quotient (valeur interdite) et d'un produit de 3 facteurs (sujet 4) ; équations sans solution ou vérifiées par tout réel ; réunion d'intervalles et $\varnothing$ ; équations produit ramenées au facteur commun ou à $a^2-b^2$, sans discriminant.
- **2nde A, Généralités sur les fonctions** : « croissante » défini sans inégalité formelle (« la courbe monte ») ; antécédents de fonctions du second degré par factorisation donnée sans méthode (ex. $2x^2-3x-2=(2x+1)(x-2)$) ; une équation avec quotient ; racine carrée, valeur absolue et parité non traitées ; variations lues sur 7 points.
- **2nde C, Généralités sur les fonctions** : sens de variation par le signe de $f(b)-f(a)$, sans taux de variation ; fonctions affines et $ax^2+c$, plus deux trinômes factorisés ($x^2-6x+5$, $x^2-4x+3$) proches de la leçon 6 ; parité, égalité de fonctions et résolutions graphiques non traitées ; quelques modèles fictifs sortent de leur contexte (antécédent −3 pour un nombre de spectateurs) ; la différence de buts par journée est tracée en ligne continue.
- **2nde C, Droites et plans de l'espace** : théorème du toit et critère de parallélisme de deux plans dans la fiche ; orthogonalité non traitée ; section hexagonale du cube en QCM ; cube décrit dans l'énoncé (ABCD en bas, EFGH au-dessus), sans figure.
- **Commun** : les courbes sont des lignes brisées (pas de sorte « courbe lisse »).

### Physique-Chimie (A et C)

- **Actions mécaniques ou forces** : g = 10 N/kg partout ; « centre de gravité » comme point d'application du poids ; vent sur une voile, plateau sous un sac classés en contact réparti ; le dynamomètre « indique le poids » d'un corps suspendu immobile, sans parler d'équilibre (leçon suivante) ; une planète fictive à g = 4 N/kg.
- **Classification périodique** : colonnes numérotées 1 à 8 (nombre d'électrons de valence, hélium avec les gaz rares) ; quatre familles seulement ; K et Ca cités sans structure électronique ; hydrogène dit non alcalin.

### SVT

- **2nde A, La production de la matière organique** : bilan en mots seulement ; élodée dans de l'eau bouillie puis refroidie présentée comme privée de CO₂ dissous ; bulles divisées par deux quand la distance de la lampe double (valeurs fictives, la baisse réelle est plus forte).
- **2nde A, Le changement climatique** : climat sur « plusieurs dizaines d'années » (sans « 30 ans ») ; montée de la mer par dilatation et fonte des glaces continentales ; vapeur d'eau citée comme gaz à effet de serre ; méthane attribué surtout à l'élevage et aux décharges ; « risque de faim » comme conséquence d'une sécheresse (proche de la leçon sur l'alimentation) ; Korhogo, Abidjan, Grand-Lahou comme exemples généraux.
- **2nde C, Le devenir des substances absorbées** : photosynthèse gardée, réduite à son lien avec la sève brute et l'amidon ; sels minéraux cités comme matière première ; liber non situé précisément dans l'écorce ; potomètre sur rameau sans racines ; vitesse de montée du colorant (3 à 8 cm/h) très lente.
- **2nde C, Les relations entre les êtres vivants** : lichen et nodosités des légumineuses comme symbioses, symbiose assimilée au mutualisme ; orchidée sur un arbre comme commensalisme ; compétition notée « − / − » ; soleil classé dans le biotope ; pyramide écologique non traitée ; relations intraspécifiques en une phrase.

### Histoire-Géographie

- **La planète terre** : l'heure d'avance de Paris sur Abidjan en décembre vient du fuseau légal (la longitude seule ne donne qu'environ 25 min) ; la leçon la relie à la rotation, cadrage scolaire habituel, sans fuseaux ni heure d'été ; durées du jour arrondies ; 8 planètes, noyau de fer et de nickel, hydrosphère « environ 70 % » ; zones climatiques sans tropiques ; atmosphère décrite comme faite surtout d'azote et d'oxygène.
- **La méthodologie de la dissertation…** : format de la situation d'évaluation DPFC gardé général (contexte, support, consignes, verbes citer, définir, décrire, expliquer, montrer) ; développement en deux ou trois parties, introduction en 4 éléments, plans chronologique ou thématique ; commentaire en 5 étapes (présenter, situer, dégager, expliquer, apprécier), synthèse et non libellé officiel ; documents d'appui fictifs ; seule date réelle : 7 août 1960.

### Figures

- La sorte `solid` ne dessine que pyramides et cônes, sans nom de sommet : demande possible d'une sorte « cube ou pavé à sommets nommés ».
