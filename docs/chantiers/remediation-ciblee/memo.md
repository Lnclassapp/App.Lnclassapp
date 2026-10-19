# Memo — Remédiation ciblée : l'élève lève sa fiche, l'enseignant voit qui bloque

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré — PR prête vers `Develop` (2026-10-16), recommandations Q1 à Q12 acceptées par le porteur |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `docs/cadrage-remediation-ciblee` (cadrage, docs seules) ; le code passera par `feature/remediation-ciblee` et une PR |
| **Programme** | `refonte-application`, vague **V5** ([feuille de route §5](../refonte-application/feuille-de-route.md#v5--remédiation-et-lacunes)) : AS-16 et AS-17. La feuille de route nomme ce chantier `remediation` ; il s'appelle `remediation-ciblee` |

---

## Le problème

Une lacune s'ouvre quand un élève obtient moins de 50 % à un exercice. Elle se lève quand il obtient au moins 75 % à un exercice de la même fiche (ADR-0043, amendé le 2026-09-27). Ce moteur tourne en production depuis la V1. Deux personnes n'en profitent pourtant qu'à moitié.

**L'élève** peut déjà lever sa fiche, mais sans être guidé.
- Le bouton « Refaire un exercice » de la fiche mène au **premier** exercice de la liste. C'est souvent celui qu'il vient de rater, alors que l'ADR-0043 demande un autre exercice, de fixation de préférence.
- La règle est donnée en pourcentage (« au moins 75 % »), alors que l'élève lit toutes ses notes sur 20 (UDR-0023).
- Le résultat de la session ne lui dit jamais ce qu'il advient de sa fiche : passée « à revoir », levée, ou encore à revoir.
- À 14/20, il reçoit « Félicitations ! » et des confettis, mais sa fiche reste à revoir : il faut 15/20. Rien ne le lui explique.

**L'enseignant** ne voit rien. Aucune page de l'enseignant ne lit `knowledge_gaps`. Il ne sait ni quels élèves sont en difficulté sur une fiche, ni qui s'en est sorti. C'est pourtant ce que promet la V5 : « l'enseignant voit qui est en difficulté et qui a réussi sa remédiation ».

## Pour qui

- **L'élève (Student)**, après un échec sous 10/20 : depuis son accueil (« Fiches essentielles à revoir ») puis la fiche, il refait un exercice et apprend, sur le résultat, si sa fiche est levée.
- **L'enseignant (Teacher)** de la classe, quand il prépare sa prochaine séance : sur la page de sa classe et sur une fiche vue depuis la classe, il voit les élèves à aider.
- **L'équipe (Team)** : elle lit les mêmes pages de classe, en lecture seule.
- **La direction (SchoolStaff)** : rien. Elle ne voit ni les noms ni les retards (ADR-0072 §4.5).

## Pourquoi maintenant

Le porteur a lancé les vagues V2 à V6. Le côté élève (AS-16) ne dépend que de la V1, qui est livrée. Le côté enseignant (AS-17) devait attendre `rapports-de-classe`. Or sa tranche « exercices » est livrée (`rapports-exercices`, #164), et la page de la classe comme la fiche vue depuis la classe existent déjà (UDR-0027, UDR-0029). Les lacunes s'accumulent en production, mais aucun enseignant ne les voit.

## Inventaire : ce qui existe, ce qui manque

Vérifié dans le code de `origin/Develop` le 2026-10-16.

| Élément | État | Où |
|---|---|---|
| Détection et résolution des lacunes à la clôture, seuils 50 et 75 (AS-14, AS-15) | ✅ livré | `UseCases::Assessment::CloseExerciseSession#settle_gap`, `Entities::Assessment::GapDecision` |
| Une seule lacune en attente par élève et par fiche, garantie en base | ✅ livré | index `index_knowledge_gaps_one_pending` |
| Session marquée `kind: "remediation"` + `knowledge_gap_id` | ✅ livré | contrainte `exercise_sessions_remediation_iff_gap` |
| **Lancer une remédiation** | ✅ **de fait, implicitement** : toute session ouverte sur **n'importe quel** exercice d'une fiche à revoir est une remédiation | `StartExerciseSession#new_session` |
| `Assessment::StartRemediationSession` et `POST /remediation_sessions` (ADR-0043 §4) | ❌ n'existent pas, et ne servent plus à rien (voir Q1) | — |
| La remédiation compte comme « fait » (enseignant, direction) | ✅ livré | ADR-0079 §4.1, chantier `remediation-comptee-faite` (#169) |
| La remédiation compte dans l'historique et la phrase de progrès | ✅ livré | `progres-eleve` (#168), défaut D1 corrigé |
| Accueil élève : carte « Fiches essentielles à revoir », 3 lignes puis « Voir plus », vers la fiche | ✅ livré | `classroom/student_homes/_pending_gaps` |
| Fiche : encart « Fiche essentielle à revoir », date, règle en infobulle | ✅ livré | `catalog/essentials/show` `#essential_gap` |
| Fiche : bouton vers un exercice **choisi** (ADR-0043) | ⚠️ **à reprendre** : mène à `exercises.first`, la page de l'exercice, pas une session | idem, `#essential_gap_action` |
| Règle affichée sur 20 | ⚠️ **à reprendre** : « 75 % » sur la fiche et dans l'aide | `catalog/essentials.fr.yml`, `communication/help.fr.yml` |
| Résultat : effet de la session sur la fiche | ❌ **manque** | `assessment/session_results/show` |
| Enseignant : élèves à revoir et fiches levées | ❌ **manque** : aucune lecture de `knowledge_gaps` côté enseignant | — |

**Reste à faire** : AS-16 se réduit à guider l'élève (le bon exercice, la règle sur 20, l'effet sur le résultat). AS-17 est entier. **Aucune table, aucune migration, aucune route nouvelle.**

## Hors périmètre

- Toute **migration** : le schéma de l'ADR-0043 suffit, et les index existants couvrent les lectures (index partiel par élève, index par fiche).
- Le **moteur** : seuils (50, 70, 75), `GapDecision`, `CloseExerciseSession` et le caractère implicite de la remédiation dans `StartExerciseSession` restent tels quels.
- La **génération de questions** de remédiation, et la lacune **par question** : la remédiation réutilise les exercices de la fiche (ADR-0043 §5).
- Une **marque « remédiation » pendant la session** : la session reste en mode concentré (UDR-0087), voir Q6.
- La **fiche d'un élève** (CL-13, AS-24), le tableau de bord de classe et la liste paginée (CL-14, CL-15) : chantier `rapports-de-classe`.
- L'**accueil enseignant** et ses « Activités » (UDR-0077) : inchangés.
- La **page de suivi d'un exercice assigné** (UDR-0072) : inchangée. La lacune vit sur la fiche, pas sur l'exercice.
- Les **notifications** (WhatsApp, push) à l'élève ou à l'enseignant : V6.
- La **direction** : elle ne voit ni les noms ni les lacunes.
- Les **élèves de démonstration** (AS-26, ADR-0019).
- L'**export** des lacunes.

## Ce que le grill a révélé

Le grill a porté sur le code réel, pas sur l'ADR-0043. Il a trouvé que le lancement explicite décrit par l'ADR n'a plus d'objet, et que la distinction « corrigé seul » ne se produit presque jamais. Les questions ci-dessous attendent la réponse du porteur. Chacune porte une recommandation.

| # | Question au porteur | Recommandation | Conséquence sur le chantier |
|---|---|---|---|
| Q1 | L'ADR-0043 prévoit un use case `StartRemediationSession` et une route dédiée. Or `StartExerciseSession` ouvre déjà une remédiation sur **tout** exercice d'une fiche à revoir, et les ADR-0079 et `remediation-comptee-faite` s'appuient sur ce fonctionnement. On l'entérine et on renonce au use case dédié ? | **Oui.** Un deuxième point d'entrée ferait deux chemins pour une même session. L'élève qui « refait un exercice » de la fiche fait déjà une remédiation. | ADR-0101 amende l'ADR-0043 §4 (démarrage) et §7 (vérification). Pas de route, pas de use case nouveaux. |
| Q2 | Quel exercice le bouton de la fiche propose-t-il ? | **La règle de l'ADR-0043**, rendue déterministe : un exercice publié de la fiche, **différent de l'exercice raté**, de type **fixation** de préférence, puis par position. À défaut d'autre exercice : l'exercice raté. Ne pas ajouter « assigné à la classe » comme critère : la règle doit rester simple et se tester en un fichier. | Règle de domaine pure `Entities::Assessment::RemediationPick`, lue par la query de la fiche. |
| Q3 | Le bouton démarre-t-il la session directement, ou ouvre-t-il la page de l'exercice ? | **Directement** : un POST vers la route existante `exercise_sessions` (comme « Commencer »). Une session déjà commencée sur cet exercice est reprise. Le titre de l'exercice proposé s'affiche sous le bouton. | Un tap de moins. Aucun changement de contrôleur. |
| Q4 | La règle pour lever la fiche se dit « 75 % » ; l'élève lit toutes ses notes sur 20. On l'écrit « 15/20 » ? | **Oui**, sur la fiche, dans l'aide et sur le résultat. On calcule la valeur avec `Grading.grade_on_20(REMEDIATION_THRESHOLD)`, sans l'écrire en dur. | Textes de `catalog/essentials.fr.yml` et `communication/help.fr.yml`. |
| Q5 | Le résultat d'une session dit-il à l'élève l'effet sur sa fiche ? | **Oui**, en une ligne sous la note : « Fiche levée » (session qui l'a levée), « Encore à revoir : vise 15/20 » (session de remédiation sous 15/20) ou « Cette fiche passe à revoir » (session qui l'a ouverte). On garde les confettis à 14/20, mais la ligne dit qu'il manque un point. **Élève seul**, comme la phrase de progrès (UDR-0073) : l'enseignant a ses propres pages. | UDR-0120. Lecture seule, à partir des colonnes existantes. |
| Q6 | Faut-il marquer la session elle-même (« Révision de la fiche … ») pendant qu'elle se joue ? | **Non.** La session est en mode concentré (UDR-0087) ; l'élève sait d'où il vient. | Rien sur `exercise_sessions/show`. |
| Q7 | AS-17 doit-il attendre `rapports-de-classe` (V3), comme le prévoit la feuille de route ? | **Non.** On l'affiche sur deux pages qui existent déjà : la **page de la classe** (un bloc « Fiches à revoir » : fiche, nombre d'élèves) et la **fiche vue depuis la classe** (les noms). La fiche élève (CL-13) pourra reprendre la même query plus tard. | UDR-0121. La dépendance V3 → AS-17 de la feuille de route tombe. |
| Q8 | L'ancienne application séparait « Auto-corrigés » et « Remédiation réussie ». Or, puisque toute session sur une fiche à revoir est une remédiation, `self_corrected` n'arrive plus que pour une session **commencée avant** l'échec et finie après. On garde la distinction à l'écran ? | **Non** : deux groupes, « À revoir » et « Fiche levée ». La base garde les deux statuts ; l'écran ne les sépare pas. | Pas de troisième colonne vide. ADR-0101 le note. |
| Q9 | Quelles lacunes levées l'enseignant voit-il ? Elles s'accumulent sans fin. | Celles **levées pendant l'année scolaire de la classe** (ADR-0041). Les lacunes **à revoir**, elles, s'affichent toutes, quelle que soit leur date d'ouverture : la difficulté est actuelle. | Filtre sur `resolved_at` dans la query enseignant. |
| Q10 | Quelles fiches le bloc de la page de classe liste-t-il ? | Celles des **cours déjà affichés sur la page** : niveau et série de la classe, matière de l'enseignant ; pour l'équipe, toutes les matières. Le bloc se trie par nombre d'élèves à revoir, du plus grand au plus petit. Il montre 3 lignes, puis « Voir plus ». Il n'apparaît pas si aucune fiche n'est à revoir. | Même filtre que `ClassroomOverviewQuery#courses`. |
| Q11 | L'enseignant voit-il combien de fois l'élève a échoué (`failed_sessions_count`) ? | **Oui**, « 3 essais sous la moyenne » dès 2 échecs. C'est ce qui distingue l'élève qui bloque de celui qui vient de rater une fois. | Colonne déjà en base. |
| Q12 | Seuls les élèves présents comptent : adhésion non quittée, compte non anonymisé, comme l'ADR-0079 ? | **Oui.** Un élève parti ou anonymisé disparaît des deux pages. | Réutilise `AssignmentFollowUpQuery.present_students`. |

## Cas limites identifiés

- **Fiche à un seul exercice publié** : le bouton propose l'exercice raté (ADR-0043 §5).
- **Fiche sans exercice publié** : pas de bouton ; l'encart reste (comportement actuel).
- **Exercice proposé déjà commencé en `standard`**, avant l'échec : la session reprise reste `standard`. À 15/20, la fiche se lève en `self_corrected`. C'est accepté, et l'écran enseignant ne fait pas la différence (Q8).
- **Remédiation entre 10/20 et 14/20** : la fiche reste à revoir, sans échec de plus (amendement ADR-0043). Le résultat dit « Encore à revoir : vise 15/20 ».
- **Résultat relu plus tard**, après qu'une autre session a levé la fiche : la ligne ne parle que de **cette** session. Elle disparaît si la fiche a été levée par une autre.
- **Deux onglets** : une remédiation rattachée à une lacune que l'autre onglet a déjà levée. Si une nouvelle lacune s'est ouverte entre-temps, `GapDecision` lève la nouvelle. Le résultat suit `resolved_by_session_id`, pas `knowledge_gap_id`.
- **Élève passé dans une autre classe** : ses lacunes le suivent, et seule sa classe actuelle les voit (Q12).
- **Fiche dépubliée ou cours dépublié** : la lacune n'est proposée ni à l'élève (comportement actuel de l'accueil) ni dans le bloc de la classe. Sur la fiche vue depuis la classe, la page elle-même répond 404.
- **Classe archivée** : l'enseignant garde la lecture (ReadClassroomPolicy) ; les lacunes levées sont celles de l'année de la classe.
- **Équipe** : elle voit toutes les matières de la classe.

## Questions encore ouvertes

- Aucune. Q1 à Q12 : recommandations acceptées par le porteur le 2026-10-16 (ci-dessous) ; l'ADR-0101 et les UDR-0119 à 0121 passent « Accepté ».

## Réponses du porteur (2026-10-16)

- Recommandations acceptées.
