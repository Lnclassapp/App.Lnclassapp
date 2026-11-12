# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les fiches de cours de l'année, le **prompt** qui rédige une leçon complète (fiche de cours, fiches de révision, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 fiches de cours sans fiche de révision), à importer depuis **Imports → Fiches de cours complètes**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt unique et autoportant pour rédiger une leçon au **format v3**, dans les 6 matières du 1er cycle (section « Selon la matière » : ce que deviennent les blocs, textes et citations, faits et sources ; tous les types de questions de l'import, questions rédigées avec corrigé modèle, barème et critères, 50 % au moins corrigées automatiquement) : gabarit en 4 blocs par notion (À retenir, La méthode en étapes numérotées, Un exemple corrigé qui applique chaque étape, Le piège à éviter), un exercice par notion et 4 problèmes type interrogation/devoir de 3ème (BEPC), 5 questions au moins avec une correction qui refait la méthode, figures paramétrées (5 sortes). Il produit **un seul fichier** `lnclass.course-tree` version 3 |
| [`prompt-redaction-lot.md`](prompt-redaction-lot.md) | La version « lot par niveau » : pour une matière et un niveau (Français 3ème…), il prend les leçons de la progression, les rédige une par une avec `prompt-redaction.md`, les contrôle (script puis relecture IA indépendante) et les range dans `lecons-traitees/`. Un appel = une matière et un niveau |
| [`../../script/contenus/valider.rb`](../../script/contenus/valider.rb) | Le contrôle hors ligne d'un fichier v3 : `ruby script/contenus/valider.rb fichier.json`. Ruby pur, code de sortie 1 s'il y a une erreur. Mêmes règles et mêmes raisons que l'import (`format_retired`, `example_steps_mismatch`, `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`, `figure_invalid`, `figure_missing`…), plus des avertissements de rédaction |
| [`lecons-traitees/`](lecons-traitees/) | **La base** : les 60 leçons de 3ème (les 10 premières de la progression en Maths, Français, Histoire-Géographie, SVT, Physique-Chimie et EDHC) les 45 de Tle C, les 45 de Tle D, les 32 de Tle A1, les 31 de Tle A2 et les 10 d'Histoire-Géographie de Tle (#484), seules à avoir le format complet actuel de `prompt-redaction.md` (4 blocs et 2 exercices par notion, 4 problèmes, 4 sujets de devoir) et à passer `valider.rb`. Develop, Staging et le jeu standard chargent ce dossier, rien d'autre |
| [`a-reprendre/`](a-reprendre/) | Les 275 autres leçons, mises de côté avec leur arborescence : v3 sans les 4 sujets de devoir, v3 à un seul exercice par notion, ou format 1. Rien ne les charge. Détail et règle de retour : [`a-reprendre/README.md`](a-reprendre/README.md) |

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

Les leçons au format v1 et celles du format v3 incomplet ne sont plus dans `lecons-traitees/` : elles attendent dans `a-reprendre/` (chantier `base-de-lecons`). Elles reviennent quand elles ont le format complet et passent `valider.rb`. Les sections par niveau plus bas décrivent l'ancien contenu de `lecons-traitees/` : seuls `3eme/`, `tle-c/`, `tle-d/`, `tle-a1/`, `tle-a2/` et `tle/` y sont.

## Boucle courte : corriger une leçon

**modifier → aperçu → valider → PR → rechargement de cette seule leçon sur Develop**

1. **Modifier** le fichier, par exemple `docs/contenus/lecons-traitees/tle-d/mathematiques/<leçon>.json`.
2. **Aperçu** : `bin/apercu-lecon <fichier>` (ou `bin/apercu-lecon <fichier> --suivre`, qui recharge à chaque enregistrement ; Ctrl-C pour finir). En quelques secondes : `valider.rb` (s'il y a un ✗, tout s'arrête et les erreurs s'affichent), import de ce seul fichier par la vraie chaîne, la leçon de même titre étant remplacée entière, publication en cascade, puis l'adresse `http://localhost:3000/courses/<leçon>` et, si le jeu standard est chargé, un compte élève fictif du niveau et de la série. Un fichier refusé laisse la base intacte. L'aperçu refuse tout environnement autre que `development` et tout fichier hors de `docs/contenus/lecons-traitees/`.
3. **Valider** : `ruby script/contenus/valider.rb <fichier>` (l'aperçu l'a déjà joué).
4. **PR** : la CI rend le fichier modifié à 390 px et sur ordinateur.
5. **Fusion** : Develop recharge cette seule leçon, reconnue par l'empreinte SHA-256 changée du fichier (ADR-0122) ; les fichiers inchangés ne sont pas rechargés.

## Ordre des imports (historique, formats v1)

> Cette section décrit les imports v1 des leçons rangées avant la refonte. Le format v3 remplace ce mode d'emploi pour les mathématiques : voir « Le pipeline d'une leçon ».

Un import ne met jamais à jour l'existant : une fiche de cours déjà présente (même nom, niveau, matière et série) est **ignorée** comme doublon, fiches de révision comprises. D'où l'ordre :

1. **D'abord les leçons traitées** (`lecons-traitees/`) : elles créent les fiches de cours complètes.
2. **Ensuite les progressions** (`progressions-2026-2027/`) : elles créent les autres fiches de cours de l'année, vides, et ignorent celles qui existent déjà.

Si la progression a déjà été importée, la fiche de cours de la leçon existe vide, et l'import de la fiche de cours complète sera ignoré. Une fiche de cours ne se supprime pas, et une fiche de cours archivée compte encore comme doublon. Il faut donc **renommer** la fiche de cours vide dans l'écran des fiches de cours (par exemple « Limites et continuité (vide) »), l'archiver, puis importer la fiche de cours complète.

## Leçons traitées

### 1ère, 3 premières leçons de chaque série et matière, comme Thalès (chantier `lecons-1ere-2nde-debut`)

Depuis le 2026-11-12, les 3 premières leçons de la progression DPFC 2026-2027 de chaque série (A1, A2, C, D) et matière (Français, Mathématiques, Physique-Chimie, SVT, Philosophie, Histoire-Géographie) de 1ère sont revenues de `a-reprendre/` au format complet : 63 fichiers, 36 fiches distinctes (une fiche commune à plusieurs séries est écrite une fois et recopiée avec le `series_name` et le `theme` de chaque série). Chaque notion a reçu un second exercice en `fixation` de 6 questions d'au moins 4 types, et chaque leçon 4 sujets de devoir de 4 exercices de 5 ou 6 questions. Le cours, les fiches, le premier exercice, le `practice` et les 4 problèmes sont inchangés. Hors Mathématiques et Physique-Chimie, les questions ajoutées sont toutes corrigées automatiquement.

Un script hors dépôt a vérifié chaque fichier : format, `valider.rb` sur la leçon et sur chaque sujet mis à la place des problèmes, contenu d'origine identique ; sympy sur chaque calcul en Mathématiques et Physique-Chimie. Détail et points à faire valider dans [le journal du chantier](../chantiers/lecons-1ere-2nde-debut/journal.md).

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `1ere-a1/francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 28 | 163 | 106 |
| `1ere-a1/francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 4 | 28 | 154 | 104 |
| `1ere-a1/francais/oeuvre-poetique.json` | Œuvre poétique | 4 | 28 | 160 | 104 |
| `1ere-a1/mathematiques/denombrement.json` | Dénombrement | 4 | 28 | 154 | 104 |
| `1ere-a1/mathematiques/equations-et-inequations.json` | Équations et inéquations | 4 | 28 | 154 | 106 |
| `1ere-a1/mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 4 | 28 | 155 | 104 |
| `1ere-a1/philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 5 | 30 | 166 | 110 |
| `1ere-a1/philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 5 | 30 | 164 | 111 |
| `1ere-a1/philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 4 | 28 | 155 | 105 |
| `1ere-a1/physique-chimie/etude-d-un-dipole-passif-cas-d-un-resistor.json` | Étude d'un dipôle passif : cas d'un résistor | 4 | 28 | 167 | 107 |
| `1ere-a1/physique-chimie/les-alcanes.json` | Les alcanes | 5 | 30 | 166 | 110 |
| `1ere-a1/physique-chimie/les-alcenes-cas-de-l-ethylene.json` | Les alcènes : cas de l'éthylène | 5 | 30 | 171 | 111 |
| `1ere-a1/svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 5 | 30 | 155 | 110 |
| `1ere-a1/svt/les-anomalies-chromosomiques.json` | Les anomalies chromosomiques | 3 | 26 | 143 | 98 |
| `1ere-a1/svt/les-effets-des-drogues-sur-le-comportement.json` | Les effets des drogues sur le comportement | 4 | 28 | 152 | 104 |
| `1ere-a2/francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 28 | 163 | 106 |
| `1ere-a2/francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 4 | 28 | 154 | 104 |
| `1ere-a2/francais/oeuvre-poetique.json` | Œuvre poétique | 4 | 28 | 160 | 104 |
| `1ere-a2/mathematiques/denombrement.json` | Dénombrement | 4 | 28 | 154 | 104 |
| `1ere-a2/mathematiques/equations-et-inequations.json` | Équations et inéquations | 4 | 28 | 154 | 106 |
| `1ere-a2/mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 4 | 28 | 155 | 104 |
| `1ere-a2/philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 5 | 30 | 166 | 110 |
| `1ere-a2/philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 5 | 30 | 164 | 111 |
| `1ere-a2/philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 4 | 28 | 155 | 105 |
| `1ere-a2/physique-chimie/etude-d-un-dipole-passif-cas-d-un-resistor.json` | Étude d'un dipôle passif : cas d'un résistor | 4 | 28 | 167 | 107 |
| `1ere-a2/physique-chimie/les-alcanes.json` | Les alcanes | 5 | 30 | 166 | 110 |
| `1ere-a2/physique-chimie/les-alcenes-cas-de-l-ethylene.json` | Les alcènes : cas de l'éthylène | 5 | 30 | 171 | 111 |
| `1ere-a2/svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 5 | 30 | 155 | 110 |
| `1ere-a2/svt/les-anomalies-chromosomiques.json` | Les anomalies chromosomiques | 3 | 26 | 143 | 98 |
| `1ere-a2/svt/les-effets-des-drogues-sur-le-comportement.json` | Les effets des drogues sur le comportement | 4 | 28 | 152 | 104 |
| `1ere-c/francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 28 | 163 | 106 |
| `1ere-c/francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 4 | 28 | 154 | 104 |
| `1ere-c/francais/oeuvre-poetique.json` | Œuvre poétique | 4 | 28 | 160 | 104 |
| `1ere-c/mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 4 | 28 | 154 | 106 |
| `1ere-c/mathematiques/equations-et-inequations-dans.json` | Équations et inéquations dans ℝ | 4 | 28 | 156 | 107 |
| `1ere-c/mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 5 | 30 | 169 | 113 |
| `1ere-c/philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 5 | 30 | 166 | 110 |
| `1ere-c/philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 5 | 30 | 164 | 111 |
| `1ere-c/philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 4 | 28 | 155 | 105 |
| `1ere-c/physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 7 | 34 | 196 | 122 |
| `1ere-c/physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-rotation-autour-d-un-axe-fixe.json` | Travail et puissance dans le cas d'un mouvement de rotation autour d'un axe fixe | 4 | 28 | 166 | 105 |
| `1ere-c/physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance dans le cas d'un mouvement de translation | 5 | 30 | 177 | 111 |
| `1ere-c/svt/la-division-meiotique.json` | La division méiotique | 4 | 28 | 150 | 104 |
| `1ere-c/svt/la-gametogenese-chez-les-mammiferes.json` | La gamétogénèse chez les mammifères | 4 | 28 | 152 | 104 |
| `1ere-c/svt/le-role-et-la-structure-des-gonades-des-mammiferes.json` | Le rôle et la structure des gonades des mammifères | 4 | 28 | 150 | 104 |
| `1ere-d/francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 28 | 163 | 106 |
| `1ere-d/francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 4 | 28 | 154 | 104 |
| `1ere-d/francais/oeuvre-poetique.json` | Œuvre poétique | 4 | 28 | 160 | 104 |
| `1ere-d/mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 4 | 28 | 152 | 104 |
| `1ere-d/mathematiques/equations-et-inequations-du-second-degre-dans.json` | Équations et inéquations du second degré dans ℝ | 4 | 28 | 158 | 104 |
| `1ere-d/mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 5 | 30 | 170 | 115 |
| `1ere-d/philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 5 | 30 | 166 | 110 |
| `1ere-d/philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 5 | 30 | 164 | 111 |
| `1ere-d/philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 4 | 28 | 155 | 105 |
| `1ere-d/physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 7 | 34 | 196 | 122 |
| `1ere-d/physique-chimie/hydrocarbures-satures-les-alcanes.json` | Hydrocarbures saturés : les alcanes | 7 | 34 | 192 | 122 |
| `1ere-d/physique-chimie/travail-et-puissance-d-une-force-constante-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance d'une force constante dans le cas d'un mouvement de translation | 5 | 30 | 177 | 111 |
| `1ere-d/svt/la-division-meiotique.json` | La division méiotique | 4 | 28 | 150 | 104 |
| `1ere-d/svt/la-gametogenese.json` | La gamétogénèse | 4 | 28 | 154 | 104 |
| `1ere-d/svt/les-fonctions-des-gonades.json` | Les fonctions des gonades | 4 | 28 | 154 | 104 |
| `1ere/histoire-geographie/geographie-dynamisme-demographique-et-qualite-de-la-vie-en-cote-d-ivoire.json` | Géographie — Dynamisme démographique et qualité de la vie en Côte d'Ivoire | 3 | 26 | 145 | 99 |
| `1ere/histoire-geographie/histoire-l-essor-du-capitalisme-et-ses-consequences.json` | Histoire — L'essor du capitalisme et ses conséquences | 4 | 28 | 156 | 105 |
| `1ere/histoire-geographie/histoire-les-revolutions-industrielles.json` | Histoire — Les révolutions industrielles | 5 | 30 | 170 | 111 |
| **Total** | | | | **10126** | **6749** |

### Tle C au format 3 : deux exercices par notion et quatre sujets (chantier `lecons-tle-c-comme-thales`, #484)

Depuis le 2026-11-07, les 45 leçons de Tle C au format 3 (Mathématiques 10, Français 6, Philosophie 9, Physique-Chimie 10, SVT 10) sont construites comme la leçon Thalès de 3ème. Chaque notion a deux exercices : le premier, d'origine, et un second en `fixation` de 6 questions de types mêlés, avec titre, énoncé « Dans cet exercice, tu … » et indice. Chaque leçon a 4 sujets de devoir (« Sujet 1 · … » à « Sujet 4 · … ») de 4 exercices de 5 ou 6 questions, en `evaluation`. Le cours, les fiches et les 4 problèmes sont inchangés. Hors Mathématiques et Physique-Chimie, les questions ajoutées sont toutes corrigées automatiquement. 4 874 questions ajoutées, 7 figures ajoutées (SVT).

Un script hors dépôt a vérifié chaque leçon : sympy sur chaque question en Mathématiques et sur chaque calcul en Physique-Chimie, la bonne réponse comme chaque mauvaise proposition, avec des réponses faussées exprès toutes détectées ; ailleurs, un extrait mot pour mot de la leçon pour chaque bonne réponse. Chaque leçon a ensuite été relue par un agent qui ne l'avait pas écrite. Les tableaux des sections Tle C plus bas donnent l'état d'avant ce chantier ; ceux-ci comptent tout (exercices des notions, problèmes et exercices des sujets). Le détail est dans [le journal du chantier](../chantiers/lecons-tle-c-comme-thales/journal.md).

Les leçons de même fiche en Tle D, A1 et A2 ne sont pas encore modifiées : la liste est dans le journal.

**Mathématiques**

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `mathematiques/barycentre-et-lignes-de-niveaux.json` | Barycentre et lignes de niveaux | 5 | 30 | 168 | 121 |
| `mathematiques/coniques.json` | Coniques | 5 | 30 | 168 | 111 |
| `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions | 5 | 30 | 170 | 112 |
| `mathematiques/divisibilite-dans.json` | Divisibilité dans ℤ | 4 | 28 | 159 | 104 |
| `mathematiques/fonctions-exponentielles-et-fonctions-puissances.json` | Fonctions exponentielles et fonctions puissances | 5 | 30 | 156 | 110 |
| `mathematiques/fonctions-logarithmes.json` | Fonctions logarithmes | 5 | 30 | 192 | 119 |
| `mathematiques/geometrie-analytique-de-l-espace.json` | Géométrie analytique de l'espace | 4 | 28 | 151 | 104 |
| `mathematiques/limites-et-continuite.json` | Limites et continuité | 5 | 30 | 166 | 114 |
| `mathematiques/nombres-complexes.json` | Nombres complexes | 5 | 30 | 185 | 118 |
| `mathematiques/primitives.json` | Primitives | 4 | 28 | 160 | 106 |
| **Total** | | **47** | **294** | **1675** | **1119** |

**Français**

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `francais/groupement-de-textes-theatraux.json` | Groupement de textes théâtraux | 4 | 28 | 153 | 105 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire | 4 | 28 | 153 | 105 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 28 | 154 | 104 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 4 | 28 | 153 | 104 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat | 4 | 28 | 157 | 106 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 4 | 28 | 159 | 104 |
| **Total** | | **24** | **168** | **929** | **628** |

**Philosophie**

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `philosophie/dieu-et-la-religion.json` | Dieu et la religion | 4 | 28 | 159 | 106 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme | 4 | 28 | 147 | 105 |
| `philosophie/la-connaissance-scientifique.json` | La connaissance scientifique | 4 | 28 | 155 | 107 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique | 4 | 28 | 154 | 105 |
| `philosophie/la-valeur-de-la-philosophie.json` | La valeur de la philosophie | 4 | 28 | 166 | 116 |
| `philosophie/la-vie-en-societe.json` | La vie en société | 3 | 26 | 146 | 104 |
| `philosophie/langage-et-verite.json` | Langage et vérité | 4 | 28 | 161 | 113 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique | 4 | 28 | 157 | 107 |
| `philosophie/progres-et-bonheur.json` | Progrès et bonheur | 4 | 28 | 152 | 104 |
| **Total** | | **35** | **250** | **1397** | **967** |

**Physique-Chimie**

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `physique-chimie/acides-carboxyliques-et-derives.json` | Acides carboxyliques et dérivés | 4 | 28 | 149 | 104 |
| `physique-chimie/champ-magnetique.json` | Champ magnétique | 4 | 28 | 160 | 109 |
| `physique-chimie/cinematique-du-point.json` | Cinématique du point | 4 | 28 | 158 | 104 |
| `physique-chimie/composes-carbonyles-aldehydes-et-cetones.json` | Composés carbonylés : aldéhydes et cétones | 5 | 30 | 161 | 110 |
| `physique-chimie/fabrication-d-un-savon.json` | Fabrication d'un savon | 5 | 30 | 173 | 115 |
| `physique-chimie/interaction-gravitationnelle.json` | Interaction gravitationnelle | 4 | 28 | 157 | 104 |
| `physique-chimie/les-alcools.json` | Les alcools | 5 | 30 | 174 | 116 |
| `physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide | 4 | 28 | 157 | 104 |
| `physique-chimie/mouvements-dans-les-champs-g-et-e-uniformes.json` | Mouvements dans les champs g⃗ et E⃗ uniformes | 4 | 28 | 170 | 113 |
| `physique-chimie/oscillations-mecaniques-libres.json` | Oscillations mécaniques libres | 5 | 30 | 167 | 115 |
| **Total** | | **44** | **288** | **1626** | **1094** |

**SVT**

| Fichier | Titre | Notions | Exercices | Questions | dont ajoutées |
|---|---|---:|---:|---:|---:|
| `svt/l-exploitation-des-gisements-petroliferes.json` | L'exploitation des gisements pétrolifères | 4 | 28 | 157 | 104 |
| `svt/l-infection-de-l-organisme-par-le-vih.json` | L'infection de l'organisme par le VIH | 4 | 28 | 165 | 116 |
| `svt/l-utilisation-de-l-energie-par-la-cellule-musculaire.json` | L'utilisation de l'énergie par la cellule musculaire | 4 | 28 | 160 | 108 |
| `svt/la-communication-nerveuse.json` | La communication nerveuse | 5 | 30 | 167 | 111 |
| `svt/la-mise-en-place-des-gisements-petroliferes-en-cote-d-ivoire.json` | La mise en place des gisements pétrolifères en Côte d'Ivoire | 4 | 28 | 157 | 106 |
| `svt/la-production-d-energie-par-la-cellule.json` | La production d'énergie par la cellule | 4 | 28 | 161 | 104 |
| `svt/la-transmission-d-un-caractere-hereditaire-chez-l-homme.json` | La transmission d'un caractère héréditaire chez l'Homme | 3 | 26 | 142 | 99 |
| `svt/le-systeme-de-defense-de-l-organisme.json` | Le système de défense de l'organisme | 5 | 30 | 171 | 110 |
| `svt/les-cycles-sexuels-chez-la-femme.json` | Les cycles sexuels chez la femme | 4 | 28 | 156 | 104 |
| `svt/les-drogues-et-le-systeme-nerveux.json` | Les drogues et le système nerveux | 4 | 28 | 148 | 104 |
| **Total** | | **41** | **282** | **1584** | **1066** |



### Tle, Histoire-Géographie : deux exercices par notion et quatre sujets (chantier `lecons-tle-comme-thales`, #484)

Depuis le 2026-11-09, les 10 leçons d'Histoire-Géographie communes à toutes les séries de Terminale (dossier `tle/`, 6 d'histoire et 4 de géographie) ont un 2e exercice par notion et 4 sujets de devoir. Aucune n'est partagée avec un autre dossier : chacune a été rédigée, prouvée par des extraits de la leçon (et par calcul pour les questions chiffrées) et relue une par une. Les faits, dates et chiffres viennent tous de la leçon d'origine ; les documents des sujets sont écrits pour Lnclass, sans fausse citation. 1 146 questions ajoutées, aucune figure. Le détail est dans [le journal du chantier](../chantiers/lecons-tle-comme-thales/journal.md).

