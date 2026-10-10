# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les cours de l'année, le **prompt** qui rédige une leçon complète (cours, fiches essentielles, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 cours sans fiche), à importer depuis **Imports → Cours complets**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt à donner à un modèle pour rédiger une leçon : règle de l'analogie, structure d'une fiche, 3 exercices par fiche, contraintes de l'application. Il produit **un seul fichier** `lnclass.course-tree` : le cours, ses fiches et leurs exercices |
| [`prompt-redaction-lot.md`](prompt-redaction-lot.md) | La version « lot par niveau » : pour un niveau et une série (Tle D, 1ère D, 3ème…), il prend les 3 premières leçons de chaque matière du niveau (jusqu’à 18), les rédige une par une avec `prompt-redaction.md`, les contrôle (script puis relecture indépendante) et les range dans `lecons-traitees/`. Un appel = un niveau |
| [`../../script/contenus/valider.rb`](../../script/contenus/valider.rb) | Le contrôle mécanique d’un fichier de leçon contre les règles du prompt : `ruby script/contenus/valider.rb fichier.json`. Ruby pur, code de sortie 1 s’il y a une erreur |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt, un fichier `lnclass.course-tree` par cours complet, rangées par niveau et série, puis par matière. Pour l’instant `tle-d/` (18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Histoire-Géographie, Philosophie et Français) et `3eme/` (18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Français, Histoire-Géographie et EDHC) |

## Le principe

La force de Lnclass, c'est que l'élève comprend du premier coup. Chaque notion passe par une **image du quotidien** que l'élève connaît déjà, avant la définition exacte, dans cet ordre :

1. l'image ;
2. le pont entre l'image et la notion ;
3. la notion exacte ;
4. la limite de l'image.

Exemple de référence, le théorème des gendarmes : deux policiers tiennent un prisonnier par les bras. S'ils arrivent tous les deux au commissariat, le prisonnier y arrive aussi.

## Utiliser le prompt

1. Copier le prompt, puis remplir son bloc **ENTRÉE** : intitulé exact de la leçon (celui de la progression), niveau, série, matière, rang dans la progression.
2. Importer le JSON obtenu depuis **Imports → Cours complets**. **Un seul import** crée le cours, ses fiches essentielles et les exercices de chaque fiche, en brouillon. On peut choisir **jusqu'à 50 fichiers d'un coup** (50 Mo au total, 500 cours au plus) : ils forment un seul import, avec une ligne de bilan par fichier. Un même cours présent dans deux fichiers de l'envoi n'est importé dans aucun des deux.
3. Faire relire le contenu par un enseignant de la discipline, puis publier.
4. Ranger le fichier dans `lecons-traitees/<niveau>-<série>/<matière>/` (le slug de la matière : `mathematiques`, `physique-chimie`, `svt`, `histoire-geographie`, `philosophie`, `francais`…) et ajouter une ligne au tableau ci-dessous.

Pour toutes les matières d’un niveau d’un coup, utiliser plutôt [`prompt-redaction-lot.md`](prompt-redaction-lot.md).

## Ordre des imports

Un import ne met jamais à jour l'existant : un cours déjà présent (même nom, niveau, matière et série) est **ignoré** comme doublon, fiches comprises. D'où l'ordre :

1. **D'abord les leçons traitées** (`lecons-traitees/`) : elles créent les cours complets.
2. **Ensuite les progressions** (`progressions-2026-2027/`) : elles créent les autres cours de l'année, vides, et ignorent ceux qui existent déjà.

Si la progression a déjà été importée, le cours de la leçon existe vide, et l'import du cours complet sera ignoré. Un cours ne se supprime pas, et un cours archivé compte encore comme doublon. Il faut donc **renommer** le cours vide dans l'écran des cours (par exemple « Limites et continuité (vide) »), l'archiver, puis importer le cours complet.

## Leçons traitées

### Tle D — `lecons-traitees/tle-d/`

| Fichier | Cours | Fiches | Exercices | Questions |
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

