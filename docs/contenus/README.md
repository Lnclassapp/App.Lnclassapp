# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les fiches de cours de l'année, le **prompt** qui rédige une leçon complète (fiche de cours, fiches de révision, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 fiches de cours sans fiche de révision), à importer depuis **Imports → Fiches de cours complètes**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt à donner à un modèle pour rédiger une leçon : règle de l'analogie, structure d'une fiche de révision, 3 exercices par fiche de révision, contraintes de l'application. Il produit **un seul fichier** `lnclass.course-tree` : la fiche de cours, ses fiches de révision et leurs exercices |
| [`prompt-redaction-lot.md`](prompt-redaction-lot.md) | La version « lot par niveau » : pour un niveau et une série (Tle D, 1ère D, 3ème…), il prend les 3 premières leçons de chaque matière du niveau (jusqu’à 18), les rédige une par une avec `prompt-redaction.md`, les contrôle (script puis relecture indépendante) et les range dans `lecons-traitees/`. Un appel = un niveau |
| [`../../script/contenus/valider.rb`](../../script/contenus/valider.rb) | Le contrôle mécanique d’un fichier de leçon contre les règles du prompt : `ruby script/contenus/valider.rb fichier.json`. Ruby pur, code de sortie 1 s’il y a une erreur |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt, un fichier `lnclass.course-tree` par fiche de cours complète, rangées par niveau et série, puis par matière. Pour l’instant `tle-d/` (18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Histoire-Géographie, Philosophie et Français) et `3eme/` (18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Français, Histoire-Géographie et EDHC) |

## Le principe

La force de Lnclass, c'est que l'élève comprend du premier coup. Chaque notion passe par une **image du quotidien** que l'élève connaît déjà, avant la définition exacte, dans cet ordre :

1. l'image ;
2. le pont entre l'image et la notion ;
3. la notion exacte ;
4. la limite de l'image.

Exemple de référence, le théorème des gendarmes : deux policiers tiennent un prisonnier par les bras. S'ils arrivent tous les deux au commissariat, le prisonnier y arrive aussi.

## Utiliser le prompt

1. Copier le prompt, puis remplir son bloc **ENTRÉE** : intitulé exact de la leçon (celui de la progression), niveau, série, matière, rang dans la progression.
2. Importer le JSON obtenu depuis **Imports → Fiches de cours complètes**. **Un seul import** crée la fiche de cours, ses fiches de révision et les exercices de chaque fiche de révision, en brouillon. On peut choisir **jusqu'à 50 fichiers d'un coup** (50 Mo au total, 500 fiches de cours au plus) : ils forment un seul import, avec une ligne de bilan par fichier. Une même fiche de cours présente dans deux fichiers de l'envoi n'est importée dans aucun des deux.
3. Faire relire le contenu par un enseignant de la discipline, puis publier.
4. Ranger le fichier dans `lecons-traitees/<niveau>-<série>/<matière>/` (le slug de la matière : `mathematiques`, `physique-chimie`, `svt`, `histoire-geographie`, `philosophie`, `francais`…) et ajouter une ligne au tableau ci-dessous.

Pour toutes les matières d’un niveau d’un coup, utiliser plutôt [`prompt-redaction-lot.md`](prompt-redaction-lot.md).