### Tle A2 au format 3 : deux exercices par notion et quatre sujets (chantier `lecons-tle-a2-comme-thales`, #484)

Depuis le 2026-11-08, les 31 leçons de Tle A2 au format 3 (Français 7, Philosophie 10, Mathématiques 7, SVT 7) sont construites comme celles de Tle A1. 30 leçons ont la même fiche qu'en Tle A1 (exponentielle et logarithme à une définition près, sans primitive en A2) : leurs ajouts sont repris de Tle A1 et recontrôlés par le script ; exponentielle et logarithme ont été relus pour le programme de A2. « Probabilité », propre à la Tle A2, a été rédigée, prouvée par énumération et relue : 110 questions ajoutées, aucune figure. Le détail est dans [le journal du chantier](../chantiers/lecons-tle-a2-comme-thales/journal.md).

### Tle A1 au format 3 : deux exercices par notion et quatre sujets (chantier `lecons-tle-a1-comme-thales`, #484)

Depuis le 2026-11-08, les 32 leçons de Tle A1 au format 3 (Français 7, Philosophie 10, Mathématiques 8, SVT 7) sont construites comme celles de Tle C et de Tle D : un second exercice `fixation` de 6 questions par notion et 4 sujets de devoir. 15 leçons ont la même fiche qu'en Tle C et D : leurs ajouts sont repris tels quels (Français 6, Philosophie 9). Les 17 leçons propres à la Tle A1 (Français 1, Philosophie 1, Mathématiques 8, SVT 7) ont été rédigées, contrôlées par le même script hors dépôt (sympy en Mathématiques, extraits ailleurs, réponses faussées toutes détectées) et relues chacune par un agent qui ne l'avait pas écrite : 1 908 questions ajoutées, aucune figure. Le détail est dans [le journal du chantier](../chantiers/lecons-tle-a1-comme-thales/journal.md).

### Tle D au format 3 : deux exercices par notion et quatre sujets (chantier `lecons-tle-d-comme-thales`, #484)

Depuis le 2026-11-07, les 45 leçons de Tle D au format 3 (Mathématiques 10, Français 6, Philosophie 9, Physique-Chimie 10, SVT 10) sont construites comme celles de Tle C : un second exercice `fixation` de 6 questions par notion et 4 sujets de devoir. 31 leçons ont la même fiche qu'en Tle C : leurs ajouts sont repris tels quels de Tle C (Français 6, Philosophie 9, Mathématiques 5, Physique-Chimie 8, SVT 3). Les 14 leçons propres à la Tle D (Mathématiques 5, Physique-Chimie 2, SVT 7) ont été rédigées, contrôlées par le même script hors dépôt (sympy en Mathématiques et pour les calculs de Physique-Chimie, extraits ailleurs, réponses faussées toutes détectées) et relues chacune par un agent qui ne l'avait pas écrite : 1 548 questions ajoutées, aucune figure. Le détail est dans [le journal du chantier](../chantiers/lecons-tle-d-comme-thales/journal.md).
### Tle D — `lecons-traitees/tle-d/`

> **Philosophie** : les fichiers `philosophie/` de ce dossier sont désormais au format 3 (chantier `contenus-tle-philosophie`, section « Tle, Philosophie au format 3 » plus bas).

| Fichier | Fiche de cours | Fiches de révision | Exercices | Questions |
|---|---|---:|---:|---:|
| `mathematiques/limites-et-continuite.json` | Limites et continuité (Maths) | 3 | 9 | 51 |
| `mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json` | Probabilité conditionnelle et variable aléatoire (Maths) | 3 | 9 | 54 |
| `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions (Maths) | 3 | 9 | 51 |
| `svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères (SVT) | 3 | 9 | 53 |
| `svt/le-fonctionnement-des-organes-sexuels-chez-l-homme.json` | Le fonctionnement des organes sexuels chez l'Homme (SVT) | 3 | 9 | 54 |
| `svt/la-reproduction-chez-les-spermaphytes.json` | La reproduction chez les spermaphytes (SVT) | 3 | 9 | 54 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique | 3 | 9 | 52 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique | 3 | 9 | 54 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme | 3 | 9 | 52 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 3 | 9 | 54 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire | 3 | 9 | 52 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat | 3 | 9 | 51 |

> **Histoire-Géographie** : les 3 leçons v1 de Tle (L'ONU, les fondements du développement économique de la Côte d'Ivoire, la bipolarisation), copiées dans `tle-d/`, `tle-a1/`, `tle-a2/` et `tle-c/`, sont remplacées par les 10 leçons v3 communes à toutes les séries de `lecons-traitees/tle/histoire-geographie/` (section « Tle, Histoire-Géographie au format 3 » plus bas).
Les 3 leçons de mathématiques de ce tableau (format v1) sont remplacées par leur version au format 3 : voir « Tle C et D, mathématiques au format 3 ».

Les 9 leçons d'Histoire-Géographie, de Philosophie et de Français ont d'abord eu **un exercice par fiche de révision** (format court de démonstration, 2026-10-06). Elles ont été **complétées le 2026-10-10** à 3 exercices par fiche de révision (Comprendre, Appliquer, S'évaluer), soit 54 exercices et 311 questions ajoutés, avec le prompt [`prompt-redaction.md`](prompt-redaction.md). Chacune a ensuite été relue par un second rédacteur (calculs refaits, dates et faits vérifiés), et les défauts trouvés ont été corrigés, dans l'ancien contenu comme dans le nouveau : par exemple « 17 États africains entrent à l'ONU en 1960 » (16 États africains, 17 nouveaux membres avec Chypre), la citation de Socrate donnée comme texte exact, ou « le dernier mot du poème » qui était l'avant-dernier vers. Les 18 leçons de Tle D passent `script/contenus/valider.rb` et s'importent ensemble sans erreur sur une base jetable : 18 cours, 55 fiches, 165 exercices, 949 questions, 3 835 propositions. Aucun enseignant ne les a encore relues.

**Attention à l'import.** Une fiche de cours déjà présente est ignorée, jamais mise à jour. Si l'ancienne version de ces 9 leçons est déjà dans une base (développement, Staging ou main), il faut **renommer puis archiver** l'ancienne fiche de cours avant d'importer la version complète.

À faire valider par un enseignant, en plus de la liste ci-dessous :

- **Philosophie** : « La connaissance de l'homme » présente Durkheim et le fait social, proches de la leçon 4 (La vie en société). Le titre de sa dernière fiche parle de « la découverte de l'inconscient ». Dans « La dissertation philosophique » et « Le commentaire de texte philosophique », la méthode (problème, enjeu, plan dialectique) doit être cohérente avec celle de l'enseignant.
- **Français** : « Préparation à l'oral du Baccalauréat » décrit un déroulement de l'épreuve en quatre temps que personne n'a confronté au programme ivoirien ; sa méthode est proche du commentaire composé (leçon 4). Le niveau de certains sujets inventés de « La dissertation littéraire » est peut-être bas pour une Terminale.

Les 5 leçons 2 et 3 de Maths, de Physique et de SVT (2026-10-06) suivent le prompt complet, 3 exercices par fiche de révision. Elles ont été importées sans erreur par la vraie chaîne d'import. Aucun enseignant ne les a encore relues. « Mouvement du centre d'inertie d'un solide » a 4 fiches de révision : le mouvement circulaire uniforme, confirmé au programme par le porteur, en a une à lui.

Les 4 premiers fichiers ont été importés le 2026-09-29 sur une base neuve, par la vraie chaîne d'import, **sans aucune erreur** : 4 fiches de cours, 12 fiches de révision, 36 exercices, 203 questions, 786 propositions. Les progressions de Maths, Physique-Chimie et SVT importées ensuite ont ignoré ces 4 fiches de cours comme doublons et créé les autres.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches de révision. Dans « Dérivabilité et étude de fonctions », l'inégalité des accroissements finis et les dérivées successives ne le sont pas non plus (signalées dans le sous-titre de la dernière fiche de révision). Deux explications de « Limites et continuité » dépassent 400 caractères (450 et 444).
- **Physique-Chimie** : leçons réécrites au format 3, voir « Tle C et D, Physique-Chimie au format 3 ».
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

### Tle C et D, Physique-Chimie au format 3 (chantier `contenus-tle-physique-chimie`)

Les 10 premières leçons de Physique-Chimie de Tle C et de Tle D (progression DPFC 2026-2027), rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), vague T3 du programme `contenus-v3-tous-niveaux`. **12 leçons distinctes, 20 fichiers** : une leçon commune aux deux séries est écrite une fois puis copiée avec la série et le rang de chacune (« Fabrication d'un savon » : rang 8 en C, 9 en D ; « Oscillations mécaniques libres » : 9 en C, 8 en D ; la leçon 6 garde l'intitulé de chaque série). Elles remplacent les 6 fichiers v1 de Tle C et D. Aucune sorte de figure nouvelle : repère, courbe, molécule, schéma fléché.

