# Journal — Les 5 premières leçons de 5ème

> Contenu seul : ni memo ni UDR. Méthode des 60 leçons de 3ème ([`lecons-3eme-comme-thales`](../lecons-3eme-comme-thales/journal.md)), format v3 complet de [`prompt-redaction.md`](../../contenus/prompt-redaction.md).

## Périmètre

Leçons 1 à 5 de la progression DPFC 2026-2027 de 5ème, en Mathématiques, Français, Physique-Chimie, SVT, Histoire-Géographie et EDHC : 30 leçons, rangées dans `docs/contenus/lecons-traitees/5eme/<matière>/`. L'anglais n'en fait pas partie.

| Lot | Matières | Contrôle du fond |
|---|---|---|
| A | Mathématiques, Physique-Chimie | sympy sur chaque calcul |
| B | Français, SVT | extrait de la fiche pour chaque bonne réponse |
| C | Histoire-Géographie, EDHC | extrait de la fiche pour chaque bonne réponse |

Chaque leçon : un rédacteur, puis un relecteur indépendant qui refait chaque calcul et chaque analyse. Le script hors dépôt passe `valider.rb` sur le fichier et sur chaque sujet mis à la place des 4 problèmes, puis les règles que `valider.rb` ne vérifie pas (2e exercice, « Je m'entraîne », sujets, doublons, `$` hors calcul).

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Entrées `5eme/<matière>` du jeu standard ajoutées en fin de liste `lecons`, avec la leçon 1 | `StandardTestSet` refuse un couple qui a du v3 sans entrée ; en fin de liste, les leçons du test d'activité réduite ne bougent pas | Non |
| 2026-11-14 | Une pile retournée n'est jamais une solution, seulement une panne (PC 3) ; opposition limitée à 2 piles ou à une seule pile à l'envers sur 3-4 | En circuit fermé, la pile retournée est forcée à l'envers ; la fiche ne pose la règle que pour 2 piles | Non |
| 2026-11-14 | Les règles que le rédacteur oubliait sont passées dans le script de contrôle : décimal d'un `fill_blank` accepté avec virgule et point, correction qui ne désigne pas une proposition par son rang | Deux relectures les ont trouvées ; l'application mélange les propositions et ne convertit pas la virgule | Non |

## Ce qui a dérapé

- Lot A : la relecture indépendante a trouvé de 11 à 27 défauts par leçon, dont 0 à 7 « faux » : corrections qui parlaient d'un autre appareil (PC 1), triangles impossibles et symétrique faux (Maths 5), données qui contredisaient l'énoncé (Maths 3), voltmètre en série « qui ne donne pas la tension » (PC 5), pile retournée présentée comme solution (PC 3). Tous corrigés, contrôle relancé jusqu'à ✓.
- La limite de quota a coupé tous les rédacteurs une fois ; ils ont repris là où ils étaient.

## Ce qu'on a appris sur la codebase

- Develop charge tous les dossiers de `lecons-traitees/` ; `V3ProgrammeLevels` liste déjà `5eme` pour Staging.
- Le jeu standard exige une entrée `lecons` par couple niveau-matière qui a du v3 (`StandardTestSet#forgotten_couples`) : sans elle, `standard_manifest_test.rb` échoue.

## À trancher

Choix prudents appliqués, à valider par un enseignant de la matière.

**Mathématiques**
- Nombres premiers : PGCD et PPCM non traités ; crible d'Ératosthène, test « on divise jusqu'à ce que le quotient soit plus petit que le diviseur », notation puissance, unicité de la décomposition ; nombres jusqu'à 1 000 dans les sujets 3 et 4.
- Segments : la réciproque de la médiatrice (PA = PB ⇒ P sur la médiatrice) est utilisée ; notion AB = AC + CB ajoutée ; codage des longueurs égales ; arcs de compas dessinés en cercles entiers (limite de la sorte de figure).
- Angles : réciproque du parallélisme (alternes-internes ou correspondants égaux ⇒ parallèles) utilisée ; bissectrice au rapporteur seulement ; alternes-externes non traités.
- Nombres décimaux relatifs : multiplication, somme algébrique et repère du plan non traités ; « abscisse » employé ; zéro sans signe ; seul le signe « − » typographique et le « - » du clavier sont acceptés.
- Symétrie axiale : axes du rectangle et du carré pris comme acquis ; lettres capitales sans empattement ; repère à coordonnées entières.

**Physique-Chimie**
- Aucune sorte de figure ne dessine un schéma électrique : circuits décrits en mots ou en `diagram`.
- Adaptation : vocabulaire « sous-voltée / survoltée » ; phrase de sécurité sur le courant du secteur.
- Lampes : éclat seulement qualitatif ; circuits mixtes et guirlandes composées (sujets 3 et 4) à la limite haute de la 5ème, sans question d'éclat.
- Piles en série : termes « association concordante » et « en opposition » ; décision prudente sur la pile retournée (voir Décisions).
- Intensité : multimètre numérique seulement (pas d'aiguille) ; calibres 10 A, 200 mA, 20 mA ; borne COM côté − ; loi des nœuds sur deux branches ; montage mixte du problème 4 et du sujet 4.
- Tension : calibres 200 mV à 200 V et règle du plus petit calibre supérieur ; interrupteur ouvert à la tension du générateur et lampe éteinte à 0 V, posé en notion 3 avant l'additivité ; additivité à 3 dipôles.
- Toutes les valeurs d'appareils, de piles et de lignes sont illustratives.

## Clôture
