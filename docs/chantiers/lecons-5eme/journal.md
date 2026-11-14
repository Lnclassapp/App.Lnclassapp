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
- Lot B : 0 à 4 « faux » par leçon, surtout des corrections qui réfutaient une proposition retirée pour tenir sous 230 000 octets (SVT 3 : 46 cas), et des conclusions contraires aux données (SVT 4 : humidité « favorable » alors que le lot sans eau est à zéro). Tous corrigés, contrôle relancé jusqu'à ✓.
- La limite de quota a coupé les rédacteurs deux fois ; ils ont repris là où ils étaient.
- Le script de contrôle supprimait « œ » dans le nom attendu du fichier ; corrigé en « oe », comme la 3ème.
- Lot C : 0 ou 1 « faux » par leçon sauf HG 4 (4 : deux explications du ‰ et deux figures qui contredisaient leur énoncé) ; en EDHC surtout des fuites, une question ou un indice qui donne la réponse d'une autre du même exercice (EDHC 4 : 18). La leçon HG 5 disait les Gur venus du Mali et du Burkina, la leçon 3 du seul Burkina : alignée. Tous corrigés, contrôle relancé jusqu'à ✓.
- Develop a reçu la 4ème (#591), la 6ème (#595) puis #587 pendant le chantier : intégrés par merge, tous les blocs gardés dans `jeu.yml`, `PRD_COUPLES` recalculé (73).

## Ce qu'on a appris sur la codebase

- Develop charge tous les dossiers de `lecons-traitees/` ; `V3ProgrammeLevels` liste déjà `5eme` pour Staging.
- Le jeu standard exige une entrée `lecons` par couple niveau-matière qui a du v3 (`StandardTestSet#forgotten_couples`) : sans elle, `standard_manifest_test.rb` échoue.

## À trancher

> **Tranché le 2026-11-14** par le validateur pédagogique (chantier [`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur), ADR-XXXX-validateur-pedagogique-agent). Chaque point ci-dessous a sa décision (Confirmé, Corrigé, Retiré ou reformulé, Hors base) et sa justification dans la table de sa matière. Plus aucun point n'attend d'enseignant.

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

**Français**
- Groupe nominal : articles contractés, numéraux et indéfinis mentionnés sans être testés ; critère « qui suivi du verbe, que suivi d'un sujet » ; adjectif épithète seulement.
- Exposé oral : « répondre aux questions » regroupé avec « présenter » ; règle « trois ou quatre idées pour cinq minutes » posée par la leçon, pas par le programme.
- Portrait : comparaison sans « comparé / comparant » ; portrait « neutre » nommé ; point de vue par comptage des mots positifs et négatifs ; « belle », « fine », « musclé » rangés en physique.
- Œuvre intégrale n°1 : œuvres réelles citées par titre, auteur et genre seulement (*Le Pagne noir*, *Les Contes d'Amadou Koumba*, *L'Enfant noir*, *Trois prétendants… un mari*) ; les autres sont inventées et annoncées comme telles ; « allié / adversaire » sans schéma actantiel ; l'œuvre étudiée en classe reste au choix de l'enseignant.
- Groupe adjectif : « apposé » aussi appelé « épithète détachée » ; superlatif relatif d'infériorité ; « pire » et « plus mauvais » acceptés ; « trop » adverbe d'intensité.

**SVT**
- Aucune planche ne montre l'animal ou le champignon : identification décrite en mots ou en `diagram`.
- Criquet : criquet puant non traité ; criquet et sauterelle distingués par les antennes ; phases solitaire et grégaire par leurs couleurs.
- Moustique : critères anophèle / culex / aedes ; « une à deux semaines » de l'œuf à l'adulte ; filariose non traitée.
- Lutte : larvicide, champignon contre les larves de criquet (une à deux semaines, sans danger pour l'homme et les animaux), poules et pintades en lutte biologique, résistance aux insecticides, conseils sur la moustiquaire imprégnée ; « larve » plutôt que « sauteriau ».
- Champignons : « carpophore » et « bouton » ; matière organique citée seulement comme condition favorable (la nutrition est une leçon suivante) ; spores qui « tombent » (simplification) ; aucune comestibilité affirmée.
- Croissance : « métamorphose incomplète » pour le criquet, la blatte, la sauterelle et le termite ; « larve » plutôt que « nymphe » pour leurs jeunes ; nymphe du moustique, asticot, abeille à métamorphose complète.
- Toutes les données d'élevage, de comptage et d'expérience sont des exemples écrits pour Lnclass.

**Histoire-Géographie**
- Premiers habitants : aucun site, peuple ancien ni date cités (l'enseignant ajoute ceux du manuel) ; pierre taillée puis polie, amas coquilliers du littoral, hache polie pour défricher ; « maîtres de la terre » selon les traditions orales ; documents et nombres de fouille inventés ; pas de frise, faute de dates sûres.
- Milieu physique : seuls chiffres 322 462 km² et mont Nimba 1 752 m ; noms des climats (attiéen, baouléen, soudanais, de montagne) ; littoral rocheux à l'ouest, lagunaire à l'est ; le fond de carte ne trace ni fleuves ni relief.
- Migrations : groupes Akan (est, actuel Ghana), Krou (ouest, actuel Liberia), Mandé (nord-ouest, actuels Mali et Guinée), Gur (nord, un peu nord-est, actuel Burkina Faso) ; « Gur » ici, « Gour » dans la leçon de 4ème ; Abla Pokou comme tradition, vers le XVIIIe siècle ; flèches dessinées vers Yamoussoukro (direction générale seulement).
- Croissance démographique : RGPH arrondis 6,7 / 10,8 / 15,4 / 22,7 / 29,4 millions (comme la 3ème) et sigle « … de l'habitat », de mémoire ; immigration burkinabè et malienne sans pourcentage ; « mariages précoces » parmi les causes de la natalité ; taux d'accroissement naturel (‰ → %), « urbanisation », « quartiers précaires » peut-être au-delà de la 5ème.
- Origine et installation des peuples : Akan (Baoulé, Agni, Abron), Krou (Bété, Dida, Wè, Kroumen), Mandé (Malinké, Dan, Gouro), Gur (Sénoufo, Lobi, Koulango), alors que l'ancien fichier v1 de 4ème mettait les Sénoufo avec les Mandé ; lagunaires « en général rattachés aux Akan » ; villes repères (Gouro à Bouaflé, Dida à Divo, Wè à Guiglo, Lobi et Koulango à Bouna, absente du fond de carte) ; récits d'installation écrits pour Lnclass.

**EDHC**
- Droits au développement et à la participation : santé et alimentation rangées dans la survie (classement UNICEF) ; 3 droits au développement et 4 à la participation, à rapprocher du manuel ; Convention de 1989, enfant de moins de 18 ans ; règles de vote laissées à une leçon suivante.
- Principes des droits humains : universalité, inaliénabilité, indivisibilité, interdépendance, égalité et non-discrimination (participation et responsabilité absentes) ; DUDH du 10 décembre 1948 citée sans article ; « seul un juge, selon la loi, peut limiter certains droits » ; eau, logement, circulation, presse présentés comme droits humains ; rampe et place devant présentées comme des aides, pas des discriminations.
- Victimes des conflits armés : quatre Conventions de Genève (1949), CICR, Croix-Rouge de Côte d'Ivoire ; aucun âge limite d'enrôlement ; cristal rouge non cité ; personnel de santé en catégorie à part (en droit strict, des civils) ; pays imaginaire, aucun conflit réel nommé.
- Le Parlement : Assemblée nationale et Sénat (Constitution de 2016) ; mandat de 5 ans pour les deux ; sénateurs élus « par exemple » par des conseillers municipaux et régionaux ; ministres « nommés par le Président » (la proposition du Premier ministre est omise) ; « juger revient aux juridictions » (la Haute Cour de justice n'est pas citée) ; nombres de sièges fictifs, signalés.
- Droits et devoirs du citoyen : un enfant ivoirien présenté comme « déjà citoyen », avec des droits et devoirs adaptés à son âge ; vote à 18 ans, sans « majorité civile » ; l'étranger ne vote pas (question limitée à la présidentielle) ; éligibilité citée sans âge ; respect du drapeau et de l'hymne dans le devoir de défendre la patrie ; voter présenté comme un devoir moral, sans dire si la loi l'impose.

## Clôture