| Série | Rang | Fichier | Cours | Notions | Exercices | Questions | Je m'entraîne | Auto | Figures | Sortes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| C | 1 | `tle-c/physique-chimie/cinematique-du-point.json` | Cinématique du point | 4 | 8 | 54 | 12 | 98 % | 5 | `coordinate_plane`, `stat_chart line` |
| C | 2 | `tle-c/physique-chimie/les-alcools.json` | Les alcools | 5 | 9 | 58 | 15 | 98 % | 4 | `diagram`, `molecule` |
| C | 3 | `tle-c/physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide | 4 | 8 | 53 | 12 | 96 % | 4 | `coordinate_plane`, `stat_chart line` |
| C | 4 | `tle-c/physique-chimie/composes-carbonyles-aldehydes-et-cetones.json` | Composés carbonylés : aldéhydes et cétones | 5 | 9 | 51 | 15 | 98 % | 4 | `diagram`, `molecule` |
| C | 5 | `tle-c/physique-chimie/interaction-gravitationnelle.json` | Interaction gravitationnelle | 4 | 8 | 53 | 12 | 98 % | 3 | `coordinate_plane`, `stat_chart line` |
| C | 6 | `tle-c/physique-chimie/mouvements-dans-les-champs-g-et-e-uniformes.json` | Mouvements dans les champs g⃗ et E⃗ uniformes | 4 | 8 | 57 | 12 | 98 % | 6 | `coordinate_plane`, `stat_chart line` |
| C | 7 | `tle-c/physique-chimie/acides-carboxyliques-et-derives.json` | Acides carboxyliques et dérivés | 4 | 8 | 45 | 12 | 98 % | 7 | `diagram`, `molecule`, `stat_chart bars`, `stat_chart line` |
| C | 8 | `tle-c/physique-chimie/fabrication-d-un-savon.json` | Fabrication d'un savon | 5 | 9 | 58 | 15 | 98 % | 3 | `diagram`, `molecule` |
| C | 9 | `tle-c/physique-chimie/oscillations-mecaniques-libres.json` | Oscillations mécaniques libres | 5 | 9 | 52 | 15 | 98 % | 6 | `coordinate_plane`, `stat_chart line` |
| C | 10 | `tle-c/physique-chimie/champ-magnetique.json` | Champ magnétique | 4 | 8 | 51 | 12 | 98 % | 4 | `coordinate_plane`, `stat_chart line` |
| D | 1 | `tle-d/physique-chimie/cinematique-du-point.json` | Cinématique du point | 4 | 8 | 54 | 12 | 98 % | 5 | `coordinate_plane`, `stat_chart line` |
| D | 2 | `tle-d/physique-chimie/les-alcools.json` | Les alcools | 5 | 9 | 58 | 15 | 98 % | 4 | `diagram`, `molecule` |
| D | 3 | `tle-d/physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide | 4 | 8 | 53 | 12 | 96 % | 4 | `coordinate_plane`, `stat_chart line` |
| D | 4 | `tle-d/physique-chimie/composes-carbonyles-aldehydes-et-cetones.json` | Composés carbonylés : aldéhydes et cétones | 5 | 9 | 51 | 15 | 98 % | 4 | `diagram`, `molecule` |
| D | 5 | `tle-d/physique-chimie/les-amines.json` | Les amines | 5 | 9 | 57 | 15 | 98 % | 6 | `diagram`, `molecule` |
| D | 6 | `tle-d/physique-chimie/mouvements-dans-les-champs-g-et-e-uniformes.json` | Mouvements dans les champs (g⃗ et E⃗) uniformes | 4 | 8 | 57 | 12 | 98 % | 6 | `coordinate_plane`, `stat_chart line` |
| D | 7 | `tle-d/physique-chimie/acides-carboxyliques-et-derives.json` | Acides carboxyliques et dérivés | 4 | 8 | 45 | 12 | 98 % | 7 | `diagram`, `molecule`, `stat_chart bars`, `stat_chart line` |
| D | 8 | `tle-d/physique-chimie/oscillations-mecaniques-libres.json` | Oscillations mécaniques libres | 5 | 9 | 52 | 15 | 98 % | 6 | `coordinate_plane`, `stat_chart line` |
| D | 9 | `tle-d/physique-chimie/fabrication-d-un-savon.json` | Fabrication d'un savon | 5 | 9 | 58 | 15 | 98 % | 3 | `diagram`, `molecule` |
| D | 10 | `tle-d/physique-chimie/les-acides-amines.json` | Les acides α-aminés | 4 | 8 | 45 | 12 | 96 % | 5 | `diagram`, `molecule` |

Leçons distinctes : 53 notions, 634 questions notées, 159 questions « Je m'entraîne », 57 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et le contrôle de « Je m'entraîne » des tests de 3e. Chaque leçon a été relue par un sous-agent distinct de son auteur, qui a refait chaque calcul ; les défauts trouvés (une courbe d'énergie fausse, des arrondis intermédiaires, des étapes de méthode mal citées, des distracteurs peu plausibles) sont corrigés.

**Brouillon.** Aucun enseignant ne les a relues : les points à faire valider sont dans le journal du programme [`contenus-v3-tous-niveaux`](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant). Si les cours v1 de Tle C ou D sont déjà dans une base, les renommer et les archiver avant d'importer.

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

### 3ème au format 3 : deux exercices par notion et quatre sujets (chantier `lecons-3eme-comme-thales`, #484)

Depuis le 2026-11-05, les 60 leçons de 3ème au format 3 (6 matières × 10) sont toutes construites comme la leçon Thalès. Chaque notion a deux exercices : le premier, d'origine, et un second en `fixation` de 6 questions de types mêlés, avec titre, énoncé « Dans cet exercice, tu … » et indice. Chaque leçon a 4 sujets de devoir (« Sujet 1 · … » à « Sujet 4 · … ») de 4 exercices de 5 ou 6 questions, en `evaluation`. Le cours, les fiches et les 4 problèmes sont inchangés. Hors Mathématiques et Physique-Chimie, les questions ajoutées sont toutes corrigées automatiquement. Les tableaux ci-dessous comptent tout : exercices des notions, problèmes et exercices des sujets.

Un script hors dépôt a vérifié chaque leçon. Il refait les calculs avec sympy en Mathématiques et en Physique-Chimie, la bonne réponse comme chaque mauvaise proposition. Dans les autres matières, chaque question est justifiée par un extrait mot pour mot de sa leçon. Le script contrôle aussi le format, les doublons, le fichier inchangé hors ajouts (octet pour octet) et `valider.rb` sur la leçon et sur chaque sujet. Le détail est dans [le journal du chantier](../chantiers/lecons-3eme-comme-thales/journal.md).

### 3ème, mathématiques au format 3 — le pilote (chantier `refonte-contenus-maths`)

Les 10 leçons de mathématiques de la progression DPFC 2026-2027, rédigées le 2026-10-29 au format `lnclass.course-tree` v3. Chaque notion a une fiche en quatre blocs (À retenir, La méthode, Un exemple corrigé, Le piège à éviter), éventuellement une figure, et un ou deux exercices (les leçons Thalès, depuis le 2026-10-31, et Calcul littéral, depuis le 2026-11-05, en ont deux par notion, aux types de questions mélangés). La leçon a en plus 4 problèmes de 5 questions ou plus. La leçon Thalès a aussi 4 sujets de devoir de 4 exercices chacun (16 exercices, 95 questions), comptés dans le tableau, avec trois figures de plus (triangle ABC avec M et N, papillon, triangle ABC avec D et E) que ses exercices citent : un schéma fixe, car la figure interactive affiche ses propres longueurs, qui contrediraient l'énoncé. La leçon Calcul littéral a elle aussi 4 sujets de devoir de 4 exercices (16 exercices, 95 questions) et deux figures de plus (rectangle d'un étal, carré découpé en quatre morceaux), sans longueurs écrites : une étiquette de la figure interactive affiche en plus la longueur calculée du segment, qui contredirait une dimension écrite avec $x$, donc les dimensions sont dans les énoncés. Les calculs (bonnes et mauvaises réponses) sont vérifiés par un script sympy hors dépôt.

| # | Fichier | Cours | Notions | Figures | Exercices | Questions |
|---:|---|---|---:|---:|---:|---:|
| 1 | `mathematiques/calcul-litteral.json` | Calcul littéral | 4 | 2 | 28 | 173 |
| 2 | `mathematiques/proprietes-de-thales-dans-un-triangle.json` | Propriétés de Thalès dans un triangle | 3 | 5 | 26 | 153 |
| 3 | `mathematiques/racines-carrees.json` | Racines carrées | 6 | 2 | 32 | 170 |
| 4 | `mathematiques/triangle-rectangle.json` | Triangle rectangle | 4 | 5 | 28 | 150 |
| 5 | `mathematiques/calcul-numerique.json` | Calcul numérique | 4 | 1 | 28 | 146 |
| 6 | `mathematiques/angles-inscrits.json` | Angles inscrits | 4 | 9 | 28 | 159 |
| 7 | `mathematiques/vecteurs.json` | Vecteurs | 4 | 10 | 28 | 149 |
| 8 | `mathematiques/equations-et-inequations-dans-r.json` | Équations et inéquations dans ℝ | 4 | 5 | 28 | 151 |
| 9 | `mathematiques/pyramides-et-cones.json` | Pyramides et cônes | 4 | 9 | 28 | 151 |
| 10 | `mathematiques/statistique.json` | Statistique | 5 | 9 | 30 | 173 |

Au total : 42 notions, 57 figures, 284 exercices et 1 575 questions. Chaque fichier passe `script/contenus/valider.rb` sans avertissement. Chacun a été relu par un second rédacteur, qui a refait les calculs et corrigé 40 défauts. Chacun s'importe en brouillon par la vraie chaîne d'import ; c'est vérifié par `test/integration/catalog/pilot_lessons_test.rb`. Les points à faire trancher par un enseignant sont dans [`validation-enseignant.md`](../chantiers/refonte-contenus-maths/validation-enseignant.md).

### 3ème, Français au format 3 (chantier `contenus-3e-francais`)

Les 10 premières leçons de Français de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Aucune figure. Chaque leçon a au moins 77 % de questions corrigées automatiquement. Les autres questions sont rédigées : chacune a un corrigé modèle, un barème et des critères. Les textes supports sont écrits pour Lnclass. Les œuvres réelles ne sont citées que par de courtes références paraphrasées, avec auteur, titre et date.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto |
|---:|---|---|---:|---:|---:|---:|
| 1 | `francais/l-expression-des-circonstances-dans-la-phrase-simple-et-dans-la-phrase-complexe.json` | L'expression des circonstances dans la phrase simple et dans la phrase complexe | 4 | 28 | 162 | 94 % |
| 2 | `francais/le-dialogue-oral.json` | Le dialogue oral | 4 | 28 | 166 | 94 % |
| 3 | `francais/le-texte-argumentatif.json` | Le texte argumentatif | 4 | 28 | 161 | 94 % |
| 4 | `francais/etude-de-l-oeuvre-integrale-n-1.json` | Étude de l'œuvre intégrale n°1 | 4 | 28 | 169 | 94 % |
| 5 | `francais/orthographe-lexicale.json` | Orthographe lexicale | 3 | 26 | 150 | 93 % |
| 6 | `francais/la-coordination.json` | La coordination | 4 | 28 | 164 | 94 % |
| 7 | `francais/le-resume-du-texte-argumentatif.json` | Le résumé du texte argumentatif | 4 | 28 | 161 | 94 % |
| 8 | `francais/le-groupe-nominal-la-pronominalisation.json` | Le groupe nominal : la pronominalisation | 4 | 28 | 172 | 94 % |
| 9 | `francais/le-verbe-l-infinitif-et-le-participe.json` | Le verbe : l'infinitif et le participe | 3 | 26 | 149 | 93 % |
| 10 | `francais/l-expose-oral.json` | L'exposé oral | 4 | 28 | 160 | 92 % |

Au total : 38 notions, 276 exercices et 1 614 questions. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. Chacun a été relu par un second rédacteur, et les défauts trouvés ont été corrigés : règles de grammaire fausses, faits d'œuvre inexacts, fautes de langue, réponses justes refusées.

À faire valider par un enseignant :

- **Leçon 4** : les faits cités sur *Une vie de boy* (Ferdinand Oyono, 1956) et *L'Enfant noir* (Camara Laye, 1953). Le choix des œuvres reste à aligner sur la liste de l'établissement.
- **Leçon 7** : la façon de compter les mots d'un résumé (trait d'union, « c'est-à-dire », chiffres). La leçon la soumet à la consigne du sujet.
- **Leçons 8 et 9** : l'ordre des pronoms à l'impératif, la distinction entre participe présent et adjectif verbal, et les propositions infinitive et participiale, seulement citées.
- **Questions rédigées** : les barèmes, de 3 à 8 points.

### 3ème, Histoire-Géographie au format 3 (chantier `contenus-3e-histoire-geographie`)

Les 10 premières leçons d'Histoire-Géographie de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures sont les sortes livrées par ce chantier (ADR-0117, UDR-0142) : frise (`timeline`), carte (`map`, fonds `cote_d_ivoire`, `africa`, `world`), schéma (`diagram`) et courbe (`stat_chart line`).

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `histoire-geographie/histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire.json` | Histoire — Le mouvement impérialiste et la colonisation en Côte d'Ivoire | 5 | 30 | 164 | 94 % | 4 | `map africa`, `map cote_d_ivoire`, `timeline`, `diagram` |
| 2 | `histoire-geographie/geographie-les-atouts-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les atouts du développement économique de la Côte d'Ivoire | 5 | 30 | 160 | 96 % | 3 | `map cote_d_ivoire`, `stat_chart line`, `diagram` |
| 3 | `histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json` | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 5 | 30 | 161 | 97 % | 2 | `timeline`, `diagram` |
| 4 | `histoire-geographie/geographie-les-secteurs-d-activites-economiques-de-la-cote-d-ivoire.json` | Géographie — Les secteurs d'activités économiques de la Côte d'Ivoire | 4 | 28 | 153 | 96 % | 4 | `map cote_d_ivoire`, `stat_chart pie`, `diagram` |
| 5 | `histoire-geographie/histoire-causes-et-caracteres-des-crises-sociopolitiques-de-l-afrique-independante.json` | Histoire — Causes et caractères des crises sociopolitiques de l'Afrique indépendante | 4 | 28 | 152 | 97 % | 3 | `map africa`, `timeline`, `diagram` |
| 6 | `histoire-geographie/histoire-la-crise-rwandaise-de-la-guerre-au-genocide-des-tutsi-1990-1994.json` | Histoire — La crise rwandaise : de la guerre au génocide des tutsi (1990-1994) | 4 | 28 | 144 | 97 % | 2 | `map africa`, `timeline` |
| 7 | `histoire-geographie/geographie-les-problemes-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les problèmes du développement économique de la Côte d'Ivoire | 5 | 30 | 158 | 95 % | 2 | `stat_chart line`, `diagram` |
| 8 | `histoire-geographie/histoire-les-causes-les-caracteres-et-les-consequences-de-la-deuxieme-guerre-mondiale.json` | Histoire — Les causes, les caractères et les conséquences de la deuxième guerre mondiale | 4 | 28 | 154 | 95 % | 2 | `timeline`, `map world` |
| 9 | `histoire-geographie/geographie-etude-economique-de-l-afrique.json` | Géographie — Etude Economique de l'Afrique | 4 | 28 | 146 | 97 % | 4 | `map africa`, `diagram`, `timeline` |
| 10 | `histoire-geographie/histoire-l-organisation-des-nations-unies-onu.json` | Histoire — L'Organisation des Nations Unies (ONU) | 4 | 28 | 157 | 95 % | 3 | `timeline`, `diagram`, `map world` |

Au total : 44 notions, 288 exercices, 1 549 questions et 29 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. À faire relire par un enseignant d'Histoire-Géographie avant publication : dates et chiffres, et le contenu des cartes.

### 3ème, SVT au format 3 (chantier `contenus-3e-svt`)

Les 10 premières leçons de SVT de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures ajoutent les planches légendées (`plate`, 8 planches de SVT : appareil digestif, frottis sanguin, cœur, double circulation, appareil génital de la femme, virus du VIH, profil de sol, poils absorbants) aux sortes déjà livrées.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `svt/les-aliments-et-l-homme.json` | Les aliments et l'Homme | 4 | 28 | 157 | 97 % | 3 | `diagram`, `stat_chart pie` |
| 2 | `svt/la-digestion-des-aliments.json` | La digestion des aliments | 4 | 28 | 168 | 97 % | 3 | `plate digestive_system`, `diagram` |
| 3 | `svt/le-sang.json` | Le sang | 4 | 28 | 157 | 97 % | 7 | `plate blood_smear`, `stat_chart pie`, `diagram`, `stat_chart line` |
| 4 | `svt/la-transfusion-sanguine.json` | La transfusion sanguine | 3 | 26 | 145 | 97 % | 3 | `diagram` |
| 5 | `svt/la-circulation-sanguine.json` | La circulation sanguine | 4 | 28 | 161 | 98 % | 6 | `plate heart`, `plate double_circulation`, `diagram`, `stat_chart line` |
| 6 | `svt/les-grossesses-precoces-et-les-moyens-de-prevention.json` | Les grossesses précoces et les moyens de prévention | 4 | 28 | 154 | 95 % | 5 | `timeline`, `plate female_reproductive_system`, `diagram` |
| 7 | `svt/l-infection-au-vih.json` | L'infection au VIH | 3 | 26 | 145 | 97 % | 5 | `plate hiv_virus`, `stat_chart line`, `diagram` |
| 8 | `svt/les-caracteristiques-d-un-sol.json` | Les caractéristiques d'un sol | 4 | 28 | 161 | 98 % | 5 | `plate soil_profile`, `stat_chart bars` |
| 9 | `svt/les-relations-sols-plantes.json` | Les relations sols-plantes | 4 | 28 | 156 | 97 % | 9 | `plate root_hairs`, `diagram`, `stat_chart bars`, `plate soil_profile` |
| 10 | `svt/la-degradation-des-sols.json` | La dégradation des sols | 4 | 28 | 153 | 97 % | 5 | `diagram`, `plate soil_profile`, `stat_chart line` |

