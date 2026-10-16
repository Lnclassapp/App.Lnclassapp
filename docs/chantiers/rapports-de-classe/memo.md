# Memo — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage (questions au porteur ouvertes) |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `docs/cadrage-rapports-de-classe` (cadrage, docs seules) ; le code passera par `feature/rapports-de-classe` et une PR |
| **Programme** | `refonte-application`, vague V3 ([feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)), premier chantier de la vague ; la V5 (AS-17) en dépend |

---

## Le problème

L'enseignant voit sa classe : chaque exercice assigné porte ses faits, ses badges et sa compréhension (`rapports-exercices`, ADR-0079). Mais **il ne peut pas regarder un élève**. Sur la page de la classe, une ligne d'élève donne son dernier score et son « fait seul » ; sur la page de suivi, les élèves d'une catégorie, en retard ou pas encore faits sont nommés. Aucun de ces noms ne mène nulle part (UDR-0027, UDR-0072 §3.5 : « les lignes ne sont pas des liens : la fiche élève n'est pas encore là »).

Pour savoir où en est Awa sur les dix exercices de la classe, l'enseignant doit ouvrir dix pages de suivi et chercher son nom dans chacune. Il ne le fait pas. Les élèves qui décrochent restent donc des noms dans des listes.

Deux autres manques :

- **La liste des élèves n'a pas de limite.** Une classe va jusqu'à 80 élèves par défaut et 150 au plus (`CLASSROOM::MAX_STUDENTS`). Avec 55 élèves, la liste pèse déjà 147,7 Ko, et la page de la classe est hors budget : 153 ms p95 et 231,6 Ko, pour un budget de 100 ms et 150 Ko (journal de `rapports-exercices`, ADR-0067).
- **La page de suivi lit la classe, mais ne propose rien.** L'ancienne application terminait le rapport par un message à l'enseignant (AS-23) : 36 phrases en dur dans la vue, une par exercice, toujours la même.

## Pour qui

- **L'enseignant (Teacher)** de la classe : il prépare sa séance, voit un élève en baisse ou en retard, et veut comprendre ce qui se passe pour lui avant de le relancer.
- **L'équipe (Team)** : elle lit déjà toute classe et sa liste d'élèves ; elle lit la fiche aux mêmes conditions.
- **L'élève (Student)** : rien. Il n'a pas accès à la page de sa classe côté enseignant, ni à la fiche d'un camarade. Sa propre progression reste sur ses pages (`progres-eleve`, `historique-eleve`).
- **La direction (SchoolStaff)** : rien. Elle lit le travail des élèves dans son espace (ADR-0065) et n'ouvre pas la page de la classe de l'enseignant.
- **Le parent** : n'existe pas dans l'application.

## Pourquoi maintenant