## Ordre des imports

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
| `mathematiques/calcul-litteral.json` | Calcul littéral | 4 | 12 | 63 |
| `mathematiques/proprietes-de-thales-dans-un-triangle.json` | Propriétés de Thalès dans un triangle | 4 | 12 | 66 |
| `mathematiques/racines-carrees.json` | Racines carrées | 4 | 12 | 72 |
| `physique-chimie/masse-et-poids-d-un-corps.json` | Masse et poids d'un corps | 4 | 12 | 71 |
| `physique-chimie/les-forces.json` | Les forces | 4 | 12 | 68 |
| `physique-chimie/equilibre-d-un-solide-soumis-a-deux-forces.json` | Équilibre d'un solide soumis à deux forces | 4 | 12 | 71 |
| `svt/les-aliments-et-l-homme.json` | Les aliments et l'Homme | 4 | 12 | 69 |
| `svt/la-digestion-des-aliments.json` | La digestion des aliments | 4 | 12 | 60 |
| `svt/le-sang.json` | Le sang | 4 | 12 | 68 |
| `francais/l-expression-des-circonstances-dans-la-phrase-simple-et-dans-la-phrase-complexe.json` | L'expression des circonstances dans la phrase simple et dans la phrase complexe | 4 | 12 | 72 |
| `francais/le-dialogue-oral.json` | Le dialogue oral | 4 | 12 | 65 |
| `francais/le-texte-argumentatif.json` | Le texte argumentatif | 4 | 12 | 72 |
| `histoire-geographie/histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire.json` | Histoire — Le mouvement impérialiste et la colonisation en Côte d'Ivoire | 4 | 12 | 60 |
| `histoire-geographie/geographie-les-atouts-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les atouts du développement économique de la Côte d'Ivoire | 4 | 12 | 65 |
| `histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json` | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 4 | 12 | 60 |
| `edhc/les-devoirs-des-parents.json` | Les devoirs des parents | 4 | 12 | 60 |
| `edhc/les-organisations-humanitaires.json` | Les organisations humanitaires | 4 | 12 | 60 |
| `edhc/les-instruments-et-les-mecanismes-de-protection-contre-les-violences-faites-aux-personnes-vulnerables.json` | Les instruments et les mécanismes de protection contre les violences faites aux personnes vulnérables | 4 | 12 | 72 |

Les 18 fichiers suivent le prompt complet : 4 fiches par cours, 3 exercices par fiche. Chacun a passé `script/contenus/valider.rb`, puis une relecture par un second rédacteur, qui a refait les calculs et vérifié les faits. Les défauts trouvés ont été corrigés. Importés ensemble sur une base jetable par la vraie chaîne d'import : **18 cours, 72 fiches, 216 exercices, 1 194 questions, 4 370 propositions, sans erreur**, une fois la matière EDHC créée. Sans elle, les 3 cours d'EDHC sont rejetés (`unknown_material`) et les 15 autres passent. Aucun enseignant ne les a encore relus.

À faire valider par un enseignant (le programme détaillé n'était pas disponible) :

- **Toutes les leçons** : le champ `subtitle` de la dernière fiche porte un « À compléter : … » qui liste ce que le rédacteur a laissé de côté. L'élève le voit. À compléter ou à effacer après validation.
- **Maths** : les fractions rationnelles, la rationalisation du dénominateur et les triangles semblables ne sont pas traités (rattachement à la 3ème incertain). Le « papillon » de Thalès et le non-parallélisme y sont.
- **Physique-Chimie** : la fiche « réaction du support » (équilibre) est peut-être de niveau lycée. g vaut 10 N/kg partout, et 1,6 N/kg sur la Lune. Le contact localisé et réparti, et le mot « tension du fil », sont à confirmer.
- **SVT** : les valeurs énergétiques 17 / 17 / 38 kJ par gramme, les tests de Fehling et du biuret, les noms d'enzymes et leurs conditions d'action, la fibrine, la phagocytose et la coagulation.
- **Français** : l'opposition et la concession (« bien que », « même si ») dans la leçon 1, convaincre et persuader et « certes… mais » dans la leçon 3. Les actes de parole et le dialogue écrit ne sont pas traités.
- **Histoire-Géographie** : les « atouts institutionnels » (OHADA, BCEAO, code des investissements), et les dates de la leçon sur l'indépendance (loi-cadre de 1956, référendum de 1958, indépendance du 7 août 1960, présidence fin 1960). L'AOF et les traités de protectorat sont cités sans date.
- **EDHC** : aucun article de loi, aucune date, aucun numéro d'urgence. Les noms des conventions et chartes citées (femmes, personnes handicapées, enfant, Protocole de Maputo) sont écrits de mémoire, et la ratification par la Côte d'Ivoire n'est pas affirmée. La matière EDHC n'existe pas dans le référentiel : il faut la créer avant d'importer les 3 cours.

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

### 1ère — `lecons-traitees/1ere-a/`, `1ere-c/`, `1ere-d/`, `1ere/`

Les 3 premières leçons de chaque matière de Première (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A, C et D ont des progressions différentes, et Histoire-Géographie est commune à toutes les séries. Dans le référentiel de Develop, la 1ère n'a que les séries A, C et D : les anciens jeux « 1ère A1 » et « 1ère A2 », au contenu identique, sont fusionnés en « 1ère A ».

#### 1ère A (15)

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