Au total : 38 notions, 276 exercices, 1 557 questions et 51 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement.

À faire valider par un enseignant de SVT avant publication : les 8 planches (captures envoyées au porteur), le vocabulaire du programme et les valeurs données à titre d'exemple dans les leçons.

### 3ème, Physique-Chimie au format 3 (chantier `contenus-3e-physique-chimie`)

Les 10 premières leçons de Physique-Chimie de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les fichiers antérieurs du même intitulé, dont « Les lentilles ». Les figures ajoutent le tracé optique (`optics`), la molécule (`molecule`) et 3 planches (`dynamometer`, `electrolyser`, `eudiometer`) aux sortes déjà livrées, dont le repère (`coordinate_plane`) des mathématiques.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `physique-chimie/masse-et-poids-d-un-corps.json` | Masse et poids d'un corps | 4 | 28 | 156 | 98 % | 4 | `plate dynamometer`, `coordinate_plane`, `stat_chart bars` |
| 2 | `physique-chimie/les-forces.json` | Les forces | 4 | 28 | 175 | 98 % | 5 | `coordinate_plane`, `plate dynamometer` |
| 3 | `physique-chimie/equilibre-d-un-solide-soumis-a-deux-forces.json` | Équilibre d'un solide soumis à deux forces | 4 | 28 | 151 | 97 % | 6 | `coordinate_plane`, `plate dynamometer` |
| 4 | `physique-chimie/travail-et-puissance-mecaniques.json` | Travail et puissance mécaniques | 4 | 28 | 168 | 98 % | 4 | `coordinate_plane`, `stat_chart bars` |
| 5 | `physique-chimie/energie-mecanique.json` | Énergie mécanique | 4 | 28 | 158 | 97 % | 3 | `stat_chart bars`, `coordinate_plane` |
| 6 | `physique-chimie/electrolyse-et-synthese-de-l-eau.json` | Électrolyse et synthèse de l'eau | 4 | 28 | 160 | 98 % | 6 | `plate electrolyser`, `plate eudiometer`, `molecule` |
| 7 | `physique-chimie/les-alcanes.json` | Les alcanes | 4 | 28 | 167 | 97 % | 7 | `molecule`, `stat_chart line`, `diagram` |
| 8 | `physique-chimie/les-lentilles.json` | Les lentilles | 5 | 30 | 179 | 98 % | 8 | `optics` |
| 9 | `physique-chimie/les-defauts-de-l-oeil-et-leurs-corrections.json` | Les défauts de l'œil et leurs corrections | 4 | 28 | 163 | 98 % | 6 | `optics` |
| 10 | `physique-chimie/oxydation-des-corps-purs-simples.json` | Oxydation des corps purs simples | 4 | 28 | 161 | 98 % | 4 | `molecule`, `diagram` |

Au total : 41 notions, 282 exercices, 1 638 questions et 53 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement.

À faire valider par un enseignant de Physique-Chimie avant publication : les 3 planches, et les chiffres des exercices.

### 3ème, EDHC au format 3 (chantier `contenus-3e-edhc`)

Les 10 premières leçons d'EDHC de la progression DPFC 2026-2027, rédigées le 2026-10-30 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Les figures sont celles de l'inventaire de l'ADR des figures de 3ème : schémas (`diagram`), graphiques (`stat_chart`, données fictives et dites fictives) et, à la leçon 10, la carte de Côte d'Ivoire des aires culturelles (`map`, fond `cote_d_ivoire`). Le contenu suit les textes en vigueur (Constitution du 8 novembre 2016) ; il est neutre : aucun parti ni personnalité politique réels, des situations et des personnages fictifs.

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures |
|---:|---|---|---:|---:|---:|---:|---|
| 1 | `edhc/les-devoirs-des-parents.json` | Les devoirs des parents | 4 | 28 | 153 | 94 % | `diagram` |
| 2 | `edhc/les-organisations-humanitaires.json` | Les organisations humanitaires | 4 | 28 | 159 | 96 % | `diagram` |
| 3 | `edhc/les-instruments-et-les-mecanismes-de-protection-contre-les-violences-faites-aux-personnes-vulnerables.json` | Les instruments et les mécanismes de protection contre les violences faites aux personnes vulnérables | 4 | 28 | 155 | 97 % | `diagram`, `stat_chart bars` |
| 4 | `edhc/les-partis-politiques.json` | Les partis politiques | 4 | 28 | 152 | 97 % | `diagram` |
| 5 | `edhc/les-institutions-juridictionnelles.json` | Les institutions juridictionnelles | 4 | 28 | 145 | 97 % | `diagram` |
| 6 | `edhc/le-scrutin-electoral.json` | Le scrutin électoral | 5 | 30 | 170 | 98 % | `diagram`, `stat_chart bars`, `stat_chart pie` |
| 7 | `edhc/le-civisme-fiscal.json` | Le civisme fiscal | 4 | 28 | 150 | 97 % | `diagram`, `stat_chart pie` |
| 8 | `edhc/la-gestion-des-biens-publics.json` | La gestion des biens publics | 4 | 28 | 153 | 97 % | `diagram`, `stat_chart bars` |
| 9 | `edhc/le-projet-d-entreprise.json` | Le projet d'entreprise | 5 | 30 | 168 | 98 % | `diagram`, `stat_chart line` |
| 10 | `edhc/les-alliances-interethniques-les-mande-et-les-gour.json` | Les alliances interethniques : les Mandé et les Gour | 4 | 28 | 151 | 97 % | `diagram`, `map` |

Au total : 42 notions, 284 exercices, 1 556 questions et 24 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. Chacun a été relu par un second modèle (Opus) qui n'en était pas l'auteur, et les défauts trouvés ont été corrigés : questions à deux bonnes réponses, faits inexacts (CEDEF, Croix-Rouge), noms à connotation régionale ou ethnique, district oublié sur la carte, corrections qui désignaient une proposition par sa position.

À faire valider par un enseignant :

- **Textes** : aucun numéro d'article n'est cité ; les renvois à la Constitution de 2016 et aux lois (scolarité obligatoire, partis politiques, Code pénal) sont à confirmer dans leur formulation.
- **Leçon 2** : le rangement de la Croix-Rouge (branche à part, ni ONG ni organisation des États), à aligner sur le manuel en usage.
- **Leçons 5 et 6** : compétences des tribunaux de commerce, de la Haute Cour de justice et du Conseil constitutionnel ; seule la présidentielle est affirmée pour les résultats définitifs du Conseil constitutionnel.
- **Leçon 7** : la distinction entre taxe et redevance.
- **Leçon 10** : le rattachement des peuples aux groupes Mandé et Gour, les termes « toukpê » et « sanankouya », et la carte, qui ne colorie que les districts où un groupe est majoritaire de façon sûre (Montagnes, Vallée du Bandama et Sassandra-Marahoué restent blancs). Aucune alliance précise entre deux peuples réels n'est affirmée.

### Tle, Histoire-Géographie au format 3 (chantier `contenus-tle-histoire-geographie`) — `lecons-traitees/tle/`

Les 10 premières leçons d'Histoire-Géographie de Tle de la progression DPFC 2026-2027, rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague T8 du programme `contenus-v3-tous-niveaux`). La progression d'HG est **commune à toutes les séries** : chaque leçon est un seul cours, **sans `series_name`**, rangé dans `tle/histoire-geographie/` (comme `1ere/` et `2nde/`), visible des classes de Tle A1, A2, C et D. Elles remplacent les 3 fichiers v1 du même intitulé, qui étaient copiés dans `tle-a1/`, `tle-a2/`, `tle-c/` et `tle-d/`. Chaque notion porte son « Je m'entraîne » (`practice`). Figures : sortes de l'ADR-0117, aucune sorte nouvelle (la France est dessinée sur le fond `world`).

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Entraînement | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU | 5 | 9 | 54 | 93 % | 16 | 3 | `diagram`, `map world`, `timeline` |
| 2 | `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire | 5 | 9 | 55 | 91 % | 18 | 4 | `diagram`, `map cote_d_ivoire`, `stat_chart line` |
| 3 | `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 | 5 | 9 | 56 | 93 % | 15 | 3 | `diagram`, `map world`, `timeline` |
| 4 | `histoire-geographie/geographie-les-secteurs-d-activites-economiques-de-la-cote-d-ivoire.json` | Géographie — Les secteurs d'activités économiques de la Côte d'Ivoire | 5 | 9 | 55 | 89 % | 15 | 4 | `diagram`, `map cote_d_ivoire`, `stat_chart pie` |
| 5 | `histoire-geographie/histoire-de-la-fin-de-la-guerre-froide-vers-un-monde-multipolaire.json` | Histoire — De la fin de la guerre froide vers un monde multipolaire | 5 | 9 | 52 | 90 % | 15 | 3 | `diagram`, `map world`, `timeline` |
| 6 | `histoire-geographie/geographie-les-problemes-de-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les problèmes de développement économique de la Côte d'Ivoire | 5 | 9 | 55 | 91 % | 25 | 4 | `diagram`, `map cote_d_ivoire`, `stat_chart line` |
| 7 | `histoire-geographie/histoire-la-montee-des-nationalismes-en-afrique.json` | Histoire — La montée des nationalismes en Afrique | 5 | 9 | 54 | 94 % | 15 | 3 | `diagram`, `map africa`, `timeline` |
| 8 | `histoire-geographie/histoire-l-accession-de-la-cote-d-ivoire-a-l-independance.json` | Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 5 | 9 | 56 | 93 % | 15 | 4 | `diagram`, `map cote_d_ivoire`, `timeline` |
| 9 | `histoire-geographie/geographie-les-fondements-de-l-economie-de-la-france.json` | Géographie — Les fondements de l'économie de la France | 5 | 9 | 58 | 91 % | 15 | 6 | `diagram`, `map world`, `stat_chart bars`, `timeline` |
| 10 | `histoire-geographie/histoire-l-accession-de-l-algerie-a-l-independance.json` | Histoire — L'accession de l'Algérie à l'indépendance | 5 | 9 | 54 | 91 % | 15 | 5 | `diagram`, `map africa`, `timeline` |

Au total : 50 notions, 90 exercices, 549 questions notées, 164 questions d'entraînement et 39 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement et `test/integration/contenus/tle_histoire_geographie_je_m_entraine_test.rb`. Chacun a été relu par un second rédacteur qui n'en était pas l'auteur ; défauts corrigés, dont : l'UEMOA créée à huit États (sept en 1994, huit depuis 1997), la CEI créée « le mois précédent » la démission de Gorbatchev (même mois), le GPRA situé au Caire en 1959 (Tunis), le charbon lorrain dit « national », des parts du PIB attribuées à une source non vérifiée (présentées désormais comme ordres de grandeur d'illustration). Points à faire valider par un enseignant : journal du chantier et du programme. Les leçons restent en brouillon jusqu'à cette relecture.
### Tle A1 et A2, mathématiques au format 3 (chantier `contenus-tle-mathematiques-a`)

Toutes les leçons de Mathématiques de la progression DPFC 2026-2027 de Tle A1 (8) et de Tle A2 (7), rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague T2 du programme `contenus-v3-tous-niveaux`), au niveau d'une série littéraire : calculs simples, contextes concrets (atelier de couture, kermesse, plantation, mobile money, marché, tontine, gbaka, tournoi de football). 9 leçons distinctes, 15 fichiers : les 6 leçons communes aux deux séries ont un fichier par série, identiques hors série et rang (la version A2 de l'exponentielle remplace la question de primitive par une dérivée, celle du logarithme définit ln sans primitive). Les fichiers remplacent les 6 fichiers v1 du même nom (Fonctions, Probabilité et variable aléatoire, Primitives en A1 ; Fonctions, Probabilité, Logarithme en A2). Chaque notion a sa fiche en 4 blocs, un exercice et « Je m'entraîne » ; chaque leçon a 4 problèmes (2 de fixation, 2 d'évaluation dont un au niveau du baccalauréat A). Aucune sorte de figure nouvelle.

#### Tle A1

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Étude de fonctions polynômes et de fonctions rationnelles | 5 | 9 | 56 | 94 % | 2 | `coordinate_plane` |
| 2 | `mathematiques/probabilite-et-variable-aleatoire.json` | Probabilité et variable aléatoire | 4 | 8 | 59 | 96 % | 2 | `diagram`, `stat_chart` |
| 3 | `mathematiques/primitives-et-calcul-integral.json` | Primitives et calcul intégral | 5 | 9 | 60 | 95 % | 1 | `coordinate_plane` |
| 4 | `mathematiques/fonction-logarithme-neperien.json` | Fonction logarithme népérien | 4 | 8 | 52 | 96 % | 1 | `stat_chart` |
| 5 | `mathematiques/fonction-exponentielle-neperienne.json` | Fonction exponentielle népérienne | 5 | 9 | 59 | 96 % | 0 | — |
| 6 | `mathematiques/statistique-a-deux-variables.json` | Statistique à deux variables | 4 | 8 | 52 | 98 % | 10 | `coordinate_plane` |
| 7 | `mathematiques/suites-numeriques.json` | Suites numériques | 5 | 9 | 51 | 96 % | 2 | `coordinate_plane` |
| 8 | `mathematiques/systemes-d-equations-lineaires-dans.json` | Systèmes d'équations linéaires dans ℝ × ℝ | 5 | 9 | 58 | 96 % | 1 | `coordinate_plane` |

Au total : 37 notions, 69 exercices, 447 questions notées et 19 figures.

#### Tle A2

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Étude de fonctions polynômes et de fonctions rationnelles | 5 | 9 | 56 | 94 % | 2 | `coordinate_plane` |
| 2 | `mathematiques/probabilite.json` | Probabilité | 5 | 9 | 58 | 96 % | 1 | `diagram` |
| 3 | `mathematiques/fonction-logarithme-neperien.json` | Fonction logarithme népérien | 4 | 8 | 52 | 96 % | 1 | `stat_chart` |
| 4 | `mathematiques/fonction-exponentielle-neperienne.json` | Fonction exponentielle népérienne | 5 | 9 | 59 | 96 % | 0 | — |
| 5 | `mathematiques/statistique-a-deux-variables.json` | Statistique à deux variables | 4 | 8 | 52 | 98 % | 10 | `coordinate_plane` |
| 6 | `mathematiques/suites-numeriques.json` | Suites numériques | 5 | 9 | 51 | 96 % | 2 | `coordinate_plane` |
| 7 | `mathematiques/systemes-d-equations-lineaires-dans.json` | Systèmes d'équations linéaires dans ℝ × ℝ | 5 | 9 | 58 | 96 % | 1 | `coordinate_plane` |

Au total : 33 notions, 61 exercices, 386 questions notées et 17 figures.

Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et « Je m'entraîne » respecte les règles de `Entities::Catalog::NotionPractice`. Chaque leçon a été relue par un second rédacteur (calculs refaits), et les défauts trouvés ont été corrigés. Les leçons restent en brouillon.

À faire valider par un enseignant de mathématiques avant publication : le rattachement de chaque notion au programme de la série A, le niveau des problèmes de type bac et leurs barèmes. La liste par leçon est dans le journal du chantier [`contenus-tle-mathematiques-a`](../chantiers/contenus-tle-mathematiques-a/journal.md).
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

> **Philosophie** : les fichiers `philosophie/` de ce dossier sont désormais au format 3 (chantier `contenus-tle-philosophie`, section « Tle, Philosophie au format 3 » plus bas).

Les 3 premières leçons de chaque matière des séries A1, A2 et C de Terminale (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A1 et A2 n'ont pas de Physique-Chimie dans la progression.

Les 6 leçons de mathématiques de A1 et A2 de ces tableaux (format v1) sont remplacées par leur version au format 3 : voir « Tle A1 et A2, mathématiques au format 3 ».

#### Tle A1

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/etude-de-fonctions-polynomes-et-de-fonctions-rationnelles.json` | Étude de fonctions polynômes et de fonctions rationnelles (Mathématiques) | 1 | 4 | 12 | 69 |
| `mathematiques/probabilite-et-variable-aleatoire.json` | Probabilité et variable aléatoire (Mathématiques) | 2 | 4 | 12 | 72 |
| `mathematiques/primitives-et-calcul-integral.json` | Primitives et calcul intégral (Mathématiques) | 3 | 4 | 12 | 72 |
| `svt/les-reactions-emotionnelles-chez-l-homme.json` | Les réactions émotionnelles chez l'Homme (SVT) | 1 | 4 | 12 | 60 |
| `svt/l-activite-cerebrale-chez-l-homme.json` | L'activité cérébrale chez l'Homme (SVT) | 2 | 5 | 15 | 84 |
| `svt/l-origine-de-la-vie.json` | L'origine de la vie (SVT) | 3 | 4 | 12 | 72 |
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
| `svt/les-cycles-sexuels-chez-la-femme.json` | Les cycles sexuels chez la femme (SVT) | 1 | 4 | 12 | 72 |
| `svt/la-transmission-d-un-caractere-hereditaire-chez-l-homme.json` | La transmission d'un caractère héréditaire chez l'Homme (SVT) | 2 | 4 | 12 | 71 |
| `svt/la-production-d-energie-par-la-cellule.json` | La production d'énergie par la cellule (SVT) | 3 | 4 | 12 | 68 |
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
- **Physique-Chimie C** : leçons réécrites au format 3, voir « Tle C et D, Physique-Chimie au format 3 ».

