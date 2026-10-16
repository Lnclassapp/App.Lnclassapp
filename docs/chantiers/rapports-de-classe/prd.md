# PRD — Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **Écrit avec les recommandations du memo (Q1 à Q8).** Une réponse du porteur qui diffère amende ce fichier avant le Lot 0 ; les scénarios concernés portent le numéro de leur question.

## 1. Contexte

L'enseignant lit chaque exercice assigné de sa classe (`rapports-exercices`), mais ne peut pas regarder un élève : aucun nom ne mène à une fiche. Ce chantier ajoute la **fiche d'un élève dans sa classe** (CL-13, AS-24), y mène depuis la page de la classe et la page de suivi (fin d'AS-22), pagine la liste des élèves (CL-15) et termine la section « Compréhension » par une phrase « prochain geste » (AS-23). Voir le [memo](memo.md), dont l'inventaire ferme AS-21, AS-25, CL-14 et les parts V3 de TR-05 et TR-32.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher (enseignant de la classe) | Ouvrir la fiche d'un élève présent de sa classe ; ouvrir le résultat de ses sessions ; lui donner un code de récupération et le retirer de la classe depuis la fiche (Q4) ; voir le prochain geste sur la page de suivi | Ouvrir la fiche d'un élève d'une classe où il n'enseigne pas, d'un élève parti ou anonymisé |
| Team | Pareil, sur toute classe active | Ouvrir la fiche d'un élève parti ou anonymisé |
| Student | — | Ouvrir la fiche d'un élève, la sienne comprise (il a ses pages) |
| SchoolStaff (direction) | — (inchangé : son espace, ADR-0065) | Ouvrir la fiche |
| Visiteur | — | Tout (redirigé vers la connexion) |

**Règles d'autorisation, toutes existantes** :
- fiche : `Policies::Classroom::ReadClassroomPolicy`, accès avec `show_roster` (ADR-0097 §4.2) ;
- actions de la fiche : `Policies::Identity::IssuePinRecoveryCodePolicy` et `Policies::Classroom::ManageClassroomMembersPolicy`, inchangées ;
- page de suivi : `Policies::Classroom::FollowAssignmentPolicy`, inchangée.

## 3. Parcours utilisateur

### Chemin nominal

1. L'enseignant ouvre la page de sa classe. La liste « Élèves » montre les 30 premiers (les nouveaux en tête), puis « Voir les 30 suivants ».
2. Il touche le nom d'Awa : sa **fiche** s'ouvre (`/classrooms/:classroom_public_id/students/:student_public_id`).
3. En tête : sa photo, son nom, la classe, son numéro masqué, son arrivée. Dessous, trois chiffres sur les exercices de la classe (« Faits 7 sur 10 · En retard 1 · Pas encore faits 3 ») et ses badges de la classe par palier.
4. La section **« Exercices de la classe »** liste les exercices assignés, dans l'ordre de la page de la classe. Pour chacun : matière, échéance, et soit « Pas encore fait », soit son meilleur score, sa catégorie (« Fragile »), son signe (« ↗ En progrès »), « 3 sessions » et un lien « Voir la meilleure session ».
5. La section **« Fait seul · 30 derniers jours »** liste ce qu'Awa a fait sans assignation : titre, matière, score, date, avec un lien vers le résultat.
6. En bas, **« Gérer »** : « Code de récupération » et « Retirer de la classe » (Q4).
7. Sur la page de suivi d'un exercice, chaque nom (catégorie, rendus en retard, pas encore faits) mène à la fiche de l'élève. En haut de la section « Compréhension », une phrase dit le **prochain geste** (Q6).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Classe sans exercice assigné | Chiffres « 0 sur 0 » ; section « Exercices de la classe » en état vide « Aucun exercice assigné à la classe. » ; badges tous à zéro, atténués |
| Aucun « fait seul » en 30 jours | État vide « Aucun exercice fait seul ces 30 derniers jours. » |
| Exercice fait une seule fois | Pas de signe ; « 1 session » |
| Exercice non fait, échéance passée | « Pas encore fait » avec l'échéance passée en ambre (UDR-0062) |
| Élève parti, anonymisé, ou d'une autre classe | 404 |
| Élève ou classe inconnus | 404 |
| Classe archivée | 404, comme sa page (ADR-0088) |
| Élève, enseignant d'une autre classe, direction | 403 |
| Retrait depuis la fiche (Q4) | Retour à la page de la classe, toast existant « Awa Bamba a été retiré de la classe. » ; la fiche répond ensuite 404 |
| `page` absent, nul, négatif ou non numérique | Première page |
| `page` au-delà de la fin | Toute la liste, sans bouton « Voir les suivants » |
| Recherche | Repart de la première page ; « Voir les suivants » garde la recherche |
| Personne n'a fait l'exercice (page de suivi) | Pas de prochain geste : l'état vide existant suffit |

## 4. Critères d'acceptation

Chacun devient un test. « Fait », « en retard », « présent » : ADR-0072 §4.4, remédiation comprise (ADR-0079 §4.1).

### Fiche d'un élève (Lot A)

```gherkin
Scénario: l'enseignant ouvre la fiche d'un élève de sa classe
  Étant donné l'enseignant de la 3ème B et Awa Bamba, élève présente de la 3ème B
  Quand il ouvre la fiche d'Awa dans la 3ème B
  Alors il voit son nom, la classe et son numéro masqué « 07 •• •• •• 04 »
  Et le numéro complet n'apparaît nulle part dans la page

Scénario: les exercices de la classe et leur état
  Étant donné 3 exercices assignés à la 3ème B, échéances passées
  Et Awa a fait le premier à l'heure (30 puis 90), le deuxième en retard (60), pas le troisième
  Quand l'enseignant ouvre sa fiche
  Alors les chiffres sont « Faits 2 sur 3 », « En retard 1 », « Pas encore faits 1 »
  Et le premier montre 90 %, « Acquis », « En progrès », « 2 sessions » et « Voir la meilleure session »
  Et le deuxième montre 60 %, « Fragile », « Rendu en retard le … » et « 1 session », sans signe
  Et le troisième montre « Pas encore fait » et son échéance passée

Scénario: seules les sessions de l'assignation comptent
  Étant donné qu'Awa a fait l'exercice X à 100 depuis une autre classe
  Et l'exercice X est assigné à la 3ème B, où Awa ne l'a pas fait
  Quand l'enseignant ouvre sa fiche dans la 3ème B
  Alors X est « Pas encore fait »

Scénario: une remédiation sur l'exercice assigné, c'est l'avoir fait
  Étant donné qu'Awa a fait l'exercice assigné à 25 puis en remédiation, rattachée à l'assignation, à 75
  Alors la fiche montre 75 %, « Acquis », « En progrès », « 2 sessions »

Scénario: mêmes chiffres que la page de suivi
  Étant donné un exercice assigné qu'Awa a rendu en retard avec un meilleur score de 65
  Alors la page de suivi la compte « en retard » et la classe « Fragile »
  Et sa fiche dit la même chose pour cet exercice

Scénario: badges de la classe (Q3)
  Étant donné qu'Awa a pour meilleurs scores 100, 85, 72 et 40 sur 4 exercices de la classe
  Et un badge Diamant obtenu sur un exercice d'une autre classe
  Alors la fiche montre 1 Diamant, 1 Or, 1 Argent, 0 Bronze

Scénario: fait seul sur 30 jours (Q2)
  Étant donné qu'Awa a terminé une session sans assignation il y a 3 jours et une il y a 31 jours
  Et une session sans assignation commencée, non terminée
  Quand l'enseignant ouvre sa fiche
  Alors la section « Fait seul » montre la seule session d'il y a 3 jours, avec son score et un lien vers son résultat

Scénario: l'enseignant ouvre le résultat d'une session depuis la fiche
  Quand il touche « Voir la meilleure session »
  Alors la page de résultat de cette session s'ouvre (ReadSessionPolicy, inchangée)

Scénario: refus
  Quand un élève de la classe, un enseignant d'une autre classe ou la direction ouvre la fiche
  Alors il reçoit 403
  Et un visiteur est renvoyé vers la connexion

Scénario: introuvable
  Étant donné un élève parti de la classe, un élève anonymisé, un élève d'une autre classe
  Quand l'enseignant ouvre leur fiche dans la 3ème B
  Alors il reçoit 404
  Et la fiche d'un élève dans une classe archivée répond 404

Scénario: l'équipe lit la fiche
  Quand un membre de l'équipe ouvre la fiche d'Awa
  Alors il la voit, sans jours de séance ni matière propre

Scénario: actions depuis la fiche (Q4)
  Quand l'enseignant touche « Code de récupération » sur la fiche d'Awa
  Alors un code est émis, comme depuis l'ancien menu de la ligne
  Quand il confirme « Retirer de la classe »
  Alors il revient à la page de la classe avec le toast de retrait
  Et Awa n'est plus dans la liste

Scénario: budget
  Étant donné le jeu de mesure de l'ADR-0067 et un élève à 10 exercices assignés
  Alors la fiche reste sous 100 ms p95 serveur et 150 Ko de HTML
  Et son nombre de requêtes ne dépend pas du nombre d'exercices assignés
```

### Page de la classe : liste des élèves (Lot B)

```gherkin
Scénario: le nom mène à la fiche
  Quand l'enseignant touche le nom d'un élève dans la liste
  Alors la fiche de cet élève s'ouvre

Scénario: la ligne n'a plus de menu (Q4)
  Alors aucune ligne de la liste n'a de menu ⋮ ni de fenêtre de retrait

Scénario: 30 élèves par page (Q5)
  Étant donné une classe de 65 élèves présents
  Quand l'enseignant ouvre la page de la classe
  Alors la liste montre 30 élèves et « 30 sur 65 »
  Et « Voir les 30 suivants » ajoute les 30 suivants sans recharger la page
  Et après 65, le bouton disparaît

Scénario: les nouveaux restent en tête
  Étant donné 2 élèves arrivés il y a 3 jours dans une classe de 65
  Alors ils sont les deux premiers de la première page

Scénario: recherche et pagination
  Étant donné 40 élèves dont le nom contient « kon »
  Quand l'enseignant cherche « kon »
  Alors la liste montre les 30 premiers et « 30 sur 40 »
  Et « Voir les 10 suivants » garde la recherche

Scénario: sans JavaScript
  Quand « Voir les 30 suivants » est suivi comme un lien
  Alors la page de la classe s'affiche avec les 60 premiers élèves

Scénario: paramètre de page invalide
  Quand la page de la classe est ouverte avec page=-1, page=abc ou page=0
  Alors la liste montre la première page

Scénario: budget
  Étant donné la classe mesurée par rapports-exercices (55 élèves, 7 exercices)
  Alors la page de la classe pèse moins de 150 Ko de HTML
  Et la mesure avant et après est consignée au journal
```

### Page de suivi : noms en liens et prochain geste (Lot C)

```gherkin
Scénario: les noms mènent à la fiche (Q8)
  Quand l'enseignant ouvre la page de suivi
  Alors chaque nom de la section « Compréhension », des rendus en retard et des « Pas encore faits » mène à la fiche de l'élève dans cette classe
  Et un nom choisi dans une catégorie ouvre la fiche en page entière, pas dans le cadre des catégories
  Mais sur la page de suivi d'une classe archivée, les noms ne sont pas des liens (la fiche y répond 404)

Scénario: prochain geste, lecture pas encore fiable (Q6)
  Étant donné 3 élèves qui ont fait l'exercice sur 25 présents
  Alors le prochain geste est « Relancez les 22 élèves qui ne l'ont pas encore fait : la lecture de la classe sera fiable à partir de 5. »

Scénario: prochain geste, petite classe qui a tout fait
  Étant donné une classe de 4 élèves présents qui ont tous fait l'exercice
  Alors le prochain geste est « Tous les élèves l'ont fait. La classe est trop petite pour une tendance : regardez chaque élève. »

Scénario: prochain geste, classe en difficulté
  Étant donné une lecture fiable dont la catégorie dominante est « En difficulté »
  Alors le prochain geste est « La plupart des élèves sont en difficulté : reprenez la notion avant d'avancer. »

Scénario: prochain geste, classe fragile
  Étant donné une lecture fiable dont la catégorie dominante est « Fragile »
  Alors le prochain geste est « La notion se met en place : reprenez en classe les questions marquées, puis avancez. »

Scénario: prochain geste, classe acquise avec des élèves en baisse
  Étant donné une lecture fiable, dominante « Acquis », et 2 élèves en baisse
  Alors le prochain geste est « La classe a compris. 2 élèves sont en baisse : voyez-les dans leur catégorie. »

Scénario: prochain geste, classe acquise
  Étant donné une lecture fiable, dominante « Acquis », aucun élève en baisse
  Alors le prochain geste est « La classe a compris : vous pouvez avancer. »

Scénario: rien quand personne n'a fait l'exercice
  Étant donné qu'aucun élève n'a fait l'exercice
  Alors aucun prochain geste n'est affiché, seulement l'état vide existant

Scénario: même phrase à chaque visite
  Étant donné la même lecture de la classe
  Alors le prochain geste est le même, quel que soit l'exercice
```

### Non-régression

```gherkin
Scénario: les lectures existantes ne bougent pas
  Alors les comptes, le cercle, les badges et la section « Compréhension » sont inchangés sur la page de la classe et la page de suivi
  Et la recherche d'un élève et le retrait par la direction fonctionnent comme avant
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::NextStep` (règle pure : `for(done:, pending:, readable:, dominant:, decline:)` → nil ou un symbole parmi six, ADR-0097 §4.6). Aucun port, aucun use case : lecture seule (CQRS, ADR-0026) |
| Infrastructure | `Queries::Classroom::StudentFileQuery` (fiche : en-tête, exercices de la classe, badges, fait seul sur `SELF_PRACTICE_DAYS = 30` jours, ADR-0097 §4.4 ; nombre de requêtes fixe ; réutilise `AssignmentScores`, `AssignmentFollowUpQuery.first_done` et `Comprehension`) ; `ClassroomOverviewQuery` gagne `page` et `students_total` (ADR-0097 §4.5) ; `ComprehensionDetailQuery::StudentRow`, `AssignmentFollowUpQuery::LateStudent` et `PendingStudent` gagnent `public_id`. **Aucune migration** |
| Delivery | Route GET `classrooms/:classroom_public_id/students/:student_public_id` → `classroom/classroom_students#show` (même chemin que le DELETE existant) ; `ClassroomStudentsController#show` ; `#destroy` répond par une redirection 303 vers la page de la classe quand le formulaire de la fiche passe `origin=file` (Q4) ; `ClassroomsController#show` lit `page` |
| UI | `classroom/classroom_students/show.html.erb` et ses partials (UDR-0107) ; `_roster.html.erb` amendé (UDR-0108) ; `assessment/comprehension/_section.html.erb` et `assignment_follow_ups/show.html.erb` amendés (UDR-0109) ; locales `classroom.classroom_students.*`, `classroom.classrooms.roster.*`, `assessment.comprehension.next_step.*` |

## 6. Décisions rattachées

- [ADR-0097](../../decisions/adr/0097-fiche-d-un-eleve-dans-sa-classe.md) (Proposé) — ce que lit la fiche, qui la lit, la pagination de la liste, la règle du prochain geste.
- [UDR-0107](../../decisions/udr/0107-fiche-d-un-eleve-dans-sa-classe.md) (Proposé) — la fiche d'un élève.
- [UDR-0108](../../decisions/udr/0108-liste-des-eleves-en-liens-et-par-trente.md) (Proposé) — la liste des élèves de la page de la classe ; amende UDR-0027, UDR-0054 §3.9, UDR-0077 §3.4, UDR-0081 §3.7.
- [UDR-0109](../../decisions/udr/0109-suivi-noms-en-liens-et-prochain-geste.md) (Proposé) — la page de suivi ; amende UDR-0072 §3.5 et §3.5 bis.
- Inchangés et suivis : ADR-0033 (seuils, badges), ADR-0072 (« fait », retard), ADR-0079 (catégorie, signe, lecture), ADR-0083 §4.4 bis (numéro masqué), ADR-0088 (classe archivée), ADR-0089 (« fait seul »), ADR-0067 (budgets).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Page de la classe, 55 élèves et 7 exercices (jeu ADR-0067) : HTML | 231,6 Ko (`rapports-exercices`) ; à re-mesurer au Lot B | < 150 Ko | |
| Page de la classe : p95 serveur | 153,4 ms ; à re-mesurer au Lot B | < 100 ms visé ; au moins pas pire | |
| Fiche d'un élève, 10 exercices assignés : p95 / HTML | — | < 100 ms / < 150 Ko | |
| Requêtes SQL de la fiche à 1 et à 10 exercices | — | même nombre | |
| Page de suivi : p95 / HTML | 78,9 ms / 39,0 Ko | < 100 ms / < 150 Ko | |
| Téléphone 390 px : fiche, page de la classe, suivi | — | aucun défilement horizontal | |
