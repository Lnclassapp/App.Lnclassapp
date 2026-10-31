# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les fiches de cours de l'année, le **prompt** qui rédige une leçon complète (fiche de cours, fiches de révision, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 fiches de cours sans fiche de révision), à importer depuis **Imports → Fiches de cours complètes**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt unique et autoportant pour rédiger une leçon au **format v3**, dans les 6 matières du 1er cycle (section « Selon la matière » : ce que deviennent les blocs, textes et citations, faits et sources ; tous les types de questions de l'import, questions rédigées avec corrigé modèle, barème et critères, 50 % au moins corrigées automatiquement) : gabarit en 4 blocs par notion (À retenir, La méthode en étapes numérotées, Un exemple corrigé qui applique chaque étape, Le piège à éviter), un exercice par notion et 4 problèmes type interrogation/devoir de 3ème (BEPC), 5 questions au moins avec une correction qui refait la méthode, figures paramétrées (5 sortes). Il produit **un seul fichier** `lnclass.course-tree` version 3 |
| [`prompt-redaction-lot.md`](prompt-redaction-lot.md) | La version « lot par niveau » : pour une matière et un niveau (Français 3ème…), il prend les leçons de la progression, les rédige une par une avec `prompt-redaction.md`, les contrôle (script puis relecture IA indépendante) et les range dans `lecons-traitees/`. Un appel = une matière et un niveau |
| [`../../script/contenus/valider.rb`](../../script/contenus/valider.rb) | Le contrôle hors ligne d'un fichier v3 : `ruby script/contenus/valider.rb fichier.json`. Ruby pur, code de sortie 1 s'il y a une erreur. Mêmes règles et mêmes raisons que l'import (`format_retired`, `example_steps_mismatch`, `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`, `figure_invalid`, `figure_missing`…), plus des avertissements de rédaction |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt, un fichier `lnclass.course-tree` par fiche de cours complète, rangées par niveau et série, puis par matière. Pour l’instant `tle-d/` (18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Histoire-Géographie, Philosophie et Français ; les 10 leçons de Maths de Tle C et de Tle D au format 3) et `3eme/` (60 leçons au format 3, les 10 premières de la progression en Maths, Français, Histoire-Géographie, SVT, Physique-Chimie et EDHC) |

## Le principe

L'élève révise une leçon avant une interrogation, un devoir ou le BEPC : il doit **comprendre une méthode et savoir la réappliquer seul**. La même méthode, en étapes numérotées, sert trois fois : dans « La méthode » de la notion, dans l'exemple corrigé (l'étape *n* applique l'étape *n*) et dans la correction de chaque question d'exercice, avec les mêmes mots.

## Le pipeline d'une leçon

**rédaction → script → relecture IA → import en brouillon → validation équipe → publication**

1. **Rédiger.** Copier `prompt-redaction.md`, remplir son bloc **ENTRÉE** (intitulé exact de la progression, niveau, rang). Le résultat est un fichier JSON `lnclass.course-tree` version 3 : les versions 1 et 2 sont **retirées** et refusées à l'import (`format_retired`).
2. **Contrôler avec le script.** `ruby script/contenus/valider.rb fichier.json`. Il refuse ce que l'import refuserait (gabarit, `example_steps_mismatch`, `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`, correction absente `blank`, `too_short` ou `too_long`, figures hors règles), avec le code que l'import rend (test de parité `test/script/contenus/parite_import_test.rb`) et avertit des défauts de rédaction : correction qui ne cite aucune étape de La méthode, mots interdits, question qui dépend d'un élément absent. Il ne vérifie pas les calculs.
3. **Relecture IA indépendante.** Un autre modèle que l'auteur refait chaque calcul et vérifie que chaque correction suit la méthode. Les défauts sont corrigés, puis le script est relancé.
4. **Importer en brouillon** depuis l'écran **Imports**. Rien n'est visible des élèves. Une leçon encore en brouillon peut être réimportée (elle garde son adresse) ; une leçon publiée est refusée.
5. **Validation par l'équipe** dans l'application : la fiche de révision, les figures, les exercices et leurs corrections. Pour le pilote 3ème, un enseignant de mathématiques relit avant publication.
6. **Publier.**

Enfin, ranger le fichier dans `lecons-traitees/<niveau>-<série>/mathematiques/` et ajouter une ligne au tableau ci-dessous.

Les leçons déjà rangées dans `lecons-traitees/` au format v1 (Tle D, 3ème, etc.) ne sont plus importables : elles seront réécrites en v3, mathématiques d'abord (chantier `refonte-contenus-maths`).

## Ordre des imports (historique, formats v1)

> Cette section décrit les imports v1 des leçons rangées avant la refonte. Le format v3 remplace ce mode d'emploi pour les mathématiques : voir « Le pipeline d'une leçon ».

Un import ne met jamais à jour l'existant : une fiche de cours déjà présente (même nom, niveau, matière et série) est **ignorée** comme doublon, fiches de révision comprises. D'où l'ordre :

1. **D'abord les leçons traitées** (`lecons-traitees/`) : elles créent les fiches de cours complètes.
2. **Ensuite les progressions** (`progressions-2026-2027/`) : elles créent les autres fiches de cours de l'année, vides, et ignorent celles qui existent déjà.

Si la progression a déjà été importée, la fiche de cours de la leçon existe vide, et l'import de la fiche de cours complète sera ignoré. Une fiche de cours ne se supprime pas, et une fiche de cours archivée compte encore comme doublon. Il faut donc **renommer** la fiche de cours vide dans l'écran des fiches de cours (par exemple « Limites et continuité (vide) »), l'archiver, puis importer la fiche de cours complète.

## Leçons traitées

### Tle D — `lecons-traitees/tle-d/`

| Fichier | Fiche de cours | Fiches de révision | Exercices | Questions |
|---|---|---:|---:|---:|
| `mathematiques/limites-et-continuite.json` | Limites et continuité (Maths) | 3 | 9 | 51 |
| `mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json` | Probabilité conditionnelle et variable aléatoire (Maths) | 3 | 9 | 54 |
| `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions (Maths) | 3 | 9 | 51 |
| `physique-chimie/cinematique-du-point.json` | Cinématique du point (Physique) | 3 | 9 | 45 |
| `physique-chimie/les-alcools.json` | Les alcools (Chimie) | 3 | 9 | 54 |
| `physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide (Physique) | 4 | 12 | 60 |
| `svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères (SVT) | 3 | 9 | 53 |
| `svt/le-fonctionnement-des-organes-sexuels-chez-l-homme.json` | Le fonctionnement des organes sexuels chez l'Homme (SVT) | 3 | 9 | 54 |
| `svt/la-reproduction-chez-les-spermaphytes.json` | La reproduction chez les spermaphytes (SVT) | 3 | 9 | 54 |
| `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU | 3 | 9 | 53 |
| `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire | 3 | 9 | 52 |
| `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 | 3 | 9 | 53 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique | 3 | 9 | 52 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique | 3 | 9 | 54 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme | 3 | 9 | 52 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 3 | 9 | 54 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire | 3 | 9 | 52 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat | 3 | 9 | 51 |

Les 3 leçons de mathématiques de ce tableau (format v1) sont remplacées par leur version au format 3 : voir « Tle C et D, mathématiques au format 3 ».