### Tle C, SVT au format 3 (chantier `contenus-tle-svt-cd`)

Les 10 premières leçons de SVT de Tle C (progression DPFC 2026-2027), rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 de `tle-c/svt/` (lignes SVT du tableau Tle C ci-dessus). Chaque notion a sa fiche en 4 blocs, un exercice et un bloc « Je m'entraîne » ; chaque leçon a 4 problèmes de type BAC. Les leçons 2, 5 et 6 sont communes aux séries C et D : écrites ici, déclinées dans `tle-d/svt/`.

| # | Fichier | Cours | Notions | Exercices | Questions | Entraînement | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `svt/les-cycles-sexuels-chez-la-femme.json` | Les cycles sexuels chez la femme | 4 | 8 | 52 | 16 | 96 % | 5 | `plate female_reproductive_system`, `stat_chart line`, `diagram` |
| 2 | `svt/la-transmission-d-un-caractere-hereditaire-chez-l-homme.json` | La transmission d'un caractère héréditaire chez l'Homme | 3 | 7 | 43 | 12 | 95 % | 2 | `diagram`, `stat_chart bars` |
| 3 | `svt/la-production-d-energie-par-la-cellule.json` | La production d'énergie par la cellule | 4 | 8 | 57 | 16 | 95 % | 5 | `stat_chart line`, `diagram` |
| 4 | `svt/l-utilisation-de-l-energie-par-la-cellule-musculaire.json` | L'utilisation de l'énergie par la cellule musculaire | 4 | 8 | 52 | 16 | 92 % | 6 | `diagram`, `stat_chart line` |
| 5 | `svt/le-systeme-de-defense-de-l-organisme.json` | Le système de défense de l'organisme | 5 | 9 | 61 | 20 | 97 % | 6 | `diagram`, `stat_chart line`, `plate blood_smear` |
| 6 | `svt/l-infection-de-l-organisme-par-le-vih.json` | L'infection de l'organisme par le VIH | 4 | 8 | 49 | 16 | 96 % | 6 | `plate hiv_virus`, `diagram`, `stat_chart line` |
| 7 | `svt/la-communication-nerveuse.json` | La communication nerveuse | 5 | 9 | 56 | 20 | 96 % | 4 | `stat_chart line`, `diagram` |
| 8 | `svt/les-drogues-et-le-systeme-nerveux.json` | Les drogues et le système nerveux | 4 | 8 | 44 | 16 | 91 % | 6 | `diagram`, `stat_chart line` |
| 9 | `svt/la-mise-en-place-des-gisements-petroliferes-en-cote-d-ivoire.json` | La mise en place des gisements pétrolifères en Côte d'Ivoire | 4 | 8 | 51 | 15 | 92 % | 4 | `map cote_d_ivoire`, `diagram`, `stat_chart line`, `stat_chart bars` |
| 10 | `svt/l-exploitation-des-gisements-petroliferes.json` | L'exploitation des gisements pétrolifères | 4 | 8 | 53 | 16 | 94 % | 6 | `diagram`, `stat_chart bars`, `stat_chart line`, `map cote_d_ivoire` |

Au total : 41 notions, 81 exercices, 518 questions notées, 163 questions d'entraînement et 50 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et a été relu par un agent distinct de son auteur.

Schémas qu'aucune sorte ne dessine (décrits en texte ou en `diagram`) : arbre généalogique, coupe d'ovaire et endomètre, mitochondrie, sarcomère et fibre musculaire, myogramme, anticorps et phagocytose, cycle du VIH dans la cellule, neurone, synapse et plaque motrice, circuit de la récompense, coupe géologique et piège pétrolier, plateforme et forage rotatif, coupe sismique. Les courbes de potentiel sont décalées de +100 mV (`stat_chart` refuse les valeurs négatives) et chaque courbe ne porte qu'une série.

À faire valider par un enseignant de SVT avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague T4).

### Tle D, SVT au format 3 (chantier `contenus-tle-svt-cd`)

Les 10 premières leçons de SVT de Tle D, rédigées le 2026-10-31 au même format que la Tle C ci-dessus. Elles remplacent les 3 fichiers v1 de `tle-d/svt/` (lignes SVT du tableau Tle D). Les leçons 4, 7 et 8 sont les leçons 2, 5 et 6 de Tle C : même contenu, seuls `series_name` et `subtitle` changent. Les 7 autres sont propres à la série D.

| # | Fichier | Cours | Notions | Exercices | Questions | Entraînement | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères | 3 | 7 | 40 | 12 | 92 % | 6 | `plate female_reproductive_system`, `diagram`, `stat_chart line` |
| 2 | `svt/le-fonctionnement-des-organes-sexuels-chez-l-homme.json` | Le fonctionnement des organes sexuels chez l'Homme | 3 | 7 | 48 | 12 | 96 % | 5 | `diagram`, `plate female_reproductive_system`, `stat_chart line` |
| 3 | `svt/la-reproduction-chez-les-spermaphytes.json` | La reproduction chez les spermaphytes | 4 | 8 | 49 | 16 | 96 % | 5 | `diagram`, `stat_chart line` |
| 4 | `svt/la-transmission-d-un-caractere-hereditaire-chez-l-homme.json` | La transmission d'un caractère héréditaire chez l'Homme | 3 | 7 | 43 | 12 | 95 % | 2 | `diagram`, `stat_chart bars` |
| 5 | `svt/la-transmission-de-deux-caracteres-hereditaires-chez-les-etres-vivants.json` | La transmission de deux caractères héréditaires chez les êtres vivants | 4 | 8 | 51 | 20 | 96 % | 8 | `stat_chart bars`, `diagram` |
| 6 | `svt/le-maintien-de-la-constance-du-milieu-interieur.json` | Le maintien de la constance du milieu intérieur | 4 | 8 | 49 | 20 | 94 % | 5 | `stat_chart line`, `diagram`, `plate digestive_system` |
| 7 | `svt/le-systeme-de-defense-de-l-organisme.json` | Le système de défense de l'organisme | 5 | 9 | 61 | 20 | 97 % | 6 | `diagram`, `stat_chart line`, `plate blood_smear` |
| 8 | `svt/l-infection-de-l-organisme-par-le-vih.json` | L'infection de l'organisme par le VIH | 4 | 8 | 49 | 16 | 96 % | 6 | `plate hiv_virus`, `diagram`, `stat_chart line` |
| 9 | `svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 5 | 9 | 53 | 19 | 96 % | 6 | `diagram`, `stat_chart line`, `stat_chart bars` |
| 10 | `svt/le-fonctionnement-du-tissu-nerveux.json` | Le fonctionnement du tissu nerveux | 5 | 9 | 54 | 20 | 94 % | 5 | `diagram`, `stat_chart line` |

Au total : 40 notions, 80 exercices, 497 questions notées, 167 questions d'entraînement et 54 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement ; chaque leçon propre à la série D a été relue par un agent distinct de son auteur.

Schémas qu'aucune sorte ne dessine, en plus de ceux de la Tle C : spermatozoïde, ovocyte et stades de segmentation, testicule et tube séminifère, fleur, ovule et grain de pollen, paire de chromosomes et crossing-over, échiquier, îlot de Langerhans, cortex et bulbe. Points à faire valider : [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague T4).

### Tle A1 et A2, SVT au format 3 (chantier `contenus-tle-svt-a`)

Les 7 leçons de SVT de Tle A1 et A2 (progression DPFC 2026-2027, identique dans les deux séries), rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), pour des élèves de série littéraire : documents à analyser plutôt que calculs. Chaque leçon est écrite dans `tle-a1/svt/` et copiée dans `tle-a2/svt/`, où seule `series_name` change. Elles remplacent les 3 fichiers v1 de chacun de ces dossiers (lignes SVT des tableaux Tle A1 et Tle A2 ci-dessus). Chaque notion a sa fiche en 4 blocs, un exercice et un bloc « Je m'entraîne » ; chaque leçon a 4 problèmes de type BAC.

| # | Fichier | Cours | Notions | Exercices | Questions | Entraînement | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `svt/les-reactions-emotionnelles-chez-l-homme.json` | Les réactions émotionnelles chez l'Homme | 4 | 8 | 48 | 16 | 96 % | 3 | `diagram`, `stat_chart bars`, `stat_chart line` |
| 2 | `svt/l-activite-cerebrale-chez-l-homme.json` | L'activité cérébrale chez l'Homme | 5 | 9 | 52 | 18 | 96 % | 9 | `diagram`, `stat_chart bars` |
| 3 | `svt/l-origine-de-la-vie.json` | L'origine de la vie | 4 | 8 | 51 | 15 | 94 % | 4 | `diagram`, `stat_chart bars` |
| 4 | `svt/l-evolution-de-la-lignee-humaine.json` | L'évolution de la lignée humaine | 5 | 9 | 52 | 11 | 92 % | 3 | `diagram`, `map africa`, `stat_chart bars` |
| 5 | `svt/l-heredite-du-sexe-et-du-groupe-sanguin-chez-l-homme.json` | L'hérédité du sexe et du groupe sanguin chez l'Homme | 4 | 8 | 52 | 16 | 96 % | 4 | `diagram`, `stat_chart bars` |
| 6 | `svt/les-previsions-genetiques.json` | Les prévisions génétiques | 4 | 8 | 48 | 16 | 94 % | 3 | `diagram` |
| 7 | `svt/l-utilisation-des-nutriments-la-biosynthese-des-proteines.json` | L'utilisation des nutriments : la biosynthèse des protéines | 5 | 9 | 53 | 15 | 96 % | 4 | `diagram`, `stat_chart bars` |

Au total, par série : 31 notions, 59 exercices, 356 questions notées, 107 questions d'entraînement et 30 figures. Chacun des 14 fichiers passe `script/contenus/valider.rb` sans erreur ni avertissement, ainsi que le contrôle de l'entraînement (règles du test de 3e), et chaque leçon a été relue par un agent distinct de son auteur.

Schémas qu'aucune sorte ne dessine (décrits en texte ou en `diagram`) : cerveau et aires corticales, tracé d'électroencéphalogramme et hypnogramme, système nerveux et glandes surrénales, frise en millions ou milliards d'années (`timeline` s'arrête à −3000), crânes et squelettes, caryotype, échiquier de croisement, arbre généalogique, cellule et ribosome, double hélice d'ADN, hématies falciformes.

À faire valider par un enseignant de SVT avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague T5).

### Tle, Philosophie au format 3 (chantier `contenus-tle-philosophie`)

Les 10 premières leçons de Philosophie de la progression DPFC 2026-2027 pour les séries A1, A2, C et D (série E ignorée, décision D3 du programme `contenus-v3-tous-niveaux`), rédigées le 2026-10-31 au format `lnclass.course-tree` v3. Chaque leçon est écrite une fois puis déclinée en un fichier par série : seuls `series_name` et le rang du sous-titre changent. « L'histoire et l'humanité » n'existe qu'en A1 et A2 ; en C et D, les leçons suivantes reculent d'un rang. **38 fichiers** (A1 10, A2 10, C 9, D 9) dans `tle-a1/`, `tle-a2/`, `tle-c/`, `tle-d/`, qui remplacent les 12 fichiers v1 du même intitulé. Aucune figure. Les questions rédigées ont un corrigé modèle, un barème et des critères ; elles notent l'argumentation, jamais l'opinion. Les thèses d'auteurs sont paraphrasées et référencées ; les textes supports sont écrits pour Lnclass.

| Rang A1/A2 | Rang C/D | Fichier | Cours | Notions | Exercices | Questions | Auto |
|---:|---:|---|---|---:|---:|---:|---:|
| 1 | 1 | `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique | 4 | 8 | 49 | 78 % |
| 2 | 2 | `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique | 4 | 8 | 50 | 80 % |
| 3 | 3 | `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme | 4 | 8 | 42 | 79 % |
| 4 | 4 | `philosophie/la-vie-en-societe.json` | La vie en société | 3 | 7 | 42 | 79 % |
| 5 | 5 | `philosophie/dieu-et-la-religion.json` | Dieu et la religion | 4 | 8 | 53 | 75 % |
| 6 | — | `philosophie/l-histoire-et-l-humanite.json` | L'histoire et l'humanité | 4 | 8 | 50 | 80 % |
| 7 | 6 | `philosophie/la-valeur-de-la-philosophie.json` | La valeur de la philosophie | 4 | 8 | 50 | 80 % |
| 8 | 7 | `philosophie/progres-et-bonheur.json` | Progrès et bonheur | 4 | 8 | 48 | 79 % |
| 9 | 8 | `philosophie/langage-et-verite.json` | Langage et vérité | 4 | 8 | 48 | 77 % |
| 10 | 9 | `philosophie/la-connaissance-scientifique.json` | La connaissance scientifique | 4 | 8 | 48 | 79 % |

