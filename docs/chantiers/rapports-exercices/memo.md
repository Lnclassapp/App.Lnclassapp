# Memo — Comprendre où en est la classe sur un exercice

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/rapports-exercices` |
| **Programme** | `refonte-application`, vague V3 ([feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)) : tranche « exercices » du chantier prévu `rapports-de-classe` |

---

## Le problème

Un enseignant assigne un exercice à sa classe, les élèves le font, et **l'enseignant n'en apprend rien**. Il ne sait ni combien d'élèves l'ont fait, ni si la notion est comprise, ni quelles questions ont piégé la classe, ni quels élèves décrochent. L'ancienne application avait un rapport par exercice (synthèse et détaillé), mais il est cassé, et ses chiffres étaient faux (un taux de réussite qui dépasse 100 % dès qu'un élève recommence, des badges Bronze invisibles, un cache jamais invalidé).

Le besoin du porteur (2026-10-04) : **mesurer la compréhension des exercices et présenter l'information à l'enseignant au bon moment.**

## Pour qui

- **L'enseignant (Teacher)** de la classe, après avoir assigné un exercice : il veut savoir s'il peut avancer ou s'il doit revenir sur la notion, et quels élèves suivre.
- **L'équipe (Team)** : elle lit déjà toute classe et sa liste d'élèves ; elle voit la même statistique, en lecture.
- **L'élève (Student)** : il ne voit **rien** de la statistique de classe (scores nominatifs de ses camarades). Sa propre progression reste sur ses pages.
- **La direction (SchoolStaff)** : rien dans ce chantier ; elle lit déjà le travail des élèves par classe (espace direction simple, ADR-0065).
- **Le parent** : n'existe pas dans l'application.

## Pourquoi maintenant

La V1 (boucle pédagogique) est en production : les élèves font des exercices et des sessions s'accumulent. `rapports-de-classe` est le premier chantier de la V3, et la V5 (suivi des remédiations par l'enseignant, AS-17) en dépend.

## Hors périmètre

- Les **sessions de remédiation** : elles ne comptent ni dans la couleur ni dans le signe ; leur suivi relève de la V5 (AS-17).
- La **détection du bachotage** (essais enchaînés en quelques minutes) : piste notée, pas de règle dans ce chantier.
- La **fiche élève** (CL-13, AS-24), le **tableau de bord de classe** et la **liste paginée** (CL-14, CL-15), l'**activité des élèves sur l'accueil enseignant** (TR-05) : restent au chantier `rapports-de-classe`.
- Le **message d'encouragement** (AS-23) : 36 phrases en dur dans l'ancienne vue, à repenser à part.
- Les **notifications** (WhatsApp, push) quand un exercice devient lisible : relèvent de la V6.
- La **réussite de la fiche essentielle dans la classe** (UDR-0029) et l'**accueil enseignant** : inchangés.
- Tout **cache** des agrégats : la lecture se fait en direct (ADR-0062, ADR-0067 : index d'abord, cache en dernier recours).
- L'**export** (PDF, tableur) du rapport.
- **Le signe de progrès vu par l'élève lui-même** sur ses pages : aligné sur la mission, mais c'est un autre acteur et un autre écran (UDR-0058). Chantier de suivi proposé : `progres-eleve`.
- **Nommer les élèves qui n'ont pas encore fait l'exercice** sur la page de suivi : question ouverte de l'ADR-0072, à trancher par le porteur.
- Ce que voit la **direction** : inchangé.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les « stats sur les exercices », c'est quoi ? | Mesurer la compréhension des exercices et la présenter à l'enseignant au bon moment ; partir de ce que prévoit la V3. (porteur, 2026-10-04) | Chantier côté enseignant, tranche « exercices » de `rapports-de-classe` (AS-21, AS-22, AS-23, AS-25 candidates). Le « bon moment » devient une question de cadrage à part entière. |
| Comment se lit la compréhension ? | Chaque élève est classé selon son score en **trois couleurs** : **rouge** = en difficulté, moins de 70 % ; **jaune** = de 70 à 80 % ; **vert** = plus de 80 %. Un **cercle** prend la couleur de la catégorie dominante. **Au clic sur une catégorie**, on voit le taux de réussite des questions. (porteur, 2026-10-04) | Une lecture en trois catégories remplace les quatre KPI et les deux tableaux de l'ancien rapport. Les bornes ne sont pas celles des libellés de l'ADR-0033 (« En difficulté » < 50, « Fragile » 50-69, « Acquis » ≥ 70) : amendement d'ADR à prévoir. Le détail par question est filtré par catégorie d'élèves. |
| Les bornes des couleurs (< 70 / 70-80 / > 80) contredisent les libellés de l'ADR-0033 : laquelle garder ? | **L'ancienne règle** (porteur, 2026-10-04) : **rouge** « En difficulté » sous 50 %, **jaune** « Fragile » de 50 à 69 %, **vert** « Acquis » à 70 % et plus. 50 pile est jaune, 70 pile est vert. | Les seuils `PASS_THRESHOLD` (50) et `MASTERY_THRESHOLD` (70) de l'ADR-0033 servent tels quels : **aucun amendement d'ADR** sur le barème. Ce sont aussi les bornes de l'ancien rapport (« À réviser » / « À surveiller » / « Maîtrisé »). Tests aux bornes 49, 50, 69, 70. |
| Quel score classe l'élève : meilleur, premier ou dernier essai ? | Proposé : le premier essai terminé (la correction affichée après chaque question fait réciter le corrigé dès le deuxième essai). **Refusé par le porteur** (2026-10-04) : le premier essai cache les progrès, or montrer le progrès des élèves est l'atout de Lnclass. **Retenu : la moyenne des scores des trois premiers essais terminés** (un ou deux si l'élève n'en a pas fait plus). | La catégorie d'un élève peut bouger jusqu'à son troisième essai, puis elle est figée (sessions immuables, ADR-0054). Les essais au-delà du troisième et les sessions de remédiation ne comptent pas. Le taux par question se calcule sur ces mêmes essais : il ne peut donc pas dépasser 100 % (défaut AS-22 de l'ancienne application). Tests : 1, 2, 3 et 4 essais ; moyenne aux bornes 50 et 70. |
| Les élèves qui n'ont pas fini l'exercice, et le cercle d'une classe où 2 élèves sur 45 ont rendu ? | Proposé et **validé par le porteur** (2026-10-04) : le cercle reste **gris, avec « 2/45 »**, tant que **moins de 5 élèves** ont fini un essai ; au-delà, il prend la couleur dominante, et le compte « rendus / effectif » reste affiché. Un élève sans essai terminé n'entre dans **aucune** couleur. | Même seuil de 5 que l'espace direction (« — » sous 5 élèves ayant rendu). Le compte « rendus / effectif » fait partie de l'affichage, pas seulement la couleur. Tests à 4 et 5 élèves ayant rendu. |
| La moyenne efface le progrès (30-60-90 et 60-60-60 donnent tous deux 60 %) : faut-il un signe de progrès ? | **Oui, aux deux endroits** : à côté de chaque élève dans le détail d'une catégorie, et en synthèse sur l'écran de la statistique. **Trois signes : progrès, stagne, en baisse.** Le porteur rouvre la base de la couleur : « et si on prenait son meilleur score, associé au signe ? » (porteur, 2026-10-04) | Le progrès devient une information de premier rang, pas un détail. La règle du signe (quels essais comparer, quelle marge) et la base de la couleur (moyenne des trois premiers ou meilleur score) sont en cours d'exploration. |
| Meilleur score pour la couleur, et quelle règle pour le signe ? (exploration du 2026-10-04) | **Validé par le porteur** (2026-10-04) : la **couleur suit le meilleur score** (alignée sur les badges : sans badge = rouge, Bronze = jaune, Argent et plus = vert). Le **signe** compare le premier, le meilleur et le dernier essai, avec une **marge de 10 points** : *progrès* si le meilleur dépasse le premier d'au moins 10 points et que le dernier reste à moins de 10 points du meilleur ; *en baisse* si le dernier est au moins 10 points sous le meilleur ; sinon *stagne*, affiché **« stable »** quand le meilleur atteint 70 %. Un seul essai : pas de signe. Pièges validés : bachotage hors périmètre ; taux par question calculé sur le meilleur essai des élèves de la catégorie ; synthèse « N en progrès · N stables · N en baisse ». | **Remplace la moyenne des trois premiers essais.** Tous les essais standard terminés comptent, sans plafond. Les règles deviennent des règles de domaine nommées (marge, seuil d'affichage), décidées par un ADR. La couleur et le badge d'un élève ne se contredisent jamais. Tests : 30-60-90, 60-60-60, 30-90-40, 90-40, 100-100, un seul essai. |
| Un élève dans deux classes, ou parti de la classe ? Quelles sessions comptent ? | **Décision alignée** sur la définition de « fait » (ADR-0048, ADR-0072 §4.4), déjà affichée sur la page classe : la statistique est celle d'un **exercice assigné** à la classe ; ne comptent que les sessions **standard terminées rattachées à cette assignation**, des élèves **présents** (adhésion non quittée, compte non anonymisé). Une session lancée depuis une autre classe ou hors assignation ne compte pas. | Le « 18/45 » du cercle est exactement le « 18 faits » déjà affiché : jamais deux chiffres différents sur la même page. La réussite de la fiche essentielle dans la classe (UDR-0029), qui lit toutes les sessions, reste telle quelle et hors périmètre. Tests : élève parti, élève anonymisé, session d'une autre classe, session de remédiation, session commencée non terminée. |
| Qui peut lire la statistique ? Un enseignant d'un autre établissement, un élève ? | **Décision alignée** sur le suivi d'un exercice assigné (ADR-0072 §4.5) : la policy de suivi existante, qui accepte l'équipe et l'enseignant de la classe (classe active ou archivée) et refuse l'élève, un autre enseignant, la direction et le visiteur. Un enseignant n'a qu'un établissement (ADR-0030). | **Aucune policy nouvelle** : la statistique vit sur la page de suivi et sur la page classe, déjà gardées par cette policy. Tests de refus : élève de la classe, enseignant d'une autre classe, direction. |
| « Au bon moment » : où l'enseignant croise-t-il l'information sans aller la chercher ? | **Décision alignée** : sur la **page de sa classe**, où il arrive en premier, dans le bloc « Exercices assignés » qui donne déjà l'échéance (prochaine séance, ADR-0072) et les faits. Chaque exercice y gagne, **au bord bas**, ses badges **à gauche** et le cercle **à droite**. Le cercle reste gris tant que moins de 5 élèves ont fait l'exercice : l'enseignant le voit se colorer en préparant sa prochaine séance. | L'UDR-0062 §3.4 (ligne d'exercice assigné) est amendée. Pas de notification, pas d'accueil enseignant (hors périmètre). La fiche essentielle dans la classe ne change pas. |
| Que se passe-t-il au clic ? | **Décision alignée** : le cercle et la ligne mènent à la **page de suivi** de l'exercice assigné (UDR-0062 §3.5), qui gagne une section « Compréhension » sous ses trois chiffres : le grand cercle, la synthèse des signes, puis les trois catégories. Choisir une catégorie affiche le **taux de réussite de chaque question** pour ses élèves et la **liste de ses élèves** avec meilleur score et signe. Lisible sans JavaScript. | Une UDR nouvelle pour la section, qui amende l'UDR-0062 §3.5. La catégorie choisie vit dans l'adresse : l'écran se partage et se recharge sans perdre le choix. La page de suivi nomme déjà des élèves sous sa policy : rien ne change pour la confidentialité. |
| Quels badges compter au bord bas de l'exercice ? | **Décision** : les quatre paliers (Bronze, Argent, Or, Diamant), comptés parmi les élèves qui ont fait l'exercice assigné, d'après leur **meilleur score sur cette assignation** (le barème de l'ADR-0033). Les quatre sont toujours affichés, un palier à zéro en atténué : l'ancien rapport omettait le Bronze (AS-25). | Couleur et badge viennent du même score : ils ne se contredisent jamais. Coût consenti : un élève qui a obtenu un badge plus haut hors de cette assignation (autre classe, avant l'assignation) apparaît ici à son palier de l'assignation. Aucune lecture de la table des badges. |
| Les décisions servent-elles la mission ? | **Rappel du porteur** (2026-10-04) : la mission de Lnclass est d'aider les acteurs du système éducatif à **progresser** ; les décisions doivent s'y aligner. | Relecture de chaque décision. Trois ajouts : le taux au **premier essai** à côté du taux au meilleur essai, pour montrer ce que la classe a appris ; la marque « **À reprendre en classe** » sous 50 % ; les élèves **en baisse ou qui stagnent en tête** de leur catégorie. Une suite proposée hors de ce chantier : montrer à l'élève son propre signe de progrès. |
| Que montre le cercle quand deux catégories sont à égalité ? | **Décision** : la plus fragile l'emporte (rouge avant jaune avant vert). L'enseignant est alerté plutôt que rassuré à tort. | Règle de domaine testée (égalité rouge/vert, jaune/vert). |
| Où l'information apparaît-elle ? | Sur la carte de l'exercice, **bord bas** : les icônes de badges **à gauche**, l'icône de la statistique **à droite, isolée** des autres. (porteur, 2026-10-04) | La carte d'exercice dans la classe change : UDR obligatoire (amendement de l'UDR de la carte, ou nouvelle UDR). Les compteurs de badges (AS-25) entrent dans le périmètre. |

## Cas limites identifiés

- **Classe sans élève**, ou exercice sans aucun rendu : cercle gris « 0/0 » ou « 0/45 », écran de statistique avec un état vide.
- **4 rendus** : cercle gris ; **5 rendus** : cercle coloré.
- **Exercice archivé ou dépublié après des rendus** : il n'est plus proposé à l'assignation, mais une assignation active le garde dans la section « Exercices assignés » de la classe avec sa statistique.
- **Question ajoutée ou retirée après des rendus** : le taux par question ne porte que sur les questions encore présentes dans l'exercice ; une question sans réponse dans la catégorie affiche « — ».
- **Élève avec une session commencée, jamais terminée** : il ne compte pas comme rendu.
- **Classe archivée** : la statistique reste lisible (lecture seule).
- **Mille élèves** : impossible par le plafond d'effectif d'une classe (ADR-0041) ; la lecture se fait en une requête groupée par écran.

## Questions encore ouvertes

- Faut-il nommer, sur la page de suivi, les élèves qui n'ont pas encore fait l'exercice ? Pour les aider à progresser, l'enseignant doit savoir qui relancer. La question est restée ouverte à l'ADR-0072.
- Le porteur a fourni des captures qui n'étaient pas les maquettes de l'écran : l'UDR propose une mise en page ; à confronter aux maquettes si elles existent.
- La marge de 10 points est une première valeur : à revoir après usage réel, elle n'a qu'une définition dans le code.