Les 9 leçons d'Histoire-Géographie, de Philosophie et de Français ont d'abord eu **un exercice par fiche de révision** (format court de démonstration, 2026-10-06). Elles ont été **complétées le 2026-10-10** à 3 exercices par fiche de révision (Comprendre, Appliquer, S'évaluer), soit 54 exercices et 311 questions ajoutés, avec le prompt [`prompt-redaction.md`](prompt-redaction.md). Chacune a ensuite été relue par un second rédacteur (calculs refaits, dates et faits vérifiés), et les défauts trouvés ont été corrigés, dans l'ancien contenu comme dans le nouveau : par exemple « 17 États africains entrent à l'ONU en 1960 » (16 États africains, 17 nouveaux membres avec Chypre), la citation de Socrate donnée comme texte exact, ou « le dernier mot du poème » qui était l'avant-dernier vers. Les 18 leçons de Tle D passent `script/contenus/valider.rb` et s'importent ensemble sans erreur sur une base jetable : 18 cours, 55 fiches, 165 exercices, 949 questions, 3 835 propositions. Aucun enseignant ne les a encore relues.

**Attention à l'import.** Une fiche de cours déjà présente est ignorée, jamais mise à jour. Si l'ancienne version de ces 9 leçons est déjà dans une base (développement, Staging ou main), il faut **renommer puis archiver** l'ancienne fiche de cours avant d'importer la version complète.

À faire valider par un enseignant, en plus de la liste ci-dessous :

- **Histoire-Géographie** : « Les fondements du développement économique de la Côte d'Ivoire » traite aussi des limites du modèle (endettement, crise des années 1980, chômage), voulu par la fiche d'origine mais proche de la leçon 6.
- **Philosophie** : « La connaissance de l'homme » présente Durkheim et le fait social, proches de la leçon 4 (La vie en société). Le titre de sa dernière fiche parle de « la découverte de l'inconscient ». Dans « La dissertation philosophique » et « Le commentaire de texte philosophique », la méthode (problème, enjeu, plan dialectique) doit être cohérente avec celle de l'enseignant.
- **Français** : « Préparation à l'oral du Baccalauréat » décrit un déroulement de l'épreuve en quatre temps que personne n'a confronté au programme ivoirien ; sa méthode est proche du commentaire composé (leçon 4). Le niveau de certains sujets inventés de « La dissertation littéraire » est peut-être bas pour une Terminale.

Les 5 leçons 2 et 3 de Maths, de Physique et de SVT (2026-10-06) suivent le prompt complet, 3 exercices par fiche de révision. Elles ont été importées sans erreur par la vraie chaîne d'import. Aucun enseignant ne les a encore relues. « Mouvement du centre d'inertie d'un solide » a 4 fiches de révision : le mouvement circulaire uniforme, confirmé au programme par le porteur, en a une à lui.

Les 4 premiers fichiers ont été importés le 2026-09-29 sur une base neuve, par la vraie chaîne d'import, **sans aucune erreur** : 4 fiches de cours, 12 fiches de révision, 36 exercices, 203 questions, 786 propositions. Les progressions de Maths, Physique-Chimie et SVT importées ensuite ont ignoré ces 4 fiches de cours comme doublons et créé les autres.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches de révision. Dans « Dérivabilité et étude de fonctions », l'inégalité des accroissements finis et les dérivées successives ne le sont pas non plus (signalées dans le sous-titre de la dernière fiche de révision). Deux explications de « Limites et continuité » dépassent 400 caractères (450 et 444).
- **Physique** : il faut vérifier que le repère de Frenet et le recours à une primitive sont au programme.
- **Chimie** : il faut vérifier que la règle de Markovnikov est au programme. DNPH, Fehling et Schiff chevauchent peut-être la leçon suivante sur les aldéhydes et cétones.
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

### 6ème, 5ème et 4ème — `lecons-traitees/6eme/`, `5eme/`, `4eme/`

Les 3 premières leçons de chaque matière du 1er cycle (progression DPFC 2026-2027, rangs 1 à 3, sans série), rédigées le 2026-10-11 avec [`prompt-redaction.md`](prompt-redaction.md). Chaque fichier contient un cours : 3 fiches (2 ou 4 pour quelques leçons), 3 exercices par fiche, 5 à 6 questions par exercice. Chaque fichier passe `script/contenus/valider.rb`. Chaque leçon a été relue par un second rédacteur, qui a refait les calculs et vérifié les faits : les défauts trouvés ont été corrigés.

Au total : **54 cours, 160 fiches, 480 exercices, 2 612 questions**, réparties comme suit.

#### 6ème
| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `6eme/mathematiques/nombres-entiers-naturels.json` | Nombres entiers naturels | 3 | 9 | 54 |
| `6eme/mathematiques/droites-et-points.json` | Droites et points | 3 | 9 | 54 |
| `6eme/mathematiques/nombres-decimaux-relatifs.json` | Nombres décimaux relatifs | 3 | 9 | 54 |
| `6eme/physique-chimie/le-circuit-electrique.json` | Le circuit électrique | 3 | 9 | 54 |
| `6eme/physique-chimie/commande-d-un-circuit-electrique.json` | Commande d'un circuit électrique | 3 | 9 | 54 |
| `6eme/physique-chimie/court-circuit-et-protection-des-installations-electriques.json` | Court - circuit et protection des installations électriques | 3 | 9 | 54 |
| `6eme/svt/les-actions-nefastes-de-l-homme-et-leurs-consequences-sur-l-environnement.json` | Les actions néfastes de l'Homme et leurs conséquences sur l'environnement | 3 | 9 | 50 |
| `6eme/svt/la-lutte-contre-la-degradation-de-l-environnement.json` | La lutte contre la dégradation de l'environnement | 3 | 9 | 48 |
| `6eme/svt/les-facteurs-de-croissance-chez-les-plantes-a-fleurs.json` | Les facteurs de croissance chez les plantes à fleurs | 3 | 9 | 46 |
| `6eme/francais/la-phrase.json` | La phrase | 3 | 9 | 45 |
| `6eme/francais/le-dialogue-oral.json` | Le dialogue oral | 3 | 9 | 45 |
| `6eme/francais/la-lettre-personnelle.json` | La lettre personnelle | 3 | 9 | 45 |
| `6eme/histoire-geographie/histoire-l-histoire-et-son-objet.json` | Histoire — L'histoire et son objet | 3 | 9 | 52 |
| `6eme/histoire-geographie/geographie-la-geographie-et-son-objet.json` | Géographie — La géographie et son objet | 3 | 9 | 54 |
| `6eme/histoire-geographie/histoire-les-sources-de-l-histoire.json` | Histoire — Les sources de l'histoire | 4 | 12 | 70 |
| `6eme/edhc/les-droits-a-la-survie-et-les-droits-a-la-protection-de-l-enfant.json` | Les droits à la survie et les droits à la protection de l'enfant | 2 | 6 | 30 |
| `6eme/edhc/les-droits-humains.json` | Les droits humains | 2 | 6 | 30 |
| `6eme/edhc/le-droit-international-humanitaire-dih.json` | Le droit international humanitaire (DIH) | 3 | 9 | 45 |

#### 5ème
| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `5eme/mathematiques/nombres-premiers.json` | Nombres premiers | 3 | 9 | 48 |
| `5eme/mathematiques/segments.json` | Segments | 3 | 9 | 48 |
| `5eme/mathematiques/angles.json` | Angles | 3 | 9 | 47 |
| `5eme/physique-chimie/adaptation-d-un-generateur-a-un-recepteur.json` | Adaptation d'un générateur à un récepteur | 3 | 9 | 45 |
| `5eme/physique-chimie/association-de-lampes-electriques.json` | Association de lampes électriques | 3 | 9 | 45 |
| `5eme/physique-chimie/association-de-piles-en-serie.json` | Association de piles en série | 3 | 9 | 46 |
| `5eme/svt/les-consequences-de-la-proliferation-du-criquet.json` | Les conséquences de la prolifération du criquet | 3 | 9 | 54 |
| `5eme/svt/les-consequences-de-la-proliferation-du-moustique.json` | Les conséquences de la prolifération du moustique | 3 | 9 | 54 |
| `5eme/svt/la-lutte-contre-le-criquet-et-le-moustique.json` | La lutte contre le criquet et le moustique | 3 | 9 | 54 |
| `5eme/francais/le-groupe-nominal.json` | Le groupe nominal | 3 | 9 | 54 |
| `5eme/francais/l-expose-oral.json` | L'exposé oral | 3 | 9 | 54 |
| `5eme/francais/le-portrait.json` | Le portrait | 3 | 9 | 54 |
| `5eme/histoire-geographie/histoire-les-premiers-habitants-de-la-cote-d-ivoire.json` | Histoire — Les premiers habitants de la Côte d'Ivoire | 3 | 9 | 45 |
| `5eme/histoire-geographie/geographie-le-milieu-physique-en-cote-d-ivoire-et-l-installation-des-populations.json` | Géographie — Le milieu physique en Côte d'Ivoire et l'installation des populations | 3 | 9 | 45 |
| `5eme/histoire-geographie/histoire-les-premiers-mouvements-migratoires-en-cote-d-ivoire.json` | Histoire — Les premiers mouvements migratoires en Côte d'Ivoire | 3 | 9 | 45 |
| `5eme/edhc/les-droits-au-developpement-et-les-droits-a-la-participation-de-l-enfant.json` | Les droits au développement et les droits à la participation de l'enfant | 3 | 9 | 45 |
| `5eme/edhc/les-principes-des-droits-humains.json` | Les principes des droits humains | 3 | 9 | 45 |
| `5eme/edhc/les-regles-de-protection-des-victimes-des-conflits-armes.json` | Les règles de protection des victimes des conflits armés | 2 | 6 | 30 |

#### 4ème
| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `4eme/mathematiques/nombres-decimaux-relatifs.json` | Nombres décimaux relatifs | 3 | 9 | 53 |
| `4eme/mathematiques/angles.json` | Angles | 3 | 9 | 54 |
| `4eme/mathematiques/nombres-rationnels.json` | Nombres rationnels | 3 | 9 | 52 |
| `4eme/physique-chimie/sources-et-recepteurs-de-lumiere.json` | Sources et récepteurs de lumière | 3 | 9 | 45 |
| `4eme/physique-chimie/propagation-de-la-lumiere.json` | Propagation de la lumière | 3 | 9 | 45 |
| `4eme/physique-chimie/les-phases-de-la-lune-et-les-eclipses.json` | Les phases de la Lune et les éclipses | 3 | 9 | 45 |
| `4eme/svt/les-differentes-transformations-du-corps-humain-de-l-enfance-a-l-adolescence.json` | Les différentes transformations du corps humain de l'enfance à l'adolescence | 3 | 9 | 45 |
| `4eme/svt/le-devenir-des-cellules-sexuelles-chez-l-homme.json` | Le devenir des cellules sexuelles chez l'Homme | 3 | 9 | 45 |
| `4eme/svt/la-formation-des-roches-endogenes.json` | La formation des roches endogènes | 3 | 9 | 45 |
| `4eme/francais/le-groupe-nominal.json` | Le groupe nominal | 3 | 9 | 45 |
| `4eme/francais/le-debat-i.json` | Le débat I | 3 | 9 | 45 |
| `4eme/francais/le-texte-explicatif.json` | Le texte explicatif | 3 | 9 | 45 |
| `4eme/histoire-geographie/histoire-la-mise-en-place-des-peuples-de-cote-d-ivoire-du-xvie-au-xviiie-siecle.json` | Histoire — La mise en place des peuples de Côte d'Ivoire du XVIe au XVIIIe siècle | 3 | 9 | 48 |
| `4eme/histoire-geographie/geographie-la-deconcentration-administrative-en-cote-d-ivoire.json` | Géographie — La déconcentration administrative en Côte d'Ivoire | 3 | 9 | 48 |
| `4eme/histoire-geographie/histoire-l-organisation-sociopolitique-des-peuples-de-cote-d-ivoire.json` | Histoire — L'organisation sociopolitique des peuples de Côte d'Ivoire | 3 | 9 | 48 |
| `4eme/edhc/la-promotion-des-droits-de-l-enfant.json` | La promotion des droits de l'enfant | 3 | 9 | 54 |
| `4eme/edhc/la-lutte-contre-le-recrutement-des-enfants-soldats.json` | La lutte contre le recrutement des enfants soldats | 3 | 9 | 54 |
| `4eme/edhc/les-instruments-et-les-mecanismes-de-protection-contre-les-discriminations.json` | Les instruments et les mécanismes de protection contre les discriminations | 3 | 9 | 54 |

**Attention à l'import.** Les 54 fichiers dépassent la limite de 50 par import : envoyer en deux fois. La matière **EDHC** n'existe pas encore dans le référentiel Lnclass : les 9 cours d'EDHC (3 par niveau) seront rejetés (`unknown_material`) tant qu'elle n'est pas créée. Si la progression a déjà été importée, renommer puis archiver les cours vides avant d'importer (voir « Ordre des imports »).

Aucun enseignant ne les a encore relues. À faire valider par un enseignant :

- **Toutes les leçons** : le sous-titre de la dernière fiche peut porter un « À compléter : … » qui liste les notions laissées de côté. L'élève le voit : à compléter ou à effacer après validation.
- **Mathématiques** : « Nombres décimaux relatifs » apparaît en 6ème et en 4ème dans la progression du dépôt : les deux leçons se recouvrent peut-être. Le rattachement à la 4ème des « angles alternes-internes et correspondants » et de l'inverse et du quotient de nombres rationnels est incertain.
- **Physique-Chimie** : la « pénombre » et la classification « transparent, translucide, opaque » sont peut-être acquises avant la 4ème.
- **SVT** : la fécondation et la cellule-œuf (leçon 2 de 4ème) ne sont pas nommées dans la progression : à confirmer.
- **Histoire-Géographie** : le rôle du gouverneur de district et des préfets de région et de département, le Poro chez les Sénoufo, la reine Pokou et le passage du Comoé (présentés sans date).
- **Français** : le périmètre du Débat I et le plan du texte explicatif, à confirmer au programme. La proposition relative est laissée de côté.
- **EDHC** : la Constitution ivoirienne est citée sans numéro d'article ni date, et les textes de loi ivoiriens (numéros, dates) ne sont pas cités. Les dates des textes internationaux, et le seuil de 15 ans de l'article 38 de la Convention relative aux droits de l'enfant, sont cités de mémoire. Le mot « interdépendance » (5ème), et la règle des 18 ans pour la participation aux combats (5ème), sont à confirmer.

### 3ème — `lecons-traitees/3eme/`

Les 3 premières leçons de chaque matière de la 3ème (progression DPFC 2026-2027), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md).

| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `physique-chimie/masse-et-poids-d-un-corps.json` | Masse et poids d'un corps | 4 | 12 | 71 |
| `physique-chimie/les-forces.json` | Les forces | 4 | 12 | 68 |
| `physique-chimie/equilibre-d-un-solide-soumis-a-deux-forces.json` | Équilibre d'un solide soumis à deux forces | 4 | 12 | 71 |
| `physique-chimie/les-lentilles.json` | Les lentilles (rédigée le 2026-10-28 pour la fiche Lentilles, chantier contenu-en-blocs : 5 fiches, un exercice par fiche puis quatre sur toute la leçon) | 5 | 9 | 45 |
| `svt/les-aliments-et-l-homme.json` | Les aliments et l'Homme | 4 | 12 | 69 |
| `svt/la-digestion-des-aliments.json` | La digestion des aliments | 4 | 12 | 60 |
| `svt/le-sang.json` | Le sang | 4 | 12 | 68 |
| `histoire-geographie/histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire.json` | Histoire — Le mouvement impérialiste et la colonisation en Côte d'Ivoire | 4 | 12 | 60 |
| `histoire-geographie/geographie-les-atouts-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les atouts du développement économique de la Côte d'Ivoire | 4 | 12 | 65 |
| `histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json` | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 4 | 12 | 60 |
| `edhc/les-devoirs-des-parents.json` | Les devoirs des parents | 4 | 12 | 60 |
| `edhc/les-organisations-humanitaires.json` | Les organisations humanitaires | 4 | 12 | 60 |
| `edhc/les-instruments-et-les-mecanismes-de-protection-contre-les-violences-faites-aux-personnes-vulnerables.json` | Les instruments et les mécanismes de protection contre les violences faites aux personnes vulnérables | 4 | 12 | 72 |

Tous les fichiers de ce lot ont depuis été réécrits au format 3, sous le même nom (sections suivantes) : ce tableau et ses réserves ne décrivent plus que la version 1. En version 1, ces fichiers suivaient le prompt complet : 4 fiches par cours, 3 exercices par fiche. Chacun a passé `script/contenus/valider.rb`, puis une relecture par un second rédacteur, qui a refait les calculs et vérifié les faits. Les défauts trouvés ont été corrigés. Importés ensemble sur une base jetable par la vraie chaîne d'import : **18 cours, 72 fiches, 216 exercices, 1 194 questions, 4 370 propositions, sans erreur**, une fois la matière EDHC créée. Sans elle, les 3 cours d'EDHC sont rejetés (`unknown_material`) et les 15 autres passent. Aucun enseignant ne les a encore relus.

À faire valider par un enseignant (le programme détaillé n'était pas disponible) :

- **Toutes les leçons** : le champ `subtitle` de la dernière fiche porte un « À compléter : … » qui liste ce que le rédacteur a laissé de côté. L'élève le voit. À compléter ou à effacer après validation.
- **Maths** : les fractions rationnelles, la rationalisation du dénominateur et les triangles semblables ne sont pas traités (rattachement à la 3ème incertain). Le « papillon » de Thalès et le non-parallélisme y sont.
- **Physique-Chimie, Les lentilles** : leçon rédigée sans programme sous les yeux, au niveau graphique (trois rayons particuliers, image réelle ou virtuelle, loupe, projecteur, appareil photo, œil réduit et défauts de la vue) ; aucune formule de conjugaison. Elle attend la relecture du porteur ou de Touré avant d'être présentée à des élèves. Les nombres de ses exercices (distances en cm, constructions à l'échelle) ont été recalculés.
- **Physique-Chimie** : la fiche « réaction du support » (équilibre) est peut-être de niveau lycée. g vaut 10 N/kg partout, et 1,6 N/kg sur la Lune. Le contact localisé et réparti, et le mot « tension du fil », sont à confirmer.
- **SVT** : les valeurs énergétiques 17 / 17 / 38 kJ par gramme, les tests de Fehling et du biuret, les noms d'enzymes et leurs conditions d'action, la fibrine, la phagocytose et la coagulation.
- **Histoire-Géographie** : les « atouts institutionnels » (OHADA, BCEAO, code des investissements), et les dates de la leçon sur l'indépendance (loi-cadre de 1956, référendum de 1958, indépendance du 7 août 1960, présidence fin 1960). L'AOF et les traités de protectorat sont cités sans date.
- **EDHC** : aucun article de loi, aucune date, aucun numéro d'urgence. Les noms des conventions et chartes citées (femmes, personnes handicapées, enfant, Protocole de Maputo) sont écrits de mémoire, et la ratification par la Côte d'Ivoire n'est pas affirmée. La matière EDHC n'existe pas dans le référentiel : il faut la créer avant d'importer les 3 cours.

### 3ème, mathématiques au format 3 — le pilote (chantier `refonte-contenus-maths`)

Les 10 leçons de mathématiques de la progression DPFC 2026-2027, rédigées le 2026-10-29 au format `lnclass.course-tree` v3. Chaque notion a une fiche en quatre blocs (À retenir, La méthode, Un exemple corrigé, Le piège à éviter), éventuellement une figure, et un exercice. La leçon a en plus 4 problèmes de 5 questions ou plus.

| # | Fichier | Cours | Notions | Figures | Exercices | Questions |
|---:|---|---|---:|---:|---:|---:|
| 1 | `mathematiques/calcul-litteral.json` | Calcul littéral | 4 | 0 | 8 | 54 |
| 2 | `mathematiques/proprietes-de-thales-dans-un-triangle.json` | Propriétés de Thalès dans un triangle | 3 | 2 | 7 | 40 |
| 3 | `mathematiques/racines-carrees.json` | Racines carrées | 6 | 2 | 10 | 52 |
| 4 | `mathematiques/triangle-rectangle.json` | Triangle rectangle | 4 | 5 | 8 | 46 |
| 5 | `mathematiques/calcul-numerique.json` | Calcul numérique | 4 | 1 | 8 | 41 |
| 6 | `mathematiques/angles-inscrits.json` | Angles inscrits | 4 | 6 | 8 | 48 |
| 7 | `mathematiques/vecteurs.json` | Vecteurs | 4 | 7 | 8 | 40 |
| 8 | `mathematiques/equations-et-inequations-dans-r.json` | Équations et inéquations dans ℝ | 4 | 3 | 8 | 45 |
| 9 | `mathematiques/pyramides-et-cones.json` | Pyramides et cônes | 4 | 4 | 8 | 40 |
| 10 | `mathematiques/statistique.json` | Statistique | 5 | 4 | 9 | 49 |

Au total : 42 notions, 34 figures, 82 exercices et 455 questions. Chaque fichier passe `script/contenus/valider.rb` sans avertissement. Chacun a été relu par un second rédacteur, qui a refait les calculs et corrigé 40 défauts. Chacun s'importe en brouillon par la vraie chaîne d'import ; c'est vérifié par `test/integration/catalog/pilot_lessons_test.rb`. Les points à faire trancher par un enseignant sont dans [`validation-enseignant.md`](../chantiers/refonte-contenus-maths/validation-enseignant.md).

### 3ème, Français au format 3 (chantier `contenus-3e-francais`)

Les 10 premières leçons de Français de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Aucune figure. Chaque leçon a au moins 77 % de questions corrigées automatiquement. Les autres questions sont rédigées : chacune a un corrigé modèle, un barème et des critères. Les textes supports sont écrits pour Lnclass. Les œuvres réelles ne sont citées que par de courtes références paraphrasées, avec auteur, titre et date.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto |
|---:|---|---|---:|---:|---:|---:|
| 1 | `francais/l-expression-des-circonstances-dans-la-phrase-simple-et-dans-la-phrase-complexe.json` | L'expression des circonstances dans la phrase simple et dans la phrase complexe | 4 | 8 | 54 | 81 % |
| 2 | `francais/le-dialogue-oral.json` | Le dialogue oral | 4 | 8 | 51 | 80 % |
| 3 | `francais/le-texte-argumentatif.json` | Le texte argumentatif | 4 | 8 | 52 | 81 % |
| 4 | `francais/etude-de-l-oeuvre-integrale-n-1.json` | Étude de l'œuvre intégrale n°1 | 4 | 8 | 53 | 81 % |
| 5 | `francais/orthographe-lexicale.json` | Orthographe lexicale | 3 | 7 | 51 | 80 % |
| 6 | `francais/la-coordination.json` | La coordination | 4 | 8 | 51 | 80 % |
| 7 | `francais/le-resume-du-texte-argumentatif.json` | Le résumé du texte argumentatif | 4 | 8 | 50 | 80 % |
| 8 | `francais/le-groupe-nominal-la-pronominalisation.json` | Le groupe nominal : la pronominalisation | 4 | 8 | 52 | 79 % |
| 9 | `francais/le-verbe-l-infinitif-et-le-participe.json` | Le verbe : l'infinitif et le participe | 3 | 7 | 47 | 79 % |
| 10 | `francais/l-expose-oral.json` | L'exposé oral | 4 | 8 | 52 | 77 % |

Au total : 38 notions, 78 exercices et 513 questions. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. Chacun a été relu par un second rédacteur, et les défauts trouvés ont été corrigés : règles de grammaire fausses, faits d'œuvre inexacts, fautes de langue, réponses justes refusées.

À faire valider par un enseignant :

- **Leçon 4** : les faits cités sur *Une vie de boy* (Ferdinand Oyono, 1956) et *L'Enfant noir* (Camara Laye, 1953). Le choix des œuvres reste à aligner sur la liste de l'établissement.
- **Leçon 7** : la façon de compter les mots d'un résumé (trait d'union, « c'est-à-dire », chiffres). La leçon la soumet à la consigne du sujet.
- **Leçons 8 et 9** : l'ordre des pronoms à l'impératif, la distinction entre participe présent et adjectif verbal, et les propositions infinitive et participiale, seulement citées.
- **Questions rédigées** : les barèmes, de 3 à 8 points.

### 3ème, Histoire-Géographie au format 3 (chantier `contenus-3e-histoire-geographie`)

Les 10 premières leçons d'Histoire-Géographie de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures sont les sortes livrées par ce chantier (ADR-0117, UDR-0142) : frise (`timeline`), carte (`map`, fonds `cote_d_ivoire`, `africa`, `world`), schéma (`diagram`) et courbe (`stat_chart line`).

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `histoire-geographie/histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire.json` | Histoire — Le mouvement impérialiste et la colonisation en Côte d'Ivoire | 5 | 9 | 53 | 81 % | 3 | `map africa`, `map cote_d_ivoire`, `timeline` |
| 2 | `histoire-geographie/geographie-les-atouts-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les atouts du développement économique de la Côte d'Ivoire | 5 | 9 | 50 | 88 % | 2 | `map cote_d_ivoire`, `stat_chart line` |
| 3 | `histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json` | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 5 | 9 | 46 | 89 % | 2 | `timeline`, `diagram` |
| 4 | `histoire-geographie/geographie-les-secteurs-d-activites-economiques-de-la-cote-d-ivoire.json` | Géographie — Les secteurs d'activités économiques de la Côte d'Ivoire | 4 | 8 | 48 | 88 % | 3 | `map cote_d_ivoire`, `stat_chart pie` |
| 5 | `histoire-geographie/histoire-causes-et-caracteres-des-crises-sociopolitiques-de-l-afrique-independante.json` | Histoire — Causes et caractères des crises sociopolitiques de l'Afrique indépendante | 4 | 8 | 45 | 91 % | 2 | `map africa`, `timeline` |
| 6 | `histoire-geographie/histoire-la-crise-rwandaise-de-la-guerre-au-genocide-des-tutsi-1990-1994.json` | Histoire — La crise rwandaise : de la guerre au génocide des tutsi (1990-1994) | 4 | 8 | 40 | 90 % | 2 | `map africa`, `timeline` |
| 7 | `histoire-geographie/geographie-les-problemes-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les problèmes du développement économique de la Côte d'Ivoire | 5 | 9 | 47 | 83 % | 2 | `stat_chart line`, `diagram` |
| 8 | `histoire-geographie/histoire-les-causes-les-caracteres-et-les-consequences-de-la-deuxieme-guerre-mondiale.json` | Histoire — Les causes, les caractères et les conséquences de la deuxième guerre mondiale | 4 | 8 | 49 | 86 % | 2 | `timeline`, `map world` |
| 9 | `histoire-geographie/geographie-etude-economique-de-l-afrique.json` | Géographie — Etude Economique de l'Afrique | 4 | 8 | 42 | 88 % | 4 | `map africa`, `diagram`, `timeline` |
| 10 | `histoire-geographie/histoire-l-organisation-des-nations-unies-onu.json` | Histoire — L'Organisation des Nations Unies (ONU) | 4 | 8 | 49 | 84 % | 3 | `timeline`, `diagram`, `map world` |

Au total : 44 notions, 84 exercices, 469 questions et 25 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. À faire relire par un enseignant d'Histoire-Géographie avant publication : dates et chiffres, et le contenu des cartes.

### 3ème, SVT au format 3 (chantier `contenus-3e-svt`)

Les 10 premières leçons de SVT de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures ajoutent les planches légendées (`plate`, 8 planches de SVT : appareil digestif, frottis sanguin, cœur, double circulation, appareil génital de la femme, virus du VIH, profil de sol, poils absorbants) aux sortes déjà livrées.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `svt/les-aliments-et-l-homme.json` | Les aliments et l'Homme | 4 | 8 | 53 | 91 % | 3 | `diagram`, `stat_chart pie` |
| 2 | `svt/la-digestion-des-aliments.json` | La digestion des aliments | 4 | 8 | 60 | 92 % | 3 | `plate digestive_system`, `diagram` |
| 3 | `svt/le-sang.json` | Le sang | 4 | 8 | 53 | 91 % | 7 | `plate blood_smear`, `stat_chart pie`, `diagram`, `stat_chart line` |
| 4 | `svt/la-transfusion-sanguine.json` | La transfusion sanguine | 3 | 7 | 47 | 89 % | 3 | `diagram` |
| 5 | `svt/la-circulation-sanguine.json` | La circulation sanguine | 4 | 8 | 51 | 92 % | 6 | `plate heart`, `plate double_circulation`, `diagram`, `stat_chart line` |
| 6 | `svt/les-grossesses-precoces-et-les-moyens-de-prevention.json` | Les grossesses précoces et les moyens de prévention | 4 | 8 | 50 | 86 % | 5 | `timeline`, `plate female_reproductive_system`, `diagram` |
| 7 | `svt/l-infection-au-vih.json` | L'infection au VIH | 3 | 7 | 45 | 91 % | 5 | `plate hiv_virus`, `stat_chart line`, `diagram` |
| 8 | `svt/les-caracteristiques-d-un-sol.json` | Les caractéristiques d'un sol | 4 | 8 | 53 | 92 % | 5 | `plate soil_profile`, `stat_chart bars` |
| 9 | `svt/les-relations-sols-plantes.json` | Les relations sols-plantes | 4 | 8 | 52 | 92 % | 9 | `plate root_hairs`, `diagram`, `stat_chart bars`, `plate soil_profile` |
| 10 | `svt/la-degradation-des-sols.json` | La dégradation des sols | 4 | 8 | 49 | 90 % | 5 | `diagram`, `plate soil_profile`, `stat_chart line` |

Au total : 38 notions, 78 exercices, 513 questions et 51 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement.

À faire valider par un enseignant de SVT avant publication : les 8 planches (captures envoyées au porteur), le vocabulaire du programme et les valeurs données à titre d'exemple dans les leçons.

### 3ème, Physique-Chimie au format 3 (chantier `contenus-3e-physique-chimie`)

Les 10 premières leçons de Physique-Chimie de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les fichiers antérieurs du même intitulé, dont « Les lentilles ». Les figures ajoutent le tracé optique (`optics`), la molécule (`molecule`) et 3 planches (`dynamometer`, `electrolyser`, `eudiometer`) aux sortes déjà livrées, dont le repère (`coordinate_plane`) des mathématiques.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `physique-chimie/masse-et-poids-d-un-corps.json` | Masse et poids d'un corps | 4 | 8 | 49 | 94 % | 2 | `plate dynamometer`, `coordinate_plane` |
| 2 | `physique-chimie/les-forces.json` | Les forces | 4 | 8 | 59 | 93 % | 5 | `coordinate_plane`, `plate dynamometer` |
| 3 | `physique-chimie/equilibre-d-un-solide-soumis-a-deux-forces.json` | Équilibre d'un solide soumis à deux forces | 4 | 8 | 43 | 91 % | 5 | `coordinate_plane` |
| 4 | `physique-chimie/travail-et-puissance-mecaniques.json` | Travail et puissance mécaniques | 4 | 8 | 61 | 95 % | 4 | `coordinate_plane`, `stat_chart bars` |
| 5 | `physique-chimie/energie-mecanique.json` | Énergie mécanique | 4 | 8 | 53 | 91 % | 3 | `stat_chart bars`, `coordinate_plane` |
| 6 | `physique-chimie/electrolyse-et-synthese-de-l-eau.json` | Électrolyse et synthèse de l'eau | 4 | 8 | 56 | 95 % | 6 | `plate electrolyser`, `plate eudiometer`, `molecule` |
| 7 | `physique-chimie/les-alcanes.json` | Les alcanes | 4 | 8 | 54 | 91 % | 5 | `molecule` |
| 8 | `physique-chimie/les-lentilles.json` | Les lentilles | 5 | 9 | 63 | 94 % | 3 | `optics` |
| 9 | `physique-chimie/les-defauts-de-l-oeil-et-leurs-corrections.json` | Les défauts de l'œil et leurs corrections | 4 | 8 | 48 | 94 % | 5 | `optics` |
| 10 | `physique-chimie/oxydation-des-corps-purs-simples.json` | Oxydation des corps purs simples | 4 | 8 | 54 | 93 % | 4 | `molecule`, `diagram` |

Au total : 41 notions, 81 exercices, 540 questions et 42 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement.

À faire valider par un enseignant de Physique-Chimie avant publication : les 3 planches, et les chiffres des exercices.

### 3ème, EDHC au format 3 (chantier `contenus-3e-edhc`)

Les 10 premières leçons d'EDHC de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures sont celles de l'inventaire de l'ADR des figures de 3ème : schémas (`diagram`), graphiques (`stat_chart`, données fictives et dites fictives) et, à la leçon 10, la carte de Côte d'Ivoire des aires culturelles (`map`, fond `cote_d_ivoire`). Le contenu suit les textes en vigueur (Constitution du 8 novembre 2016) ; il est neutre : aucun parti ni personnalité politique réels, des situations et des personnages fictifs.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures |
|---:|---|---|---:|---:|---:|---:|---|
| 1 | `edhc/les-devoirs-des-parents.json` | Les devoirs des parents | 4 | 8 | 49 | 82 % | `diagram` |
| 2 | `edhc/les-organisations-humanitaires.json` | Les organisations humanitaires | 4 | 8 | 51 | 86 % | `diagram` |
| 3 | `edhc/les-instruments-et-les-mecanismes-de-protection-contre-les-violences-faites-aux-personnes-vulnerables.json` | Les instruments et les mécanismes de protection contre les violences faites aux personnes vulnérables | 4 | 8 | 49 | 92 % | `diagram`, `stat_chart bars` |
| 4 | `edhc/les-partis-politiques.json` | Les partis politiques | 4 | 8 | 44 | 89 % | `diagram` |
| 5 | `edhc/les-institutions-juridictionnelles.json` | Les institutions juridictionnelles | 4 | 8 | 41 | 88 % | `diagram` |
| 6 | `edhc/le-scrutin-electoral.json` | Le scrutin électoral | 5 | 9 | 51 | 92 % | `diagram`, `stat_chart bars`, `stat_chart pie` |
| 7 | `edhc/le-civisme-fiscal.json` | Le civisme fiscal | 4 | 8 | 44 | 89 % | `diagram`, `stat_chart pie` |
| 8 | `edhc/la-gestion-des-biens-publics.json` | La gestion des biens publics | 4 | 8 | 45 | 89 % | `diagram`, `stat_chart bars` |
| 9 | `edhc/le-projet-d-entreprise.json` | Le projet d'entreprise | 5 | 9 | 47 | 91 % | `diagram`, `stat_chart line` |
| 10 | `edhc/les-alliances-interethniques-les-mande-et-les-gour.json` | Les alliances interethniques : les Mandé et les Gour | 4 | 8 | 42 | 88 % | `diagram`, `map` |

Au total : 42 notions, 82 exercices, 463 questions et 22 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. Chacun a été relu par un second modèle (Opus) qui n'en était pas l'auteur, et les défauts trouvés ont été corrigés : questions à deux bonnes réponses, faits inexacts (CEDEF, Croix-Rouge), noms à connotation régionale ou ethnique, district oublié sur la carte, corrections qui désignaient une proposition par sa position.

À faire valider par un enseignant :

- **Textes** : aucun numéro d'article n'est cité ; les renvois à la Constitution de 2016 et aux lois (scolarité obligatoire, partis politiques, Code pénal) sont à confirmer dans leur formulation.
- **Leçon 2** : le rangement de la Croix-Rouge (branche à part, ni ONG ni organisation des États), à aligner sur le manuel en usage.
- **Leçons 5 et 6** : compétences des tribunaux de commerce, de la Haute Cour de justice et du Conseil constitutionnel ; seule la présidentielle est affirmée pour les résultats définitifs du Conseil constitutionnel.
- **Leçon 7** : la distinction entre taxe et redevance.
- **Leçon 10** : le rattachement des peuples aux groupes Mandé et Gour, les termes « toukpê » et « sanankouya », et la carte, qui ne colorie que les districts où un groupe est majoritaire de façon sûre (Montagnes, Vallée du Bandama et Sassandra-Marahoué restent blancs). Aucune alliance précise entre deux peuples réels n'est affirmée.

### Tle C et D, mathématiques au format 3 (chantier `contenus-tle-mathematiques-cd`)

Les 10 leçons de Mathématiques de la progression DPFC 2026-2027 de Tle C et de Tle D, rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague T1 du programme `contenus-v3-tous-niveaux`). 14 leçons distinctes, 20 fichiers : les 6 leçons communes aux deux séries (Limites et continuité, Dérivabilité et étude de fonctions, Primitives, Fonctions logarithmes, Fonctions exponentielles, Nombres complexes) ont un fichier par série, avec les mêmes notions et des problèmes 3 et 4 au niveau de chaque série. « Fonctions exponentielles et fonctions puissances » (C) et « Fonctions exponentielles et puissances » (D) gardent le titre de leur progression. Les fichiers remplacent les 6 fichiers v1 du même nom (Barycentre, Limites et Divisibilité en C ; Limites, Probabilité et Dérivabilité en D). Chaque notion a sa fiche en 4 blocs, un exercice et « Je m'entraîne » ; chaque leçon a 4 problèmes (2 de fixation, 2 d'évaluation dont un au niveau du baccalauréat). Aucune sorte de figure nouvelle : les courbes, tableaux de variations, solides et coniques sont décrits par des points, segments et droites (dette notée au journal du chantier).

#### Tle C

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/barycentre-et-lignes-de-niveaux.json` | Barycentre et lignes de niveaux | 5 | 9 | 47 | 98 % | 8 | `geometry` |
| 2 | `mathematiques/limites-et-continuite.json` | Limites et continuité | 5 | 9 | 52 | 100 % | 2 | `coordinate_plane` |
| 3 | `mathematiques/divisibilite-dans.json` | Divisibilité dans ℤ | 4 | 8 | 55 | 98 % | 3 | `number_line`, `diagram`, `coordinate_plane` |
| 4 | `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions | 5 | 9 | 58 | 98 % | 5 | `coordinate_plane` |
| 5 | `mathematiques/geometrie-analytique-de-l-espace.json` | Géométrie analytique de l'espace | 4 | 8 | 47 | 96 % | 0 | — |
| 6 | `mathematiques/primitives.json` | Primitives | 4 | 8 | 54 | 98 % | 0 | — |
| 7 | `mathematiques/fonctions-logarithmes.json` | Fonctions logarithmes | 5 | 9 | 73 | 99 % | 2 | `number_line`, `diagram` |
| 8 | `mathematiques/coniques.json` | Coniques | 5 | 9 | 57 | 98 % | 7 | `coordinate_plane` |
| 9 | `mathematiques/fonctions-exponentielles-et-fonctions-puissances.json` | Fonctions exponentielles et fonctions puissances | 5 | 9 | 46 | 100 % | 3 | `coordinate_plane` |
| 10 | `mathematiques/nombres-complexes.json` | Nombres complexes | 5 | 9 | 67 | 100 % | 3 | `coordinate_plane` |

Au total : 47 notions, 87 exercices, 556 questions notées et 33 figures.

#### Tle D

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/limites-et-continuite.json` | Limites et continuité | 5 | 9 | 52 | 100 % | 1 | `coordinate_plane` |
| 2 | `mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json` | Probabilité conditionnelle et variable aléatoire | 5 | 9 | 63 | 97 % | 4 | `diagram`, `stat_chart bars` |
| 3 | `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions | 5 | 9 | 60 | 98 % | 4 | `coordinate_plane` |
| 4 | `mathematiques/primitives.json` | Primitives | 4 | 8 | 54 | 100 % | 0 | — |
| 5 | `mathematiques/fonctions-logarithmes.json` | Fonctions logarithmes | 5 | 9 | 70 | 100 % | 2 | `number_line`, `diagram` |
| 6 | `mathematiques/fonctions-exponentielles-et-puissances.json` | Fonctions exponentielles et puissances | 5 | 9 | 46 | 100 % | 3 | `coordinate_plane` |
| 7 | `mathematiques/suites-numeriques.json` | Suites numériques | 5 | 9 | 58 | 100 % | 2 | `coordinate_plane` |
| 8 | `mathematiques/nombres-complexes.json` | Nombres complexes | 5 | 9 | 65 | 100 % | 3 | `coordinate_plane` |
| 9 | `mathematiques/calcul-integral.json` | Calcul intégral | 5 | 9 | 56 | 98 % | 3 | `coordinate_plane` |
| 10 | `mathematiques/nombres-complexes-et-geometrie-du-plan.json` | Nombres complexes et géométrie du plan | 4 | 8 | 45 | 96 % | 5 | `coordinate_plane`, `geometry` |

Au total : 48 notions, 88 exercices, 569 questions notées et 27 figures.

Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et « Je m'entraîne » respecte les règles de `Entities::Catalog::NotionPractice`. Chaque leçon a été relue par un second rédacteur (calculs refaits), et les défauts trouvés ont été corrigés. Les leçons restent en brouillon.

À faire valider par un enseignant de mathématiques avant publication : le rattachement de chaque notion au programme de la série, le niveau des problèmes de type bac et leurs barèmes. La liste par leçon est dans le journal du chantier [`contenus-tle-mathematiques-cd`](../chantiers/contenus-tle-mathematiques-cd/journal.md).

### Tle A1, A2 et C — `lecons-traitees/tle-a1/`, `tle-a2/`, `tle-c/`

Les 3 premières leçons de chaque matière des séries A1, A2 et C de Terminale (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A1 et A2 n'ont pas de Physique-Chimie dans la progression.

#### Tle A1

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Étude de fonctions polynômes et de fonctions rationnelles (Mathématiques) | 1 | 4 | 12 | 69 |
| `mathematiques/probabilite-et-variable-aleatoire.json` | Probabilité et variable aléatoire (Mathématiques) | 2 | 4 | 12 | 72 |
| `mathematiques/primitives-et-calcul-integral.json` | Primitives et calcul intégral (Mathématiques) | 3 | 4 | 12 | 72 |
| `svt/les-reactions-emotionnelles-chez-l-homme.json` | Les réactions émotionnelles chez l'Homme (SVT) | 1 | 4 | 12 | 60 |
| `svt/l-activite-cerebrale-chez-l-homme.json` | L'activité cérébrale chez l'Homme (SVT) | 2 | 5 | 15 | 84 |
| `svt/l-origine-de-la-vie.json` | L'origine de la vie (SVT) | 3 | 4 | 12 | 72 |
| `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU (Histoire-Géographie) | 1 | 3 | 9 | 53 |
| `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire (Histoire-Géographie) | 2 | 3 | 9 | 52 |
| `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 (Histoire-Géographie) | 3 | 3 | 9 | 53 |
| `francais/oeuvre-narrative.json` | Œuvre narrative (Français) | 1 | 3 | 9 | 54 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat (Français) | 2 | 3 | 9 | 51 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire (Français) | 3 | 3 | 9 | 52 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique (Philosophie) | 1 | 3 | 9 | 52 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique (Philosophie) | 2 | 3 | 9 | 54 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme (Philosophie) | 3 | 3 | 9 | 52 |

