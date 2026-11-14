# Journal — Les 5 premières leçons de 6ème

> Contenu seul (pas de memo ni d'UDR). Demande du porteur, relayée par l'orchestrateur le 2026-11-13 : 5 leçons par matière.
> Méthode : celle des 60 leçons de 3ème (`docs/contenus/prompt-redaction-lot.md`, format v3 complet), au niveau 6ème.

## Périmètre

Rangs 1 à 5 de la progression DPFC 2026-2027 de 6ème, en Mathématiques, Français, Physique-Chimie, SVT,
Histoire-Géographie et EDHC : 30 leçons, rangées dans `docs/contenus/lecons-traitees/6eme/<matière>/`.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-13 | Les couples `6eme/<matière>` sont ajoutés à la fin de `lecons:` dans `db/seeds/standard/jeu.yml` | Sans eux, `StandardTestSet` refuse le manifeste (`couple_missing`) ; en fin de liste, les 27 premières leçons du test d'activité ne bougent pas | Non |
| 2026-11-14 | `PRD_COUPLES` du test du manifeste suit le nombre de couples (57 au lot A, 59 au lot B ; 65 après la fusion de Develop, qui apporte les 6 couples de 4ème ; 67 au lot C) | Le test compte les couples du jeu standard | Non |

## Ce qui a dérapé

## À trancher

> **Tranché le 2026-11-14** par le validateur pédagogique (chantier [`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur), ADR-XXXX-validateur-pedagogique-agent). Chaque point ci-dessous a sa décision (Confirmé, Corrigé, Retiré ou reformulé, Hors base) et sa justification dans la table de sa matière. Plus aucun point n'attend d'enseignant.

À faire valider par un enseignant de la matière avant publication.

- PC L1 circuit : symboles pile/lampe/moteur décrits en mots (aucune sorte de figure « circuit ») ; moteur en leçon 1 ?; liste des conducteurs/isolants.
- Maths L4 segments : médiatrice non traitée ; report au compas sans « cercle » (leçon 7) ; hm/dam dans le tableau.
- Maths L5 pavés/cylindres : aucun calcul d'aire ni de volume du cylindre (disque = leçon 7) ; aire totale du pavé $2(Ll+Lh+lh)$ à confirmer en 6ème ; pas de 1 dm³ = 1 L.
- Maths L2 droites et points : perpendiculaires et parallèles traitées ici (peut-être leçon 8 « Angles ») ; notations [AB), ∈, ⊥, ∥ ; pas de figure de demi-droite (sorte geometry) ; figures à 9 points (lisibilité 390 px).
- Maths L3 relatifs : pas d'addition/soustraction (5ème ?) ; « distance à zéro » gardée légère ; vocabulaire « abscisse », « +3 = 3 ».
- Maths L1 entiers : division euclidienne, multiples, diviseurs non traités ; classes, « pas », « abscisse » ; droites graduées bornées à 100 (sorte number_line).
- Maths L3 relatifs : le signe de 0 n'est pas tranché (« 0 s'écrit sans signe ; il est son propre opposé ») : les manuels divergent (ni positif ni négatif / les deux). Confirmer la convention du manuel ivoirien.
- PC L2 commande : série/dérivation et va-et-vient non traités ; symbole de l'interrupteur décrit en mots, celui du bouton-poussoir non décrit.
- PC L3 court-circuit : surcharge de multiprise présentée comme règle de prudence ; disjoncteur près du compteur CIE ; gestes de sécurité écrits pour un enfant (à relire) ; prix illustratifs.
- PC L4 solides et liquides : volume d'un solide par déplacement d'eau inclus (notion 4) — à retirer s'il n'est pas dans cette leçon ; lecture au bas du ménisque (eau).
- PC L5 gaz : masse de l'air ≈ 1,3 g/L présentée comme approchée (à retirer si hors leçon) ; composition de l'air non traitée ; conduite à tenir en cas d'odeur de gaz.
- Pas de sorte de figure « schéma électrique » : les symboles (pile, lampe, moteur, interrupteur) sont décrits en mots, les figures sont des schémas fléchés (diagram). Une sorte « circuit » serait à demander.
- Français L1 la phrase : phrase simple/complexe au niveau découverte (un verbe conjugué = simple) ; « impérative (injonctive) » couvre des phrases non verbales.
- Français L3 lettre : registres familier et courant seulement ; tutoiement d'un grand-parent présenté comme usage ; barème des 2 written (4 et 8 points).
- Français L2 dialogue oral : notion 5 « écrire un dialogue » (tirets, guillemets, incise) rattachée à la leçon 2 ; découpage en 5 notions.
- Français L4 œuvre intégrale : aucune œuvre réelle (la liste officielle n'est pas dans la progression) : contes et auteurs imaginaires écrits pour Lnclass, à remplacer par l'œuvre choisie par l'établissement ; schéma narratif en 5 étapes supposé au programme de 6ème ; « aide »/« opposant » au lieu d'« adjuvant » ; morales proposées parmi d'autres.
- Français L5 orthographe lexicale : homophones lexicaux non traités ; circonflexe expliqué par un s ancien ; règle é/è simplifiée.
- SVT L1 actions néfastes : définitions (environnement, action néfaste, cause, conséquence) de rédaction ; érosion et humus évités ; caniveaux d'Abidjan vers la lagune écrit avec « peuvent ».
- SVT L2 lutte : « comité d'hygiène » défini de façon générique ; tri en trois groupes (organiques, qui ne pourrissent pas, dangereux), papier/carton absents ; durée du compost non chiffrée.
- SVT L3 facteurs de croissance : germination non traitée (leçon 6) ; signes d'un plant privé de lumière, chaleur excessive, compost comme apport de sels minéraux à confirmer ; photosynthèse et excès d'eau écartés.
- SVT L4 aliments : vocabulaire « bâtisseurs / énergétiques / fonctionnels » (la 3ème dit « protecteurs ») ; classement niébé, poisson, œuf, lait / huile de palme, beurre / fruits, légumes à confirmer.
- SVT L5 graine : pas de planche de fleur (schéma en arbre) ; fécondation définie très simplement ; fruits au sens botanique (tomate, piment) ; expérience du filet à mailles fines.
- Français L4 : les morales et le découpage du schéma narratif de chaque conte sont des propositions parmi d'autres.
- Les valeurs des exercices (prix, mesures, masses) sont illustratives ; les textes supports sont écrits pour Lnclass.
- `valider.rb` ne contrôle pas les sujets : un script hors dépôt les a passés un par un (dette à reprendre dans le script).
- HG L1 et L2 : siècles, durées et frise renvoyés à la leçon 7 « La notion de chronologie » ; échelle, plan, légende et rose des vents renvoyés à la leçon 10 « Les moyens de représentation de la terre ». Les leçons 1 et 2 traitent l'objet de la discipline (définition, domaines, importance). À confirmer avec le programme.
- HG L3 sources : sources audiovisuelles non traitées ; archéologiques et iconographiques dans une même notion ; témoin direct/indirect au niveau 6ème ?
- HG L4 relief : aucune altitude réelle (valeurs illustratives) ; définitions de colline et plateau sans seuil ; contours de la carte schématiques.
- HG L5 information et dignité : fait/opinion/rumeur, « au moins deux sources sûres » (règle pratique), droit humanitaire non nommé (traité en EDHC leçon 3).
- HG L5 : DUDH (1948), Convention relative aux droits de l'enfant (1989) et Conventions de Genève nommées sans article ; leur place en 6ème (recoupe EDHC leçons 2 et 3) à confirmer.
- EDHC L1 droits de l'enfant : relais (centre social, services sociaux, chef de quartier) génériques ; travail interdit défini par trois critères, sans âge minimum ni loi ; distinction besoin/envie.
- EDHC2 (Les droits humains) : la Déclaration universelle est citée par sa date (1948) et son idée « libres et égaux en dignité et en droits », sans article ; exemples de devoirs et motifs de traitement différencié « justes » (gravité de la maladie, notes) choisis par la rédaction ; découpage en 4 notions non officiel.
- EDHC3 (DIH) : Conventions de Genève de 1949 sans article ; signature et ratification par la Côte d'Ivoire à confirmer ; « biens civils » et conflit non international évoqués, peut-être au-delà de la 6ème ; cristal rouge volontairement omis ; missions de la Croix-Rouge de Côte d'Ivoire (secours, secourisme) à confirmer.
- EDHC4 (La Constitution) : sens des mots de la devise = formulations pédagogiques ; drapeau décrit orange-blanc-vert « de gauche à droite », sans le sens des couleurs ; se tenir debout et silencieux pendant l'hymne = règle civique générale.
- EDHC5 (Le Président de la République) : mandat écrit seulement « élu pour 5 ans, rééligible une fois », sans durée maximale déduite ; « garant de la Constitution » remplacé par « veille au respect de la Constitution et incarne l'unité nationale » (à confirmer selon le programme) ; Vice-Président réduit à « aide le Président », sans remplacement ni désignation (révision de 2020 à confirmer) ; promulgation sans délai ni procédure ; « Constitution de 2016 » sans « (révisée) ».
- EDHC3 (suite relecture) : la Côte d'Ivoire « s'est engagée à respecter » les Conventions (adhésion de 1961, à confirmer) ; cristal rouge présenté en une phrase (losange rouge) ; FICR ajoutée au schéma du Mouvement, peut-être au-delà de la 6ème.