Les 9 leçons d'Histoire-Géographie, de Philosophie et de Français ont d'abord eu **un exercice par fiche** (format court de démonstration, 2026-10-06). Elles ont été **complétées le 2026-10-10** à 3 exercices par fiche (Comprendre, Appliquer, S'évaluer), soit 54 exercices et 311 questions ajoutés, avec le prompt [`prompt-redaction.md`](prompt-redaction.md). Chacune a ensuite été relue par un second rédacteur (calculs refaits, dates et faits vérifiés), et les défauts trouvés ont été corrigés, dans l'ancien contenu comme dans le nouveau : par exemple « 17 États africains entrent à l'ONU en 1960 » (16 États africains, 17 nouveaux membres avec Chypre), la citation de Socrate donnée comme texte exact, ou « le dernier mot du poème » qui était l'avant-dernier vers. Les 18 leçons de Tle D passent `script/contenus/valider.rb` et s'importent ensemble sans erreur sur une base jetable : 18 cours, 55 fiches, 165 exercices, 949 questions, 3 835 propositions. Aucun enseignant ne les a encore relues.

**Attention à l'import.** Un cours déjà présent est ignoré, jamais mis à jour. Si l'ancienne version de ces 9 leçons est déjà dans une base (développement, Staging ou main), il faut **renommer puis archiver** l'ancien cours avant d'importer la version complète.

À faire valider par un enseignant, en plus de la liste ci-dessous :

- **Histoire-Géographie** : « Les fondements du développement économique de la Côte d'Ivoire » traite aussi des limites du modèle (endettement, crise des années 1980, chômage), voulu par la fiche d'origine mais proche de la leçon 6.
- **Philosophie** : « La connaissance de l'homme » présente Durkheim et le fait social, proches de la leçon 4 (La vie en société). Le titre de sa dernière fiche parle de « la découverte de l'inconscient ». Dans « La dissertation philosophique » et « Le commentaire de texte philosophique », la méthode (problème, enjeu, plan dialectique) doit être cohérente avec celle de l'enseignant.
- **Français** : « Préparation à l'oral du Baccalauréat » décrit un déroulement de l'épreuve en quatre temps que personne n'a confronté au programme ivoirien ; sa méthode est proche du commentaire composé (leçon 4). Le niveau de certains sujets inventés de « La dissertation littéraire » est peut-être bas pour une Terminale.

Les 5 leçons 2 et 3 de Maths, de Physique et de SVT (2026-10-06) suivent le prompt complet, 3 exercices par fiche. Elles ont été importées sans erreur par la vraie chaîne d'import. Aucun enseignant ne les a encore relues. « Mouvement du centre d'inertie d'un solide » a 4 fiches : le mouvement circulaire uniforme, confirmé au programme par le porteur, en a une à lui.

Les 4 premiers fichiers ont été importés le 2026-09-29 sur une base neuve, par la vraie chaîne d'import, **sans aucune erreur** : 4 cours, 12 fiches, 36 exercices, 203 questions, 786 propositions. Les progressions de Maths, Physique-Chimie et SVT importées ensuite ont ignoré ces 4 cours comme doublons et créé les autres.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches. Dans « Dérivabilité et étude de fonctions », l'inégalité des accroissements finis et les dérivées successives ne le sont pas non plus (signalées dans le sous-titre de la dernière fiche). Deux explications de « Limites et continuité » dépassent 400 caractères (450 et 444).
- **Physique** : il faut vérifier que le repère de Frenet et le recours à une primitive sont au programme.
- **Chimie** : il faut vérifier que la règle de Markovnikov est au programme. DNPH, Fehling et Schiff chevauchent peut-être la leçon suivante sur les aldéhydes et cétones.
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

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

## Contraintes de l'application, vérifiées pendant le test

- **Pas de tableau dans une fiche.** L'application supprime `table`, `tr`, `td` et `th`, et ne garde que le texte des cellules. Les balises conservées sont `h2`, `h3`, `p`, `ul`, `ol`, `li`, `strong`, `em` et `blockquote`.
- **Formules KaTeX** (`$…$`, `$$…$$`). Elles sont rendues dans les fiches, les questions, les propositions et les explications, mais pas dans les noms ni les titres. L'extension chimie `\ce` n'est pas chargée : on écrit les formules chimiques en indices Unicode (CH₃–CH₂–OH).
- **Ordre des propositions.** L'application les mélange à chaque session.