#### Tle A2

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Étude de fonctions polynômes et de fonctions rationnelles (Mathématiques) | 1 | 4 | 12 | 69 |
| `mathematiques/probabilite.json` | Probabilité (Mathématiques) | 2 | 4 | 12 | 64 |
| `mathematiques/fonction-logarithme-neperien.json` | Fonction logarithme népérien (Mathématiques) | 3 | 4 | 12 | 72 |
| `svt/les-reactions-emotionnelles-chez-l-homme.json` | Les réactions émotionnelles chez l'Homme (SVT) | 1 | 4 | 12 | 60 |
| `svt/l-activite-cerebrale-chez-l-homme.json` | L'activité cérébrale chez l'Homme (SVT) | 2 | 5 | 15 | 84 |
| `svt/l-origine-de-la-vie.json` | L'origine de la vie (SVT) | 3 | 4 | 12 | 72 |
| `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU (Histoire-Géographie) | 1 | 3 | 9 | 53 |
| `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire (Histoire-Géographie) | 2 | 3 | 9 | 52 |
| `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 (Histoire-Géographie) | 3 | 3 | 9 | 53 |
| `francais/oeuvre-narrative.json` | Œuvre narrative (Français) | 1 | 3 | 9 | 54 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat (Français) | 2 | 3 | 9 | 51 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire (Français) | 3 | 3 | 9 | 52 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique (Philosophie) | 1 | 3 | 9 | 52 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique (Philosophie) | 2 | 3 | 9 | 54 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme (Philosophie) | 3 | 3 | 9 | 52 |

#### Tle C

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/barycentre-et-lignes-de-niveaux.json` | Barycentre et lignes de niveaux (Mathématiques) | 1 | 4 | 12 | 72 |
| `mathematiques/limites-et-continuite.json` | Limites et continuité (Mathématiques) | 2 | 5 | 15 | 75 |
| `mathematiques/divisibilite-dans.json` | Divisibilité dans ℤ (Mathématiques) | 3 | 4 | 12 | 67 |
| `physique-chimie/cinematique-du-point.json` | Cinématique du point (Physique-Chimie) | 1 | 5 | 15 | 75 |
| `physique-chimie/les-alcools.json` | Les alcools (Physique-Chimie) | 2 | 4 | 12 | 72 |
| `physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide (Physique-Chimie) | 3 | 4 | 12 | 70 |
| `svt/les-cycles-sexuels-chez-la-femme.json` | Les cycles sexuels chez la femme (SVT) | 1 | 4 | 12 | 72 |
| `svt/la-transmission-d-un-caractere-hereditaire-chez-l-homme.json` | La transmission d'un caractère héréditaire chez l'Homme (SVT) | 2 | 4 | 12 | 71 |
| `svt/la-production-d-energie-par-la-cellule.json` | La production d'énergie par la cellule (SVT) | 3 | 4 | 12 | 68 |
| `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU (Histoire-Géographie) | 1 | 3 | 9 | 53 |
| `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire (Histoire-Géographie) | 2 | 3 | 9 | 52 |
| `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 (Histoire-Géographie) | 3 | 3 | 9 | 53 |
| `francais/oeuvre-narrative.json` | Œuvre narrative (Français) | 1 | 3 | 9 | 54 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire (Français) | 2 | 3 | 9 | 52 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat (Français) | 3 | 3 | 9 | 51 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique (Philosophie) | 1 | 3 | 9 | 52 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique (Philosophie) | 2 | 3 | 9 | 54 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme (Philosophie) | 3 | 3 | 9 | 52 |