- C'est le premier chantier de la V3, et la V5 en dépend : le suivi des remédiations par l'enseignant (AS-17) s'affichera dans ses rapports, donc sur la fiche d'un élève.
- La tranche « exercices » est livrée (`rapports-exercices`, #164), et les écrans enseignant sont réorganisés (`interface-enseignant-organisation`). Le reste du chantier est désormais petit et bien délimité.
- La page de la classe est hors budget depuis `rapports-exercices` (dette D3). La liste des élèves en est la cause principale.

## Inventaire : ce qui est fait, ce qui reste

Vérifié dans le code de `Develop` le 2026-10-16.

| Feature | Attendu (feuille de route) | État dans le code | Reste |
|---|---|---|---|
| **AS-21** Rapport de synthèse d'un exercice | Faits, réussite, badges d'un exercice pour la classe | **Fait.** Comptes « faits · en retard · pas encore faits » (`AssignmentFollowUpQuery`), cercle de compréhension et badges au bord bas (`ComprehensionSummaryQuery`, UDR-0072 §3.4) | — |
| **AS-22** Rapport détaillé par question et par élève | Taux par question sans dépasser 100 %, détail par élève | **Fait en grande partie.** Taux par question au meilleur et au premier essai, par catégorie ; élèves d'une catégorie avec meilleur score et signe (`ComprehensionDetailQuery`, UDR-0072 §3.5) | Les noms ne mènent à rien : il manque le passage du rapport à l'élève (lien vers sa fiche) |
| **AS-25** Compteurs de badges sur la carte | Quatre paliers, Bronze compris, sans N+1 | **Fait.** Quatre paliers, d'après le meilleur score sur l'assignation, en nombre de requêtes constant (ADR-0079 §4.2) | — |
| **CL-13 = AS-24** Fiche d'un élève de sa classe | Sessions et badges de l'élève, sans mélanger les classes | **Absent.** Aucune route GET `classrooms/:id/students/:id` (seul le DELETE du retrait existe), aucune query, aucune vue. La ligne de la liste mène au résultat de la **dernière** session, toutes classes confondues (`ClassroomOverviewQuery#last_sessions`) | Toute la fiche |
| **AS-23** Message d'encouragement | Un message adapté aux résultats de la classe | **Absent** | À trancher (Q6) |
| **CL-14** Tableau de bord d'une classe | Fusionné avec CL-10 | **Fait par la page de la classe** (CL-10, V1) enrichie de `rapports-exercices`. Les trois compteurs de l'ancienne page (% d'actifs, moyenne, total des badges) n'ont pas été repris | À trancher (Q7) : fermer, ou ajouter des chiffres de classe |
| **CL-15** Liste paginée des élèves | Liste sous policy, à jour, paginée | **En partie.** Liste sous `ReadClassroomPolicy`, lue en direct, avec recherche (UDR-0054 §3.9). **Pas de pagination** : toute la classe est rendue | Pagination (Q5) |
| **TR-05** (part V3) Activité des élèves sur l'accueil enseignant | — | **Fait** par `interface-enseignant-organisation` : section « Activités » = exercices à suivre (`TeacherFollowUpsQuery`, UDR-0077 §3.1) | À confirmer (Q1) |
| **TR-32** (part V3) Cache des rapports | Rapports sans cache périmé | **Fermé par décision** : lecture en direct, aucun cache (ADR-0079 §4.6, ADR-0067). Aucun cache n'existe, aucun ne peut être périmé | À confirmer (Q1) |

Chantiers livrés lus pour cet inventaire : [`rapports-exercices`](../rapports-exercices/memo.md) (ADR-0079, UDR-0072), [`progres-eleve`](../progres-eleve/memo.md) (le signe vu par l'élève), [`remediation-comptee-faite`](../remediation-comptee-faite/memo.md) (une remédiation sur l'exercice assigné, c'est l'avoir fait, côté direction aussi), [`interface-enseignant-organisation`](../interface-enseignant-organisation/memo.md) (« Activités » de l'accueil, ordre de la page de la classe), et la page de la classe (`Queries::Classroom::ClassroomOverviewQuery`, UDR-0027, UDR-0077 §3.4, UDR-0081 §3.7, UDR-0084 §3.7).

**Ce qui reste, en résumé :** la fiche d'un élève dans sa classe, les liens qui y mènent depuis la page de la classe et la page de suivi, la pagination de la liste des élèves, et, selon les réponses, une phrase « prochain geste » sur la page de suivi.

## Hors périmètre

- **Le suivi des remédiations** (AS-17) : V5. La fiche lui laisse sa place, sans rien en afficher. Les lacunes en attente d'un élève n'y apparaissent pas.
- **La compréhension d'un exercice** (cercle, catégories, taux par question) : livrée, inchangée. Ses règles restent celles de l'ADR-0079.
- **Ce que voit l'élève de lui-même** : `progres-eleve`, `historique-eleve`, inchangés.
- **Ce que voit la direction** : inchangé, y compris ses « Anciens élèves ».
- **La fiche d'un élève parti ou anonymisé** : pas de fiche (404). Ses résultats restent lisibles par la direction (ADR-0036).
- **Un graphique, une courbe, un export** (PDF, tableur) de la fiche ou des rapports.
- **Une moyenne de l'élève toutes matières confondues** : elle mélange les exercices et cache le progrès (même raison que l'ADR-0079 pour écarter la moyenne).
- **Les notifications** à l'enseignant (WhatsApp, push) : V6.
- **Modifier, archiver une classe** (CL-02, CL-03) : chantier `vie-de-la-classe`.
- **Le retour du résultat d'une session vers la fiche** : la page de résultat garde son lien de retour vers la fiche essentielle (UDR-0023) ; l'enseignant revient par le bouton « retour » du navigateur.
- **Toute table ou migration nouvelle** : la fiche lit `classroom_students`, `classroom_assignments` et `exercise_sessions`, déjà indexées.

## Ce que le grill a révélé

> Grill fait sur l'inventaire du code (2026-10-16). Les décisions qui découlent des ADR acceptés sont prises ; les autres attendent le porteur. **Chaque question au porteur porte une recommandation** ; le PRD, l'ADR-0097 et les UDR sont écrits avec la recommandation, et seront amendés si la réponse diffère.

### Questions au porteur

| # | Question posée | Recommandation | Conséquence sur le chantier |
|---|---|---|---|
| **Q1** | AS-21, AS-25, l'essentiel d'AS-22, la part V3 de TR-05 (« Activités ») et de TR-32 (aucun cache) sont livrés. Les considère-t-on comme fermés ? | **Oui.** Le chantier ne garde que ce qui manque. | Ces features sont cochées au commit de clôture, avec renvoi à leur chantier. Le chantier passe de 8 features à 4 : CL-13/AS-24, la fin d'AS-22, CL-15, et AS-23 ou CL-14 selon Q6 et Q7. |
| **Q2** | Que montre la fiche d'un élève ? | **Deux sections.** (1) **Les exercices assignés à cette classe** : pour chacun, fait ou non, en retard ou non, meilleur score, catégorie, signe de progrès, nombre de sessions, et un lien vers sa meilleure session. (2) **Ce qu'il a fait seul** ces 30 derniers jours : titre, matière, score, date. Pas les sessions faites dans une autre classe. | Toutes les règles viennent de l'ADR-0079 (catégorie, signe) et de l'ADR-0089 (« fait seul »). L'enseignant passe de « Awa : 2 fait seul (7 j) » à la liste de ces exercices. Défaut de l'ancienne fiche corrigé : elle mélangeait les classes. |
| **Q3** | Quels badges sur la fiche : ceux de la table des badges (record de toutes les classes), ou ceux de ses meilleurs scores sur les exercices de cette classe ? | **Ceux de cette classe**, comptés par palier d'après son meilleur score sur chaque assignation, comme au bord bas de l'exercice (ADR-0079 §4.2). | Badge et couleur ne se contredisent jamais, sur la fiche comme sur la page de la classe. Coût : un élève qui a fait mieux ailleurs apparaît ici à son palier de la classe. |
| **Q4** | Les actions sur un élève (« Code de récupération », « Retirer de la classe ») restent-elles dans le menu ⋮ de chaque ligne, ou passent-elles sur la fiche ? | **Elles passent sur la fiche.** La ligne devient un seul lien vers la fiche. | Une action rare (UDR-0077 §3.4) coûte un geste de plus. En échange, chaque ligne perd son menu et sa fenêtre de confirmation, soit la plus grosse part du poids de la liste. Le retrait, lancé depuis la fiche, ramène à la page de la classe avec un message. Amende UDR-0077 §3.4 et UDR-0081 §3.7. |
| **Q5** | Comment paginer la liste des élèves (CL-15) ? | **30 élèves, puis « Voir les 30 suivants »** dans le cadre de la liste, sans numéros de page. La recherche porte toujours sur toute la classe. Sans JavaScript, le bouton est un lien qui affiche les 60 premiers. | La page de la classe repasse sous 150 Ko pour une classe de 55 élèves (à mesurer, avant et après). Les nouveaux restent en tête (UDR-0081 §3.7). Amende UDR-0027 et UDR-0054 §3.9. |
| **Q6** | Le message d'encouragement (AS-23) : le garde-t-on, et sous quelle forme ? | **Oui, sous la forme d'un « prochain geste »** : une phrase en haut de la section « Compréhension », choisie par une règle du domaine parmi six cas (personne n'a fait, lecture pas encore fiable, classe en difficulté, fragile, acquise avec des élèves en baisse, acquise). Pas de tirage au hasard, pas de variante par exercice, une seule phrase par cas, dans les locales. | Chaque lecture appelle un geste (mission, 2026-10-04). Une règle nommée dans le domaine (ADR-0097 §4.6), testée cas par cas. Si la réponse est non, le lot C se réduit aux liens vers la fiche. |
| **Q7** | Le tableau de bord de classe (CL-14) : ajoute-t-on des chiffres de classe à la page (% d'élèves actifs, moyenne, total des badges), ou la ferme-t-on comme livrée par la page de la classe ? | **La fermer.** Chaque exercice assigné porte déjà sa lecture. Une moyenne de classe mélangerait des exercices différents et cacherait le progrès. Et la page est déjà hors budget. | Aucun lot. CL-14 est cochée au commit de clôture, avec renvoi à CL-10 et à l'UDR-0072. |
| **Q8** | Peut-on mettre l'identifiant public de l'élève dans le HTML de la page de suivi ? L'UDR-0072 l'excluait (« aucun identifiant d'élève dans le HTML »), parce qu'il n'y avait pas de fiche. | **Oui.** Le `public_id` n'est pas un secret (ADR-0029), la page est gardée par sa policy, et la page de la classe l'expose déjà. | Les noms de la section « Compréhension », des rendus en retard et des « Pas encore faits » deviennent des liens vers la fiche. Amende UDR-0072 §3.5 et §3.5 bis. |

### Décisions alignées sur l'existant (pas de question)

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui lit la fiche ? | Ceux qui lisent la liste des élèves : `ReadClassroomPolicy` avec `show_roster` (enseignant de la classe, équipe). Refus : élève, enseignant d'une autre classe, direction, visiteur. | **Aucune policy nouvelle.** Tests de refus pour chacun. |
| Un élève parti, anonymisé, ou qui n'a jamais été dans la classe ? | **404**, comme une ligne absente de la liste. | La query ne lit que les adhésions présentes (`left_at IS NULL`, compte non anonymisé). |
| Une classe archivée ? | **404**, comme sa page (ADR-0088). | Même garde que `ClassroomsController#show`. |
| Quelles sessions comptent pour un exercice assigné ? | La définition de « fait » de l'ADR-0072 §4.4, remédiation comprise (ADR-0079 §4.1) : sessions terminées, rattachées à l'assignation. | Les chiffres de la fiche sont ceux de la page de suivi pour le même élève. Test croisé. |
| Le numéro de téléphone de l'élève ? | **Masqué**, comme sur la liste (ADR-0083 §4.4 bis). Le numéro complet ne quitte pas la query. | Test : aucun numéro complet dans le HTML. |
| Faut-il un cache ? | **Non**, lecture en direct (ADR-0079 §4.6, ADR-0067 : index, puis requête, puis cache par ADR). | Nombre de requêtes fixe, quel que soit le nombre d'exercices. Budget < 100 ms, < 150 Ko. |
| Dans quel ordre les exercices de la fiche ? | L'ordre de la page de la classe (échéance croissante, sans échéance à la fin, puis le plus récent). | L'enseignant retrouve le même ordre d'une page à l'autre. |

## Cas limites identifiés

- **Classe sans exercice assigné** : la section « Exercices de la classe » montre un état vide ; les badges sont tous à zéro.
- **Élève arrivé après l'échéance** d'un exercice : s'il le fait ensuite, il est « rendu en retard », car le retard se lit sur la date de la première session faite, comme sur la page de suivi (ADR-0072). La fiche reprend la règle telle quelle, sans exception pour les nouveaux.
- **Exercice fait une seule fois** : pas de signe, « 1 session ».
- **Exercice fait en remédiation seulement** : il est fait, avec son score (ADR-0079 §4.1).
- **Session commencée, jamais terminée** : l'exercice reste « pas encore fait ».
- **Élève qui a fait l'exercice depuis une autre classe** : cette session ne compte pas ici (sessions de l'assignation seulement).
- **Fait seul : aucune session en 30 jours** : la section affiche un état vide, pas « 0 ».
- **150 élèves** : 5 clics sur « Voir les 30 suivants » ; la recherche reste le chemin court.
- **Recherche + pagination** : une recherche repart des 30 premiers résultats.
- **Retrait depuis la fiche** (si Q4 = oui) : retour à la page de la classe avec le toast existant ; la fiche de l'élève retiré répond ensuite 404.
- **Équipe** : elle lit la fiche ; le retrait suit `ManageClassroomMembersPolicy`, inchangée.

## Questions encore ouvertes

- Q1 à Q8 ci-dessus, à trancher par le porteur avant le Lot 0.
- La fenêtre de 30 jours pour « fait seul » (Q2) est une première valeur ; elle n'aura qu'une définition dans le code.
- Le jeu de mesure de l'ADR-0067 sème-t-il assez de tentatives de questions pour mesurer la page de suivi ? (dette D4 de `rapports-exercices`) À vérifier au Lot 0 ; la fiche n'en lit pas.