Au total : 39 notions, 79 exercices et 480 questions par série complète (A1, A2). Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. Chaque leçon a été relue par un relecteur indépendant (autre modèle que l'auteur) : 0 défaut bloquant, 5 à 7 défauts à corriger par leçon (attributions, barèmes, réponses justes refusées, corrections qui désignaient une proposition par son rang), tous corrigés.

Les leçons restent en brouillon. À faire valider par un enseignant de philosophie :

- **L1 Dissertation** : Terminologie des plans (dialectique thèse/antithèse/dépassement ou synthèse ; analytique/progressif) et lien forme du sujet → plan présenté comme tendance ; structure de l'introduction (amorce, sujet, problème/problématique, annonce du plan) ; paragraphe idée-argument-exemple-bilan avec référence d'auteur facultative.
- **L2 Commentaire** : Explication en 5 gestes (situer, définir, reformuler/justifier, illustrer, relier) ; place de l'évaluation de l'intérêt (dernier moment du développement) ; 4 temps de l'introduction ; connecteurs (certes… mais, sans doute… mais, ainsi) ; textes supports tous écrits pour Lnclass ; Usage de « problème » (la difficulté) et « problématique » (la question) dans le commentaire, aligné sur L1.
- **L3 Connaissance de l'homme** : Périmètre de la notion « sciences humaines » (Durkheim, 1895, « considérer les faits sociaux comme des choses ») face aux leçons 4 et 10 ; dates de 1re publication Freud (« L'Interprétation des rêves » datée 1900, « Psychopathologie de la vie quotidienne » 1901, « Une difficulté de la psychanalyse » 1917) ; inconscient présenté comme hypothèse.
- **L4 Vie en société** : Aristote, « Politique » (IVe s. av. J.-C.), animal politique et langage ; Hobbes, « Léviathan », 1651 (guerre de chacun contre chacun, paraphrase) ; Rousseau, « Du contrat social », 1762, citation « L'homme est né libre, et partout il est dans les fers » ; Kant, « insociable sociabilité » (1784) ; Montesquieu, « De l'esprit des lois », 1748 ; travail et échanges non traités ; Kant, « insociable sociabilité » tiré d'un texte sur l'histoire (proximité avec L6) ; état de nature de Hobbes présenté comme hypothèse ; justice traitée sans auteur.
- **L5 Dieu et la religion** : Durkheim, « Les formes élémentaires de la vie religieuse », 1912 ; étymologie de « religion » (relier / recueillir) présentée comme discutée ; Descartes, 3e Méditation (idée d'infini) ; pari de Pascal (« Pensées », 1670) comme raison d'agir ; Kant, 1781 (ni prouver ni réfuter) ; Feuerbach 1841 ; Freud, « L'Avenir d'une illusion », 1927 (sens d'illusion) ; Marx 1844, « l'opium du peuple » ; Locke 1689 et Voltaire 1763 sur la tolérance ; laïcité de l'État ivoirien (Constitution, aucun article cité) ; neutralité d'ensemble ; Kant, « faire place à la croyance » : préface de la 2e édition (1787) ; titre de Marx 1844 ; article de la Constitution ivoirienne sur la laïcité non cité.
- **L6 Histoire et humanité** : Rousseau, perfectibilité (1755) ; Hegel, « Leçons sur la philosophie de l'histoire » (publication posthume, 1837), raison dans l'histoire et « ruse de la raison » ; Marx et Engels 1848 ; Marx, « Le 18 Brumaire de Louis Bonaparte », 1852 ; Pascal, petite cause imprévue ; objection de la contingence sans auteur ; indépendance de la Côte d'Ivoire le 7 août 1960 ; Pascal rangé dans la réponse « hasard » ; conclusion « le sens de l'histoire se construit ».
- **L7 Valeur de la philosophie** : Platon, « Théétète », et Aristote, « Métaphysique » : l'étonnement (paraphrase) ; Descartes, lettre-préface des « Principes de la philosophie », 1647 (arbre, yeux fermés) ; Russell, « Problèmes de philosophie », 1912, chap. XV ; Tempels, « La philosophie bantoue », 1945 (Présence africaine 1949), force vitale ; Hountondji, 1976, ethnophilosophie ; Towa, 1971 ; Kagame, « La philosophie bantu-rwandaise de l'être », 1956 (paraphrase) ; équilibre des positions dans le débat sur la philosophie africaine ; la notion « philosophie, sciences et religion » face à la leçon 10.
- **L8 Progrès et bonheur** : Condorcet, 1795, perfectibilité indéfinie (fill_blank « perfectibilité ») ; Descartes, « maîtres et possesseurs de la nature », 1637, VIe partie ; Rousseau, 1750 ; Épicure, « Lettre à Ménécée », classement des désirs ; Épictète, « Manuel », ce qui dépend de nous ; Kant, 1785, bonheur concept indéterminé ; Formule « ni naturels ni nécessaires » attribuée à la « Lettre à Ménécée » (plutôt Maxime capitale XXIX) ; « Discours sur les sciences et les arts » daté 1750 (diffusé 1751).
- **L9 Langage et vérité** : Descartes, lettre au marquis de Newcastle, 1646 (paraphrase) ; Benveniste, abeilles (article de 1952, recueil « Problèmes de linguistique générale », 1966) ; Saussure, 1916 ; Bergson, « Le Rire », 1900, mots-étiquettes ; Platon, « Gorgias » ; Aristote, vérité-adéquation ; cohérence sans auteur ; définitions de sophisme, mensonge, erreur.
- **L10 Connaissance scientifique** : Bachelard, 1938, obstacle épistémologique et rupture ; Claude Bernard, 1865 ; Popper, 1934, réfutabilité (cygne noir) ; Copernic, 1543 ; Rabelais, « Pantagruel », 1532, « Science sans conscience n'est que ruine de l'âme » ; faits : anophèle femelle, Aedes de jour, Jenner 1796, éradication de la variole 1980 (OMS).
- **Toutes les leçons** : la méthode de l'introduction (amorce, sujet cité, problématique, annonce du plan) et du paragraphe argumenté, alignée sur la leçon 1 ; les barèmes des questions rédigées (1 à 8 points).

### Tle A1, A2, C et D, Français au format 3 (chantier `contenus-tle-francais`)

Les 7 leçons distinctes de Français de Terminale (progression DPFC 2026-2027), rédigées le 2026-10-31 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), niveau baccalauréat. Chaque leçon est écrite dans `tle-a1/francais/` et déclinée dans `tle-a2/`, `tle-c/` et `tle-d/`, où seuls `series_name` et le rang du `subtitle` changent : 26 fichiers (7 en A1 et A2, 6 en C et D, sans « Œuvre poétique »). Elles remplacent les 3 fichiers v1 de chacun de ces dossiers (lignes Français des tableaux Tle ci-dessus). Aucune figure. Chaque notion a sa fiche en 4 blocs, un exercice et un bloc « Je m'entraîne » ; chaque leçon a 4 problèmes, dont un de type BAC. Les textes supports sont écrits pour Lnclass ; les œuvres réelles ne sont citées que par de courtes références paraphrasées, avec auteur, titre et date.

| Fichier | Cours | A1 / A2 | C / D | Notions | Exercices | Questions | Entraînement | Auto |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `francais/oeuvre-narrative.json` | Œuvre narrative | 1 | 1 | 4 | 8 | 49 | 13 | 86 % |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat | 2 | 3 | 4 | 8 | 51 | 17 | 88 % |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire | 3 | 2 | 4 | 8 | 48 | 16 | 81 % |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 4 | 4 | 4 | 8 | 50 | 20 | 84 % |
| `francais/groupement-de-textes-theatraux.json` | Groupement de textes théâtraux | 5 | 5 | 4 | 8 | 48 | 16 | 90 % |
| `francais/oeuvre-poetique.json` | Œuvre poétique | 6 | — | 4 | 8 | 50 | 17 | 92 % |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 7 | 6 | 4 | 8 | 55 | 15 | 84 % |

Au total : 28 notions, 56 exercices, 351 questions notées et 114 questions d'entraînement. Chacun des 26 fichiers passe `script/contenus/valider.rb` sans erreur ni avertissement, ainsi que le contrôle de l'entraînement (règles du test de 3e), et chaque leçon a été relue par un agent distinct de son auteur.

À faire valider par un enseignant de Français avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague T7).

### 1ère C et D, Physique-Chimie au format 3 (chantier `contenus-1ere-physique-chimie-cd`)

Les 10 premières leçons de Physique-Chimie de 1ère C et de 1ère D (progression DPFC 2026-2027), rédigées le 2026-11-01 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), vague P3 du programme `contenus-v3-tous-niveaux`. **12 leçons distinctes (13 intitulés), 20 fichiers** : une leçon commune aux deux séries est écrite une fois puis copiée avec la série et le rang de chaque progression (C1 « Travail et puissance dans le cas d'un mouvement de translation » et D1 « …d'une force constante… » : même contenu, deux intitulés ; « Énergie potentielle » en C et « Énergie potentielle de pesanteur » en D sont deux leçons). Elles remplacent les fichiers v1 du même intitulé de `1ere-c/` et `1ere-d/`. Les leçons communes n'emploient que des acquis communs aux deux ordres de progression (Énergie cinétique : pas de rotation ; Énergie mécanique : pesanteur seulement).

| Série | Rang | Fichier | Cours | Notions | Exercices | Questions | Je m'entraîne | Auto | Figures | Sortes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| C | 1 | `1ere-c/physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance dans le cas d'un mouvement de translation | 5 | 9 | 66 | 15 | 97 % | 3 | `coordinate_plane` |
| C | 2 | `1ere-c/physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 7 | 11 | 74 | 21 | 97 % | 4 | `diagram`, `molecule` |
| C | 3 | `1ere-c/physique-chimie/travail-et-puissance-dans-le-cas-d-un-mouvement-de-rotation-autour-d-un-axe-fixe.json` | Travail et puissance dans le cas d'un mouvement de rotation autour d'un axe fixe | 4 | 8 | 61 | 12 | 97 % | 3 | `coordinate_plane` |
| C | 4 | `1ere-c/physique-chimie/hydrocarbures-satures-les-alcanes.json` | Hydrocarbures saturés : les alcanes | 7 | 11 | 70 | 21 | 97 % | 4 | `molecule` |
| C | 5 | `1ere-c/physique-chimie/energie-cinetique.json` | Énergie cinétique | 4 | 8 | 59 | 12 | 97 % | 2 | `coordinate_plane` |
| C | 6 | `1ere-c/physique-chimie/hydrocarbures-insatures-les-alcenes-et-les-alcynes.json` | Hydrocarbures insaturés : les alcènes et les alcynes | 5 | 9 | 61 | 15 | 97 % | 6 | `diagram`, `molecule` |
| C | 7 | `1ere-c/physique-chimie/le-benzene.json` | Le benzène | 5 | 9 | 65 | 15 | 97 % | 2 | `molecule` |
| C | 8 | `1ere-c/physique-chimie/energie-potentielle.json` | Énergie potentielle | 4 | 8 | 55 | 12 | 98 % | 2 | `coordinate_plane` |
| C | 9 | `1ere-c/physique-chimie/petrole-et-gaz-naturels.json` | Pétrole et gaz naturels | 6 | 10 | 76 | 18 | 97 % | 3 | `diagram`, `molecule`, `stat_chart` |
| C | 10 | `1ere-c/physique-chimie/energie-mecanique.json` | Énergie mécanique | 4 | 8 | 55 | 12 | 96 % | 4 | `coordinate_plane` |
| D | 1 | `1ere-d/physique-chimie/travail-et-puissance-d-une-force-constante-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance d'une force constante dans le cas d'un mouvement de translation | 5 | 9 | 66 | 15 | 97 % | 3 | `coordinate_plane` |
| D | 2 | `1ere-d/physique-chimie/generalites-sur-les-composes-organiques.json` | Généralités sur les composés organiques | 7 | 11 | 74 | 21 | 97 % | 4 | `diagram`, `molecule` |
| D | 3 | `1ere-d/physique-chimie/hydrocarbures-satures-les-alcanes.json` | Hydrocarbures saturés : les alcanes | 7 | 11 | 70 | 21 | 97 % | 4 | `molecule` |
| D | 4 | `1ere-d/physique-chimie/energie-cinetique.json` | Énergie cinétique | 4 | 8 | 59 | 12 | 97 % | 2 | `coordinate_plane` |
| D | 5 | `1ere-d/physique-chimie/hydrocarbures-insatures-les-alcenes-et-les-alcynes.json` | Hydrocarbures insaturés : les alcènes et les alcynes | 5 | 9 | 61 | 15 | 97 % | 6 | `diagram`, `molecule` |
| D | 6 | `1ere-d/physique-chimie/energie-potentielle-de-pesanteur.json` | Énergie potentielle de pesanteur | 4 | 8 | 54 | 12 | 98 % | 2 | `coordinate_plane` |
| D | 7 | `1ere-d/physique-chimie/le-benzene.json` | Le benzène | 5 | 9 | 65 | 15 | 97 % | 2 | `molecule` |
| D | 8 | `1ere-d/physique-chimie/petrole-et-gaz-naturels.json` | Pétrole et gaz naturels | 6 | 10 | 76 | 18 | 97 % | 3 | `diagram`, `molecule`, `stat_chart` |
| D | 9 | `1ere-d/physique-chimie/energie-mecanique.json` | Énergie mécanique | 4 | 8 | 55 | 12 | 96 % | 4 | `coordinate_plane` |
| D | 10 | `1ere-d/physique-chimie/quelques-composes-oxygenes.json` | Quelques composés oxygénés | 5 | 9 | 56 | 15 | 96 % | 6 | `diagram`, `molecule` |

Leçons distinctes : 60 notions, 752 questions notées, 180 questions « Je m'entraîne », 41 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et le contrôle de « Je m'entraîne » de session (4 blocs, 1 à 6 questions par notion, case multiple et indice, `tolerance` numérique). Chaque leçon a été relue par un sous-agent Opus distinct de son auteur (Sonnet), qui a refait chaque calcul. Aucune sorte de figure nouvelle, aucun code.

**Brouillon.** Aucun enseignant ne les a relues : les points à faire valider sont dans le journal du programme [`contenus-v3-tous-niveaux`](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant). Les lignes de Physique-Chimie du tableau « 1ère C » et « 1ère D » ci-dessous (v1, rangs 1 à 3) sont remplacées par ce tableau. Si les cours v1 sont déjà dans une base, les renommer et les archiver avant d'importer.

### 1ère A1 et A2, Physique-Chimie au format 3 (chantier `contenus-1ere-a-physique-chimie`)

Les 10 premières leçons de Physique-Chimie de 1ère A (progression DPFC 2026-2027), rédigées le 2026-11-02 au format `lnclass.course-tree` v3, vague P4 du programme `contenus-v3-tous-niveaux`. Le référentiel n'a pas de série « A » en 1ère : chaque leçon est écrite une fois puis déclinée en **20 fichiers** (`1ere-a1/physique-chimie/` et `1ere-a2/physique-chimie/`, identiques à `series_name` près). Les leçons 9 et 10 partent des versions 1ère C/D, allégées. Elles remplacent les 3 fichiers v1 (rangs 1 à 3) du tableau « 1ère A1 et A2 » plus bas.

| Rang | Fichier (A1 et A2) | Cours | Notions | Exercices | Questions | Je m'entraîne | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `physique-chimie/etude-d-un-dipole-passif-cas-d-un-resistor.json` | Étude d'un dipôle passif : cas d'un résistor | 4 | 8 | 60 | 12 | 3 | `coordinate_plane` |
| 2 | `physique-chimie/les-alcanes.json` | Les alcanes | 5 | 9 | 56 | 15 | 4 | `molecule` |
| 3 | `physique-chimie/les-alcenes-cas-de-l-ethylene.json` | Les alcènes : cas de l'éthylène | 5 | 9 | 60 | 15 | 6 | `diagram`, `molecule` |
| 4 | `physique-chimie/etude-d-un-dipole-actif-cas-d-une-pile-loi-de-pouillet.json` | Étude d'un dipôle actif : cas d'une pile. Loi de Pouillet | 4 | 8 | 58 | 12 | 4 | `coordinate_plane`, `diagram` |
| 5 | `physique-chimie/petroles-et-gaz-naturels.json` | Pétroles et gaz naturels | 4 | 8 | 54 | 12 | 3 | `diagram`, `molecule` |
| 6 | `physique-chimie/puissance-et-energie-electriques.json` | Puissance et énergie électriques | 4 | 8 | 61 | 12 | 2 | `diagram`, `stat_chart` |
| 7 | `physique-chimie/principe-de-la-production-d-une-tension-alternative.json` | Principe de la production d'une tension alternative | 5 | 9 | 56 | 15 | 3 | `coordinate_plane`, `diagram` |
| 8 | `physique-chimie/reactions-d-oxydo-reduction-en-solution-aqueuse.json` | Réactions d'oxydo-réduction en solution aqueuse | 4 | 8 | 48 | 12 | 2 | `diagram` |
| 9 | `physique-chimie/travail-et-puissance-d-une-force-constante-dans-le-cas-d-un-mouvement-de-translation.json` | Travail et puissance d'une force constante dans le cas d'un mouvement de translation | 4 | 8 | 58 | 12 | 3 | `coordinate_plane` |
| 10 | `physique-chimie/energie-cinetique.json` | Énergie cinétique | 4 | 8 | 57 | 12 | 2 | `coordinate_plane` |