Les 3 leçons de mathématiques de ce tableau (format v1) sont remplacées par leur version au format 3 : voir « Tle C et D, mathématiques au format 3 ».

**48 cours, 169 fiches, 507 exercices, 2911 questions, 11635 propositions.** Tous passent `script/contenus/valider.rb`. Importés ensemble en un seul envoi sur une base jetable par la vraie chaîne d'import : **48 cours créés, sans erreur ni refus** (169 fiches, 507 exercices, 2 911 questions, 11 635 propositions).

**Ce qui a été repris, ce qui a été rédigé.**

- **Histoire-Géographie, Français, Philosophie** (27 fichiers) : les progressions de A1, A2 et C ont les mêmes intitulés que celle de Tle D. Les leçons de Tle D (déjà relues) ont été **copiées** avec la série et le rang de la progression de chaque série. Le contenu est donc identique d'une série à l'autre.
- **Maths, SVT, Physique-Chimie C** (17 leçons) : **rédigées** pour la série, avec un niveau adapté. En A1 et A2 (littéraires), on vise la compréhension et les calculs concrets, peu de démonstrations. En C, la rigueur et les démonstrations de cours. Chacune a été relue par un second rédacteur (calculs refaits, faits vérifiés, titre et contenu confrontés), et les défauts trouvés ont été corrigés.
- **A2 repris de A1** : « Étude de fonctions polynômes et de fonctions rationnelles » (Maths) et les 3 leçons de SVT ont le même intitulé en A1 et en A2. Le fichier de A2 est la copie de celui de A1, avec la série et le rang de A2.

**Attention à l'import.**

- La série fait partie de la clé de doublon (nom, niveau, matière, série). Les cours des progressions sans série ne sont donc pas des doublons de ces leçons.
- Un cours déjà présent est ignoré, jamais mis à jour. Si une progression de A1, A2 ou C a déjà été importée, le cours de la leçon existe vide : le **renommer, l'archiver**, puis importer le cours complet.
- Chaque fichier peut être importé séparément : l'ordre n'a pas d'importance entre eux.

À faire valider par un enseignant (le programme détaillé n'était pas disponible) :

- **Toutes les leçons** : le champ `subtitle` de la dernière fiche porte un « À compléter : … » qui liste ce que le rédacteur a laissé de côté. L'élève le voit. À compléter ou à effacer après validation.
- **Maths C** : « Barycentre et lignes de niveaux » traite la fonction de Leibniz et le cercle d'Apollonius ; la place de chaque notion dans la leçon est à confirmer. L'algorithme d'Euclide de « Divisibilité dans ℤ » suppose b non nul avec un dernier reste non nul.
- **Maths A1 et A2** : le niveau (calculs concrets, peu de démonstrations) est à confirmer avec un enseignant de série A.
- **SVT A1 et A2** : le vocabulaire (drogues, dépendance, tolérance, imagerie TEP, synapses) est peut-être dense pour des littéraires ; « L'origine de la vie » a un « À compléter » sur le rattachement au programme de la série A.
- **SVT C** : la contraception hormonale (4e fiche de « Les cycles sexuels chez la femme ») et la méiose, le rendement chiffré de la respiration (36 à 38 ATP par glucose, 30,5 kJ par mole d'ATP et 2 870 kJ par mole de glucose : valeurs écrites par le rédacteur) sont à confirmer.
- **Physique-Chimie C** : le repère de Frenet et le mouvement rectiligne sinusoïdal (« Cinématique du point »), la fermentation alcoolique, la liaison hydrogène et la distillation (« Les alcools ») ; les noms des produits d'oxydation (aldéhydes, cétones, acides) y sont cités sans nomenclature systématique, réservée à la leçon suivante ; le frottement par une relation `f = k·R_N` donnée dans l'énoncé, sans coefficient de frottement (« Mouvement du centre d'inertie d'un solide »).

### 1ère — `lecons-traitees/1ere-a1/`, `1ere-a2/`, `1ere-c/`, `1ere-d/`, `1ere/`

Les 3 premières leçons de chaque matière de Première (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A, C et D ont des progressions différentes, et Histoire-Géographie est commune à toutes les séries. Dans le référentiel de Develop, la 1ère n'a que les séries A, C et D : les anciens jeux « 1ère A1 » et « 1ère A2 », au contenu identique, sont fusionnés en « 1ère A ».

#### 1ère A1 et A2 (15 chacune)

Même texte dans `1ere-a1/` et `1ere-a2/`, à la série près : écrites pour une série « A » que le référentiel n'ouvre pas en 1ère, elles ont été séparées le 2026-10-23.

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/equations-et-inequations.json` | Équations et inéquations | 1 | 4 | 12 | 72 |
| `mathematiques/denombrement.json` | Dénombrement | 2 | 4 | 12 | 72 |
| `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 3 | 4 | 12 | 72 |
| `physique-chimie/etude-d-un-dipole-passif-cas-d-un-resistor.json` | Étude d'un dipôle passif : cas d'un résistor | 1 | 4 | 12 | 71 |
| `physique-chimie/les-alcanes.json` | Les alcanes | 2 | 4 | 12 | 72 |
| `physique-chimie/les-alcenes-cas-de-l-ethylene.json` | Les alcènes : cas de l'éthylène | 3 | 4 | 12 | 72 |
| `svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 1 | 4 | 12 | 64 |
| `svt/les-effets-des-drogues-sur-le-comportement.json` | Les effets des drogues sur le comportement | 2 | 4 | 12 | 65 |
| `svt/les-anomalies-chromosomiques.json` | Les anomalies chromosomiques | 3 | 3 | 9 | 54 |
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 12 | 64 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 2 | 3 | 9 | 45 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 3 | 4 | 12 | 64 |
| `philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 1 | 3 | 9 | 48 |
| `philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 2 | 4 | 12 | 60 |
| `philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 3 | 3 | 9 | 53 |

#### 1ère C (15)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/equations-et-inequations-dans.json` | Équations et inéquations dans ℝ | 1 | 4 | 12 | 72 |
| `mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 2 | 4 | 12 | 71 |
| `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 3 | 4 | 12 | 72 |
| `physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance dans le cas d'un mouvement de translation | 1 | 4 | 12 | 72 |
| `physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 2 | 4 | 12 | 72 |
| `physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-rotation-autour-d-un-axe-fixe.json` | Travail et puissance dans le cas d'un mouvement de rotation autour d'un axe fixe | 3 | 4 | 12 | 72 |
| `svt/le-role-et-la-structure-des-gonades-des-mammiferes.json` | Le rôle et la structure des gonades des mammifères | 1 | 4 | 12 | 68 |
| `svt/la-division-meiotique.json` | La division méiotique | 2 | 4 | 12 | 70 |
| `svt/la-gametogenese-chez-les-mammiferes.json` | La gamétogénèse chez les mammifères | 3 | 4 | 12 | 64 |
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 12 | 64 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 2 | 4 | 12 | 64 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 3 | 3 | 9 | 45 |
| `philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 1 | 3 | 9 | 48 |
| `philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 2 | 4 | 12 | 60 |
| `philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 3 | 3 | 9 | 53 |

#### 1ère D (15)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/equations-et-inequations-du-second-degre-dans.json` | Équations et inéquations du second degré dans ℝ | 1 | 4 | 12 | 64 |
| `mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 2 | 4 | 12 | 71 |
| `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 3 | 4 | 12 | 72 |
| `physique-chimie/travail-et-puissance-d-une-force-constante-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance d'une force constante dans le cas d'un mouvement de translation | 1 | 4 | 12 | 72 |
| `physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 2 | 4 | 12 | 72 |
| `physique-chimie/hydrocarbures-satures-les-alcanes.json` | Hydrocarbures saturés : les alcanes | 3 | 3 | 9 | 54 |
| `svt/les-fonctions-des-gonades.json` | Les fonctions des gonades | 1 | 3 | 9 | 51 |
| `svt/la-division-meiotique.json` | La division méiotique | 2 | 4 | 12 | 70 |
| `svt/la-gametogenese.json` | La gamétogenèse | 3 | 4 | 12 | 64 |
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 12 | 64 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 2 | 4 | 12 | 64 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 3 | 3 | 9 | 45 |
| `philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 1 | 3 | 9 | 48 |
| `philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 2 | 4 | 12 | 60 |
| `philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 3 | 3 | 9 | 53 |

#### 1ère (commune à toutes les séries) (3)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `histoire-geographie/histoire-l-essor-du-capitalisme-et-ses-consequences.json` | Histoire — L'essor du capitalisme et ses conséquences | 1 | 3 | 9 | 54 |
| `histoire-geographie/geographie-dynamisme-demographique-et-qualite-de-la-vie-en-cote-d-ivoire.json` | Géographie — Dynamisme démographique et qualité de la vie en Côte d'Ivoire | 2 | 3 | 9 | 51 |
| `histoire-geographie/histoire-les-revolutions-industrielles.json` | Histoire — Les révolutions industrielles | 3 | 3 | 9 | 54 |

**48 cours, 177 fiches, 531 exercices, 2998 questions, 11289 propositions.** Tous passent `script/contenus/valider.rb`, et `ctrlchars.rb` ne signale aucun caractère de contrôle. Les 63 cours de la version précédente (1ère A1 et A2 séparées) avaient été importés en deux envois sur une base jetable, sans refus ; **le lot actuel de 48 cours n'a pas été réimporté**.

**Ce qui a été repris, ce qui a été rédigé.**

- **Rédigées pour leur série** (32) : Maths A, C et D ; Physique-Chimie A, C et D ; SVT A, C et D ; Français A ; Philosophie A ; Histoire-Géographie. Les niveaux suivent la série : A (littéraire) = compréhension, calculs concrets ; C et D = rigueur, avec les approfondissements marqués « Plus difficile ».
- **Copiées vers une autre série** (16) : quand la progression d'une autre série porte le même intitulé, la leçon est copiée avec la série et le rang de cette progression. Le nom et le sous-titre sont ceux de la progression d'arrivée. Les 15 copies vers « 1ère A2 » ont été supprimées avec la fusion en A : elles étaient identiques à celles de A1.
- **Français et Philosophie** : la même leçon sert aux séries A, C et D. Les rangs peuvent différer d'une série à l'autre, et le sous-titre suit la progression.
- **Histoire-Géographie** : sans `series_name`, comme la progression commune. Le validateur accepte cette absence pour cette seule matière à partir de la 2nde.

**Attention à l'import.**

- La série fait partie de la clé de doublon (nom, niveau, matière, série). Un cours sans série n'est donc pas un doublon d'un cours de série.
- Un cours déjà présent est ignoré, jamais mis à jour. Si une progression de 1ère a déjà été importée, le cours de la leçon existe vide : le **renommer, l'archiver**, puis importer le cours complet.
- Un import accepte jusqu'à 50 fichiers : ce lot en compte 48, à importer en un seul envoi.

À faire valider par un enseignant (le programme détaillé n'était pas disponible) :

- **Toutes les leçons** : le champ `subtitle` de la dernière fiche porte parfois un « À compléter : … » qui liste ce que le rédacteur a laissé de côté. L'élève le voit. À compléter ou à effacer après validation.
- **Maths** : le rattachement de la valeur absolue, des équations avec |x| et des équations bicarrées au programme de chaque série.
- **Physique-Chimie** : le repère de Frenet, le mouvement rectiligne sinusoïdal (C), le code des couleurs et la résistivité (A1), la formule générale de combustion avec coefficients fractionnaires (D).
- **SVT** : la régulation hormonale et le cycle sexuel (gonades, C et D), la méiose et la gamétogenèse (C et D), les effets des drogues et les anomalies chromosomiques (A).
- **Français et Philosophie** : la règle du e muet, les formes fixes (sonnet, ballade), le nombre de parties d'une dissertation, les connecteurs et la réfutation.
- **Histoire-Géographie** : l'IDH et le taux de scolarisation (à citer avec une source), la date de la seconde révolution industrielle (« vers 1850 », « vers 1870 »), les lois sur le travail des enfants.

### 2nde — `lecons-traitees/2nde-a/`, `2nde-c/`, `2nde/`

Les 3 premières leçons de chaque matière de Seconde (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-11 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A et C ont des progressions différentes en Mathématiques, SVT et Français ; Physique-Chimie et Histoire-Géographie ont des premières leçons communes.

#### 2nde A (12)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/calcul-numerique.json` | Calcul numérique | 1 | 3 | 9 | 45 |
| `mathematiques/denombrement.json` | Dénombrement | 2 | 3 | 9 | 45 |
| `mathematiques/calcul-litteral.json` | Calcul littéral | 3 | 3 | 9 | 45 |
| `physique-chimie/le-mouvement.json` | Le mouvement | 1 | 3 | 9 | 45 |
| `physique-chimie/l-element-chimique.json` | L'élément chimique | 2 | 3 | 9 | 45 |
| `physique-chimie/structure-de-l-atome.json` | Structure de l'atome | 3 | 3 | 9 | 45 |
| `svt/la-transmission-d-un-message-nerveux.json` | La transmission d'un message nerveux | 1 | 3 | 9 | 49 |
| `svt/la-transmission-d-un-message-hormonal.json` | La transmission d'un message hormonal | 2 | 3 | 9 | 48 |
| `svt/les-grands-ensembles-environnementaux.json` | Les grands ensembles environnementaux | 3 | 3 | 9 | 48 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 1 | 3 | 9 | 48 |
| `francais/les-techniques-de-communication.json` | Les techniques de communication | 2 | 3 | 9 | 48 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 3 | 3 | 9 | 48 |

#### 2nde C (12)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/vecteurs-et-points-du-plan.json` | Vecteurs et points du plan | 1 | 4 | 12 | 67 |
| `mathematiques/ensemble-des-nombres-reels.json` | Ensemble des nombres réels | 2 | 3 | 9 | 48 |
| `mathematiques/utilisation-des-symetries-et-translations.json` | Utilisation des symétries et translations | 3 | 3 | 9 | 48 |
| `physique-chimie/le-mouvement.json` | Le mouvement | 1 | 3 | 9 | 45 |
| `physique-chimie/l-element-chimique.json` | L'élément chimique | 2 | 3 | 9 | 45 |
| `physique-chimie/structure-de-l-atome.json` | Structure de l'atome | 3 | 3 | 9 | 45 |
| `svt/l-absorption-de-l-eau-par-la-plante-verte.json` | L'absorption de l'eau par la plante verte | 1 | 3 | 9 | 45 |
| `svt/l-influence-des-sels-mineraux-sur-la-croissance-de-la-plante-verte.json` | L'influence des sels minéraux sur la croissance de la plante verte | 2 | 3 | 9 | 45 |
| `svt/l-absorption-des-sels-mineraux-par-la-plante-verte.json` | L'absorption des sels minéraux par la plante verte | 3 | 3 | 9 | 45 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 1 | 3 | 9 | 48 |
| `francais/les-techniques-de-communication.json` | Les techniques de communication | 2 | 3 | 9 | 48 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 3 | 3 | 9 | 48 |

#### 2nde (commune à toutes les séries) (3)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `histoire-geographie/histoire-l-histoire-et-la-formation-du-citoyen.json` | Histoire — L'Histoire et la formation du citoyen | 1 | 3 | 9 | 46 |
| `histoire-geographie/geographie-la-geographie-objet-interet-et-demarche.json` | Géographie — La géographie : objet, intérêt et démarche | 2 | 3 | 9 | 45 |
| `histoire-geographie/histoire-les-methodes-d-etude-de-l-histoire.json` | Histoire — Les méthodes d'étude de l'histoire | 3 | 3 | 9 | 45 |

**27 cours, 82 fiches, 246 exercices, 1272 questions, 4458 propositions.** Tous passent `script/contenus/valider.rb`, et `ctrlchars.rb` ne signale aucun caractère de contrôle. Importés en un seul envoi sur une base jetable : **27 cours créés, aucun ignoré, aucun refusé**.

**Ce qui a été repris, ce qui a été rédigé.**

- **Rédigées pour leur série** (21) : Maths A et C ; SVT A et C ; Français A ; Physique-Chimie A ; Histoire-Géographie (commune, sans `series_name`).
- **Copiées vers la série C** (6) : Physique-Chimie et Français ont les mêmes trois premières leçons en A et en C. La copie reprend la leçon de la série A, avec la série C et le nom et le sous-titre de la progression C.

**Attention à l'import.**

- La série fait partie de la clé de doublon (nom, niveau, matière, série). Un cours sans série n'est donc pas un doublon d'un cours de série.
- Un cours déjà présent est ignoré, jamais mis à jour. Si une progression de 2nde a déjà été importée, les cours de ces leçons existent vides : le **renommer, l'archiver**, puis importer le cours complet.
- Histoire-Géographie : les cours rédigés n'ont pas de série, comme la progression. Un cours vide de la progression, créé avec une série, ne sera pas reconnu comme doublon.

À faire valider par un enseignant (le programme détaillé n'était pas disponible) :

- **Toutes les leçons** : le champ `subtitle` de la dernière fiche porte parfois un « À compléter : … » qui liste ce que le rédacteur a laissé de côté. L'élève le voit. À compléter ou à effacer après validation.
- **Mathématiques** : les pourcentages et les identités remarquables (A), le critère de colinéarité et la valeur absolue (C), la démonstration de l'irrationalité de √2 (C).
- **Physique-Chimie** : la notion d'accélération (leçon 1), les formules des molécules et des ions (leçon 2), le nombre de masse (leçon 3).
- **SVT** : le potentiel d'action et les hormones précises (A), le déboisement et les pluies (A), le transport actif et la respiration comme source d'énergie (C), la liste des symptômes de carence (C).
- **Français** : la focalisation et les rôles adjuvant et opposant (A), le discours direct et indirect et la lettre (A), les fonctions du langage (A).
- **Histoire-Géographie** : la « mémoire collective » et le « patrimoine », la convention « l'histoire commence avec les premiers textes », le contexte de la décolonisation dans l'exemple de la leçon 1.


## Contraintes de l'application, vérifiées pendant le test

- **Pas de tableau dans une fiche de révision.** L'application supprime `table`, `tr`, `td` et `th`, et ne garde que le texte des cellules. Les balises conservées sont `h2`, `h3`, `p`, `ul`, `ol`, `li`, `strong`, `em` et `blockquote`.
- **Formules KaTeX** (`$…$`, `$$…$$`). Elles sont rendues dans les fiches de révision, les questions, les propositions et les explications, mais pas dans les noms ni les titres. L'extension chimie `\ce` n'est pas chargée : on écrit les formules chimiques en indices Unicode (CH₃–CH₂–OH).
- **Ordre des propositions.** L'application les mélange à chaque session.