Au total (par série) : 43 notions, 568 questions notées, 129 questions « Je m'entraîne », 32 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement (Ruby 3.4). Chaque leçon a été relue par un sous-agent Opus distinct de son auteur (calculs refaits, chiffres et données vérifiés).

**Brouillon.** Aucun enseignant ne les a relues : les points à faire valider sont dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant). Aucune sorte ne dessine un circuit électrique ni une sinusoïde : circuits décrits dans les énoncés, sinusoïdes approchées par segments.

### 1ère A1, A2, C et D, Philosophie au format 3 (chantier `contenus-1ere-philosophie`)

Les 8 leçons de Philosophie de la progression DPFC 2026-2027 de 1ère (identique en A1, A2, C et D), rédigées le 2026-11-02 au format `lnclass.course-tree` v3, vague P7 du programme `contenus-v3-tous-niveaux`. Chaque leçon est écrite une fois puis déclinée en un fichier par série : seul `series_name` change. **32 fichiers** dans `1ere-a1/`, `1ere-a2/`, `1ere-c/`, `1ere-d/`, qui remplacent les 12 fichiers v1 du même intitulé (leçons 1 à 3 : voir les tableaux « 1ère » plus bas, sans leurs lignes de Philosophie). Aucune figure. Relecture indépendante par un sous-agent Opus (attributions, dates, citations), puis corrections. Les leçons restent en brouillon.

| Rang | Fichier (A1, A2, C, D) | Cours | Notions | Exercices | Questions | Corrigées auto. |
|---:|---|---|---:|---:|---:|---:|
| 1 | `philosophie/la-methode-de-lecture-de-texte.json` | La méthode de lecture de texte | 5 | 9 | 56 | 89 % |
| 2 | `philosophie/la-redaction-de-l-introduction.json` | La rédaction de l'introduction | 5 | 9 | 53 | 87 % |
| 3 | `philosophie/la-redaction-de-la-conclusion.json` | La rédaction de la conclusion | 4 | 8 | 50 | 78 % |
| 4 | `philosophie/l-essai-de-problematisation.json` | L'essai de problématisation | 5 | 9 | 55 | 80 % |
| 5 | `philosophie/la-periode-antique.json` | La période antique | 5 | 9 | 55 | 78 % |
| 6 | `philosophie/le-moyen-age-et-la-renaissance.json` | Le Moyen-Age et la renaissance | 5 | 9 | 56 | 89 % |
| 7 | `philosophie/la-periode-moderne.json` | La période moderne | 5 | 9 | 54 | 89 % |
| 8 | `philosophie/la-periode-contemporaine.json` | La période contemporaine | 5 | 9 | 57 | 88 % |

À faire valider par un enseignant de philosophie : voir le journal du chantier (`docs/chantiers/contenus-1ere-philosophie/journal.md`).

### 1ère — `lecons-traitees/1ere-a1/`, `1ere-a2/`, `1ere-c/`, `1ere-d/`, `1ere/`

Les 3 premières leçons de chaque matière de Première (progression DPFC 2026-2027, rangs 1 à 3), rédigées le 2026-10-10 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Les séries A, C et D ont des progressions différentes, et Histoire-Géographie est commune à toutes les séries. Dans le référentiel de Develop (`db/seeds/catalog.rb`), la 1ère a les séries A1, A2, C et D : les leçons communes aux deux séries A sont écrites une fois, puis déclinées en A1 et A2.

#### 1ère A1 et A2 (12 chacune, hors Français)

Même texte dans `1ere-a1/` et `1ere-a2/`, à la série près : écrites pour une série « A » que le référentiel n'ouvre pas en 1ère, elles ont été séparées le 2026-10-23.

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `mathematiques/equations-et-inequations.json` | Équations et inéquations | 1 | 4 | 12 | 72 |
| `mathematiques/denombrement.json` | Dénombrement | 2 | 4 | 12 | 72 |
| `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 3 | 4 | 12 | 72 |
| `physique-chimie/etude-d-un-dipole-passif-cas-d-un-resistor.json` | Étude d'un dipôle passif : cas d'un résistor | 1 | 4 | 12 | 71 |
| `physique-chimie/les-alcanes.json` | Les alcanes | 2 | 4 | 12 | 72 |
| `physique-chimie/les-alcenes-cas-de-l-ethylene.json` | Les alcènes : cas de l'éthylène | 3 | 4 | 12 | 72 |
| `svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 1 | 5 | 9 | 45 |
| `svt/les-effets-des-drogues-sur-le-comportement.json` | Les effets des drogues sur le comportement | 2 | 4 | 8 | 48 |
| `svt/les-anomalies-chromosomiques.json` | Les anomalies chromosomiques | 3 | 3 | 7 | 45 |

#### 1ère C (12, hors Français)

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

#### 1ère D (12, hors Français)

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

#### 1ère (commune à toutes les séries) (3)

| Fichier | Cours | Rang | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|---:|
| `histoire-geographie/histoire-l-essor-du-capitalisme-et-ses-consequences.json` | Histoire — L'essor du capitalisme et ses conséquences | 1 | 3 | 9 | 54 |
| `histoire-geographie/geographie-dynamisme-demographique-et-qualite-de-la-vie-en-cote-d-ivoire.json` | Géographie — Dynamisme démographique et qualité de la vie en Côte d'Ivoire | 2 | 3 | 9 | 51 |
| `histoire-geographie/histoire-les-revolutions-industrielles.json` | Histoire — Les révolutions industrielles | 3 | 3 | 9 | 54 |

**36 cours, 133 fiches, 399 exercices, 2306 questions** (hors Français, remplacé ci-dessous ; 12 fichiers v1 de Français retirés). Tous passent `script/contenus/valider.rb`, et `ctrlchars.rb` ne signale aucun caractère de contrôle. Les 63 cours de la version précédente (1ère A1 et A2 séparées) avaient été importés en deux envois sur une base jetable, sans refus ; **le lot actuel n'a pas été réimporté**.

#### 1ère — Français, 11 leçons (A, C, D)

Les 11 leçons distinctes de Français de 1ère de la progression DPFC 2026-2027, rédigées le 2026-11-01 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague P8 du programme `contenus-v3-tous-niveaux`, chantier [`contenus-1ere-francais`](../chantiers/contenus-1ere-francais/memo.md)). Écrites une fois (la dernière, propre à C et D, en C), puis déclinées en A1, A2, C et D : seuls `series_name` et le rang du `subtitle` changent (A1 et A2 ont le même texte). « Groupement de textes romanesques » n’existe qu’en A1 et A2 ; « Les valeurs des temps verbaux » qu’en C et D. Elles remplacent les 12 fichiers v1 de `1ere-a1/`, `1ere-a2/`, `1ere-c/` et `1ere-d/` (40 fichiers en tout : 10 en A1, 10 en A2, 10 en C, 10 en D). Chaque notion porte son « Je m’entraîne ». Aucune figure ; textes écrits pour Lnclass ; relecture indépendante par Opus, un tour.


##### 1ère A1 et A2 (mêmes fichiers dans `1ere-a1/` et `1ere-a2/`, `series_name` « A1 » ou « A2 »)

| Fichier | Cours | Rang | Fiches | Exercices | Questions | Entraînement |
|---|---|---:|---:|---:|---:|---:|
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 8 | 56 | 16 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 2 | 4 | 8 | 50 | 12 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 3 | 4 | 8 | 57 | 14 |
| `francais/le-rythme-dans-le-texte.json` | Le rythme dans le texte | 4 | 4 | 8 | 50 | 12 |
| `francais/la-focalisation.json` | La focalisation | 5 | 4 | 8 | 49 | 16 |
| `francais/groupement-de-textes-romanesques.json` | Groupement de textes romanesques | 6 | 4 | 8 | 55 | 16 |
| `francais/les-tonalites-litteraires.json` | Les tonalités littéraires | 7 | 5 | 9 | 54 | 15 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 8 | 4 | 8 | 60 | 12 |
| `francais/l-argumentation.json` | L'argumentation | 9 | 4 | 8 | 52 | 12 |
| `francais/l-implicite.json` | L'implicite | 10 | 4 | 8 | 49 | 12 |

##### 1ère C

| Fichier | Cours | Rang | Fiches | Exercices | Questions | Entraînement |
|---|---|---:|---:|---:|---:|---:|
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 8 | 56 | 16 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 2 | 4 | 8 | 57 | 14 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 3 | 4 | 8 | 50 | 12 |
| `francais/le-rythme-dans-le-texte.json` | Le rythme dans le texte | 4 | 4 | 8 | 50 | 12 |
| `francais/les-tonalites-litteraires.json` | Les tonalités littéraires | 5 | 5 | 9 | 54 | 15 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 6 | 4 | 8 | 60 | 12 |
| `francais/la-focalisation.json` | La focalisation | 7 | 4 | 8 | 49 | 16 |
| `francais/l-argumentation.json` | L'argumentation | 8 | 4 | 8 | 52 | 12 |
| `francais/l-implicite.json` | L'implicite | 9 | 4 | 8 | 49 | 12 |
| `francais/les-valeurs-des-temps-verbaux.json` | Les valeurs des temps verbaux | 10 | 4 | 8 | 50 | 15 |

##### 1ère D

| Fichier | Cours | Rang | Fiches | Exercices | Questions | Entraînement |
|---|---|---:|---:|---:|---:|---:|
| `francais/oeuvre-poetique.json` | Œuvre poétique | 1 | 4 | 8 | 56 | 16 |
| `francais/le-commentaire-compose.json` | Le commentaire composé | 2 | 4 | 8 | 57 | 14 |
| `francais/lecture-des-consignes-et-elaboration-de-plan.json` | Lecture des consignes et élaboration de plan | 3 | 4 | 8 | 50 | 12 |
| `francais/le-rythme-dans-le-texte.json` | Le rythme dans le texte | 4 | 4 | 8 | 50 | 12 |
| `francais/les-tonalites-litteraires.json` | Les tonalités littéraires | 5 | 5 | 9 | 54 | 15 |
| `francais/resume-du-texte-argumentatif.json` | Résumé du texte argumentatif | 6 | 4 | 8 | 60 | 12 |
| `francais/la-focalisation.json` | La focalisation | 7 | 4 | 8 | 49 | 16 |
| `francais/l-argumentation.json` | L'argumentation | 8 | 4 | 8 | 52 | 12 |
| `francais/l-implicite.json` | L'implicite | 9 | 4 | 8 | 49 | 12 |
| `francais/les-valeurs-des-temps-verbaux.json` | Les valeurs des temps verbaux | 10 | 4 | 8 | 50 | 15 |

**164 notions, 324 exercices, 2118 questions notées et 546 d’entraînement** pour les 40 fichiers. Tous passent `script/contenus/valider.rb` sans erreur ni avertissement et le contrôle de l’entraînement.

À faire valider par un enseignant de Français avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague P8).

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

### 1ère, Histoire-Géographie au format 3 (chantier `contenus-1ere-histoire-geographie`)

Les 10 premières leçons d'Histoire-Géographie de 1ère de la progression DPFC 2026-2027 (commune à toutes les séries : pas de `series_name`), rédigées le 2026-11-02 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md). Elles remplacent les 3 fichiers v1 du même intitulé. Chaque fichier a été relu par un sous-agent distinct de l'auteur (faits, dates, chiffres, cartes, calculs).

| # | Fichier | Cours | Notions | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---|
| 1 | `1ere/histoire-geographie/histoire-l-essor-du-capitalisme-et-ses-consequences.json` | Histoire — L'essor du capitalisme et ses conséquences | 4 | 51 | 88 % | 5 | `diagram`, `stat_chart`, `timeline` |
| 2 | `1ere/histoire-geographie/geographie-dynamisme-demographique-et-qualite-de-la-vie-en-cote-d-ivoire.json` | Géographie — Dynamisme démographique et qualité de la vie en Côte d'Ivoire | 3 | 46 | 87 % | 5 | `diagram`, `stat_chart`, `timeline` |
| 3 | `1ere/histoire-geographie/histoire-les-revolutions-industrielles.json` | Histoire — Les révolutions industrielles | 5 | 59 | 90 % | 4 | `diagram`, `map world`, `timeline` |
| 4 | `1ere/histoire-geographie/geographie-la-croissance-demographique-mondiale-et-ses-consequences.json` | Géographie — La croissance démographique mondiale et ses conséquences | 5 | 59 | 92 % | 4 | `diagram`, `map world`, `stat_chart` |
| 5 | `1ere/histoire-geographie/histoire-le-mouvement-imperialiste-et-le-congres-de-berlin.json` | Histoire — Le mouvement impérialiste et le congrès de Berlin | 4 | 49 | 88 % | 4 | `diagram`, `map africa`, `timeline` |
| 6 | `1ere/histoire-geographie/histoire-les-resistances-aux-conquetes-territoriales-exemple-de-la-cote-d-ivoire-de-1878-a-1920.json` | Histoire — Les résistances aux conquêtes territoriales : exemple de la Côte d'Ivoire de 1878 à 1920 | 4 | 49 | 88 % | 3 | `diagram`, `map cote_d_ivoire`, `timeline` |
| 7 | `1ere/histoire-geographie/geographie-l-urbanisation-dans-les-pays-en-developpement-l-exemple-de-la-cote-d-ivoire.json` | Géographie — L'urbanisation dans les pays en développement : l'exemple de la Côte d'Ivoire | 5 | 57 | 84 % | 3 | `diagram`, `map cote_d_ivoire` |
| 8 | `1ere/histoire-geographie/geographie-l-urbanisation-dans-les-pays-developpes-l-exemple-de-la-france.json` | Géographie — L'urbanisation dans les pays développés : l'exemple de la France | 4 | 51 | 88 % | 6 | `diagram`, `map world`, `stat_chart`, `timeline` |
| 9 | `1ere/histoire-geographie/histoire-la-colonisation-et-les-resistances-en-cote-d-ivoire-de-1893-a-1946.json` | Histoire — La colonisation et les résistances en Côte d'Ivoire de 1893 à 1946 | 5 | 54 | 91 % | 4 | `diagram`, `map cote_d_ivoire`, `timeline` |
| 10 | `1ere/histoire-geographie/geographie-l-organisation-administrative-de-la-cote-d-ivoire.json` | Géographie — L'organisation administrative de la Côte d'Ivoire | 4 | 48 | 85 % | 4 | `diagram`, `map cote_d_ivoire` |

Au total : 43 notions, 83 exercices, 523 questions et 42 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement. À faire relire par un enseignant d'Histoire-Géographie avant publication : voir `docs/chantiers/contenus-1ere-histoire-geographie/journal.md`.
### 1ère C et D, SVT au format 3 (chantier `contenus-1ere-svt-cd`)

Les 10 premières leçons de SVT de 1ère C et de 1ère D (progression DPFC 2026-2027), rédigées le 2026-11-01 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), vague P5 du programme `contenus-v3-tous-niveaux` (rédaction Sonnet, relecture indépendante Opus). **16 leçons distinctes, 20 fichiers** : 4 leçons sont communes aux deux séries (méiose, synthèse des protéines, mouvements des plaques, échanges d'ions) et écrites une fois, copiées avec la série et le rang de D (seuls `series_name` et `subtitle` changent) ; 3 paires proches (C1/D1, C3/D3, C6/D4) partagent le socle mais ont chacune leur intitulé, leurs notions et leurs exercices. Elles remplacent les 6 fichiers v1 de `1ere-c/svt/` et `1ere-d/svt/`. Chaque notion a sa fiche en 4 blocs, un exercice et un bloc « Je m'entraîne » ; chaque leçon a 4 problèmes.

| Série | # | Fichier | Cours | Notions | Exercices | Questions | Entraînement | Auto | Figures | Sortes |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| C | 1 | `1ere-c/svt/le-role-et-la-structure-des-gonades-des-mammiferes.json` | Le rôle et la structure des gonades des mammifères | 4 | 8 | 46 | 10 | 96 % | 4 | `diagram`, `plate female_reproductive_system`, `stat_chart bars` |
| C | 2 | `1ere-c/svt/la-division-meiotique.json` | La division méiotique | 4 | 8 | 46 | 13 | 98 % | 1 | `diagram` |
| C | 3 | `1ere-c/svt/la-gametogenese-chez-les-mammiferes.json` | La gamétogénèse chez les mammifères | 4 | 8 | 48 | 13 | 96 % | 3 | `diagram`, `stat_chart bars` |
| C | 4 | `1ere-c/svt/la-fecondation-chez-les-mammiferes.json` | La fécondation chez les mammifères | 3 | 7 | 44 | 9 | 93 % | 5 | `plate female_reproductive_system`, `diagram`, `stat_chart bars` |
| C | 5 | `1ere-c/svt/la-synthese-des-proteines.json` | La synthèse des protéines | 4 | 8 | 57 | 16 | 96 % | 2 | `diagram`, `stat_chart bars` |
| C | 6 | `1ere-c/svt/la-transmission-d-un-caractere-hereditaire.json` | La transmission d'un caractère héréditaire | 4 | 8 | 51 | 12 | 96 % | 2 | `diagram`, `stat_chart bars` |
| C | 7 | `1ere-c/svt/la-structure-interne-du-globe-terrestre.json` | La structure interne du globe terrestre | 4 | 8 | 49 | 14 | 98 % | 2 | `diagram` |
| C | 8 | `1ere-c/svt/les-mouvements-des-plaques-lithospheriques.json` | Les mouvements des plaques lithosphériques | 4 | 8 | 51 | 16 | 96 % | 3 | `map world`, `stat_chart line`, `diagram` |
| C | 9 | `1ere-c/svt/les-echanges-d-ions-au-niveau-du-sol.json` | Les échanges d'ions au niveau du sol | 4 | 8 | 52 | 12 | 96 % | 4 | `plate root_hairs`, `diagram`, `stat_chart bars` |
| C | 10 | `1ere-c/svt/la-photosynthese.json` | La photosynthèse | 4 | 8 | 48 | 12 | 96 % | 4 | `stat_chart line`, `diagram` |
| D | 1 | `1ere-d/svt/les-fonctions-des-gonades.json` | Les fonctions des gonades | 4 | 8 | 50 | 12 | 96 % | 4 | `diagram`, `stat_chart bars`, `plate female_reproductive_system` |
| D | 2 | `1ere-d/svt/la-division-meiotique.json` | La division méiotique | 4 | 8 | 46 | 13 | 98 % | 1 | `diagram` |
| D | 3 | `1ere-d/svt/la-gametogenese.json` | La gamétogénèse | 4 | 8 | 50 | 12 | 96 % | 4 | `diagram`, `stat_chart bars`, `plate female_reproductive_system` |
| D | 4 | `1ere-d/svt/la-transmission-d-un-caractere-hereditaire-le-monohybridisme.json` | La transmission d'un caractère héréditaire : le monohybridisme | 4 | 8 | 52 | 12 | 96 % | 2 | `diagram`, `stat_chart bars` |
| D | 5 | `1ere-d/svt/la-synthese-des-proteines.json` | La synthèse des protéines | 4 | 8 | 57 | 16 | 96 % | 2 | `diagram`, `stat_chart bars` |
| D | 6 | `1ere-d/svt/les-activites-internes-du-globe-terrestre.json` | Les activités internes du globe terrestre | 4 | 8 | 48 | 12 | 98 % | 3 | `stat_chart line`, `diagram`, `map africa` |
| D | 7 | `1ere-d/svt/les-mouvements-des-plaques-lithospheriques.json` | Les mouvements des plaques lithosphériques | 4 | 8 | 51 | 16 | 96 % | 3 | `map world`, `stat_chart line`, `diagram` |
| D | 8 | `1ere-d/svt/les-echanges-d-ions-au-niveau-du-sol.json` | Les échanges d'ions au niveau du sol | 4 | 8 | 52 | 12 | 96 % | 4 | `plate root_hairs`, `diagram`, `stat_chart bars` |
| D | 9 | `1ere-d/svt/l-evolution-des-sols-tropicaux.json` | L'évolution des sols tropicaux | 4 | 8 | 54 | 12 | 96 % | 5 | `plate soil_profile`, `diagram`, `stat_chart bars` |
| D | 10 | `1ere-d/svt/le-reflexe-inne.json` | Le réflexe inné | 5 | 9 | 56 | 13 | 95 % | 3 | `diagram`, `stat_chart line` |

Au total : 80 notions, 160 exercices, 1008 questions notées, 257 questions d'entraînement et 61 figures. Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et a été relu par un agent distinct de son auteur.

Schémas qu'aucune sorte ne dessine (décrits en texte ou en `diagram`) : testicule et tube séminifère, méiose, fécondation, ribosome et traduction, coupe du globe et coupe de subduction, complexe argilo-humique, chloroplaste, moelle épinière et œil. Les courbes sont à une seule série et à valeurs positives.

À faire valider par un enseignant de SVT avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague P5).
### 1ère A1 et A2, SVT au format 3 (chantier `contenus-1ere-a-svt`)

Les 9 leçons de SVT de 1ère A1 et A2 (progression DPFC 2026-2027, identique dans les deux séries ; le référentiel n'a pas de série « A » en 1ère), rédigées le 2026-11-02 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md), vague P6 du programme `contenus-v3-tous-niveaux`, pour des élèves de série littéraire : documents à analyser plutôt que calculs. Chaque leçon est écrite dans `1ere-a1/svt/` et copiée dans `1ere-a2/svt/`, où seule `series_name` change (18 fichiers). Elles remplacent les 3 fichiers v1 de chacun de ces dossiers (lignes SVT du tableau « 1ère A1 et A2 » ci-dessus). Aucune des 9 leçons n'existe en 1ère D (#435) : toutes sont des rédactions complètes. Rédaction par des agents Sonnet, relecture indépendante de chaque leçon par un agent Opus (qui vérifie aussi les faits médicaux des leçons 2, 4, 5 et 9). Chaque notion a sa fiche en 4 blocs, un exercice et un bloc « Je m'entraîne » ; chaque leçon a 4 problèmes.

| # | Fichier | Cours | Notions | Exercices | Questions | Entraînement | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `svt/le-reflexe-conditionnel.json` | Le réflexe conditionnel | 5 | 9 | 45 | 15 | 95 % | 4 | `diagram`, `stat_chart line` |
| 2 | `svt/les-effets-des-drogues-sur-le-comportement.json` | Les effets des drogues sur le comportement | 4 | 8 | 48 | 12 | 95 % | 2 | `diagram` |
| 3 | `svt/les-anomalies-chromosomiques.json` | Les anomalies chromosomiques | 3 | 7 | 45 | 9 | 95 % | 2 | `diagram`, `stat_chart bars` |
| 4 | `svt/les-cycles-sexuels-chez-la-femme.json` | Les cycles sexuels chez la femme | 4 | 8 | 49 | 10 | 93 % | 5 | `diagram`, `plate`, `stat_chart line` |
| 5 | `svt/la-regulation-des-naissances.json` | La régulation des naissances | 3 | 7 | 40 | 9 | 95 % | 3 | `diagram`, `plate` |
| 6 | `svt/la-transmission-d-un-caractere-hereditaire-lie-aux-autosomes.json` | La transmission d'un caractère héréditaire lié aux autosomes | 4 | 8 | 48 | 16 | 95 % | 3 | `diagram`, `stat_chart` |
| 7 | `svt/la-transmission-d-un-caractere-hereditaire-lie-aux-chromosomes-sexuels.json` | La transmission d'un caractère héréditaire lié aux chromosomes sexuels | 4 | 8 | 48 | 15 | 93 % | 2 | `diagram` |
| 8 | `svt/la-production-d-energie-par-la-cellule.json` | La production d'énergie par la cellule | 3 | 7 | 42 | 12 | 95 % | 2 | `diagram` |
| 9 | `svt/la-mise-en-reserve-des-nutriments.json` | La mise en réserve des nutriments | 4 | 8 | 48 | 12 | 95 % | 3 | `diagram`, `plate`, `stat_chart line` |

Au total, par série : 34 notions, 70 exercices, 413 questions notées, 110 questions d'entraînement et 26 figures. Les 18 fichiers passent `script/contenus/valider.rb` sans erreur ni avertissement ainsi que le contrôle de l'entraînement (règles du test de 3e, jouées par script : pas de test pour la 1ère).

Schémas qu'aucune sorte ne dessine (décrits en texte ou en `diagram`) : caryotype, cerveau et aires corticales, cellule et mitochondrie, coupe de l'ovaire (follicule, corps jaune) et utérus avec nidation, échiquier de croisement en tableau, arbre généalogique, courbe de température (le `stat_chart` part de zéro).

À faire valider par un enseignant de SVT avant publication : les points listés dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague P6).

### 1ère C et D, mathématiques au format 3 (chantier `contenus-1ere-mathematiques-cd`)

Les 10 premières leçons de Mathématiques de la progression DPFC 2026-2027 de 1ère C et de 1ère D, rédigées le 2026-11-01 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague P1 du programme `contenus-v3-tous-niveaux`). 13 leçons distinctes, 20 fichiers : les 7 leçons communes aux deux séries sont écrites une fois puis déclinées par série (acquis, interdits et exemples de la série). Elles **remplacent** les fichiers v1 du même intitulé rédigés le 2026-10-10 (rangs 1 à 3). « Généralités sur les fonctions » et « Dénombrement » restent déclinables en 1ère A (vague P2).

#### 1ère C

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/equations-et-inequations-dans.json` | Équations et inéquations dans ℝ | 4 | 8 | 49 | 96 % | 0 | — |
| 2 | `mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 4 | 8 | 48 | 96 % | 3 | `geometry` |
| 3 | `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 5 | 9 | 56 | 96 % | 0 | — |
| 4 | `mathematiques/barycentre.json` | Barycentre | 5 | 9 | 57 | 95 % | 2 | `coordinate_plane` |
| 5 | `mathematiques/limites-et-continuite.json` | Limites et continuité | 4 | 8 | 53 | 96 % | 0 | — |
| 6 | `mathematiques/denombrement.json` | Dénombrement | 4 | 8 | 53 | 96 % | 0 | — |
| 7 | `mathematiques/extension-de-la-notion-de-limite.json` | Extension de la notion de limite | 4 | 8 | 57 | 95 % | 0 | — |
| 8 | `mathematiques/composees-de-transformations-du-plan.json` | Composées de transformations du plan | 4 | 8 | 58 | 97 % | 2 | `coordinate_plane`, `geometry` |
| 9 | `mathematiques/derivation.json` | Dérivation | 5 | 9 | 56 | 96 % | 0 | — |
| 10 | `mathematiques/orthogonalite-de-l-espace.json` | Orthogonalité de l'espace | 5 | 9 | 54 | 96 % | 0 | — |

#### 1ère D

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures | Sortes |
|---:|---|---|---:|---:|---:|---:|---:|---|
| 1 | `mathematiques/equations-et-inequations-du-second-degre-dans.json` | Équations et inéquations du second degré dans ℝ | 4 | 8 | 54 | 96 % | 0 | — |
| 2 | `mathematiques/angles-orientes-et-trigonometrie.json` | Angles orientés et trigonométrie | 4 | 8 | 48 | 100 % | 3 | `geometry` |
| 3 | `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 5 | 9 | 55 | 100 % | 0 | — |
| 4 | `mathematiques/limites-et-continuite.json` | Limites et continuité | 4 | 8 | 49 | 100 % | 0 | — |
| 5 | `mathematiques/denombrement.json` | Dénombrement | 4 | 8 | 51 | 98 % | 0 | — |
| 6 | `mathematiques/derivation.json` | Dérivation | 5 | 9 | 56 | 98 % | 0 | — |
| 7 | `mathematiques/extension-de-la-notion-de-limite.json` | Extension de la notion de limite | 4 | 8 | 55 | 100 % | 0 | — |
| 8 | `mathematiques/barycentre.json` | Barycentre | 5 | 9 | 56 | 98 % | 2 | `coordinate_plane` |
| 9 | `mathematiques/etude-et-representation-graphique-d-une-fonction.json` | Étude et représentation graphique d'une fonction | 4 | 8 | 61 | 97 % | 0 | — |
| 10 | `mathematiques/probabilite.json` | Probabilité | 4 | 8 | 56 | 96 % | 0 | — |

Au total : 87 notions, 167 exercices, 1082 questions notées et 12 figures.

Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et « Je m'entraîne » respecte les règles de `Entities::Catalog::NotionPractice` (contrôle `docs/chantiers/contenus-1ere-mathematiques-cd/controle-entrainement.rb`). Chaque leçon a été relue par un second rédacteur (calculs refaits), et les défauts trouvés ont été corrigés. Les leçons restent en brouillon.

Figures manquantes (courbes, tableaux de variations, arbres, solides en perspective) : sortes absentes du moteur, notées en dette dans le journal du chantier.

### 1ère A1 et A2, mathématiques au format 3 (chantier `contenus-1ere-mathematiques-a`)

Les 7 leçons de Mathématiques de la progression DPFC 2026-2027 de la série A de 1ère, rédigées le 2026-11-02 au format `lnclass.course-tree` v3 avec [`prompt-redaction-lot.md`](prompt-redaction-lot.md) (vague P2 du programme `contenus-v3-tous-niveaux` ; rédaction Sonnet, relecture indépendante Opus). Le référentiel ouvre « 1ère A1 » et « 1ère A2 » : chaque leçon est écrite une fois puis déclinée en deux fichiers identiques à la série près, dans `1ere-a1/mathematiques/` et `1ere-a2/mathematiques/` (**7 leçons, 14 fichiers**). « Dénombrement » et « Généralités sur les fonctions » déclinent au niveau A les leçons de 1ère C/D (calculs plus simples, sans Angles ni Limites). Elles **remplacent** les fichiers v1 du même intitulé (rangs 1 à 3, rédigés le 2026-10-10).

| # | Fichier | Cours | Notions | Exercices | Questions | Auto | Figures |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | `mathematiques/equations-et-inequations.json` | Équations et inéquations | 4 | 8 | 48 | 100 % | 2 |
| 2 | `mathematiques/denombrement.json` | Dénombrement | 4 | 8 | 50 | 98 % | 0 |
| 3 | `mathematiques/generalites-sur-les-fonctions.json` | Généralités sur les fonctions | 4 | 8 | 51 | 96 % | 0 |
| 4 | `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions | 4 | 8 | 50 | 98 % | 0 |
| 5 | `mathematiques/suites-numeriques.json` | Suites numériques | 4 | 8 | 49 | 100 % | 1 |
| 6 | `mathematiques/statistique.json` | Statistique | 4 | 8 | 56 | 96 % | 3 |
| 7 | `mathematiques/systemes-d-equations-dans.json` | Systèmes d'équations dans ℝ × ℝ | 4 | 8 | 50 | 96 % | 1 |

Au total : 28 notions, 56 exercices, 354 questions notées.

Chaque fichier passe `script/contenus/valider.rb` sans erreur ni avertissement, et « Je m'entraîne » respecte `Entities::Catalog::NotionPractice` (contrôle `docs/chantiers/contenus-1ere-mathematiques-a/controle-entrainement.rb`). **Brouillon** : points à faire valider par un enseignant dans le [journal du programme](../chantiers/contenus-v3-tous-niveaux/journal.md#à-faire-valider-par-un-enseignant) (vague P2). Courbes de fonction et tableaux de variations : décrits dans les énoncés (dette notée au journal du chantier).

À faire valider par un enseignant de mathématiques avant publication : le périmètre de chaque notion (ce qui est traité ou non), les modèles de situation et les barèmes des problèmes. La liste par leçon est dans le journal du chantier [`contenus-1ere-mathematiques-cd`](../chantiers/contenus-1ere-mathematiques-cd/journal.md).

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
