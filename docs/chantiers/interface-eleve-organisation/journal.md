# Journal — Organisation des écrans élève : accueil, « Ma classe » et rythme d'une session

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | Les « cours assignés » sont les cours qui contiennent un exercice assigné à la classe | Un cours ne s'assigne plus (ADR-0072) ; c'est la seule lecture qui ne soit pas toujours vide | Non : UDR-0076 §2.2, à confirmer par le porteur |
| 2026-10-05 | « Exercices assignés » ne garde que les exercices pas encore faits | Sinon un exercice fait serait dit deux fois sur la page (UDR-0057 R6) | Non : UDR-0076 §2.3, à confirmer par le porteur |
| 2026-10-05 | « Mes matières » sans case « Inviter » ni « Paiement » | Le code est déjà dans la carte « Ma classe », juste au-dessus ; le paiement n'existe pas | Non : memo, hors périmètre |
| 2026-10-05 | Session : aucun cache, la question suivante voyage avec le verdict | ADR-0076 : le coût est l'aller-retour, pas le calcul (2 à 9 ms) ; un 304 paie le même trajet ; ADR-0054 interdit tout fragment qui contiendrait une correction | Non : application de l'ADR-0076, UDR-0076 §3.3 |
| 2026-10-05 | « Question suivante » porte `data-turbo-prefetch="false"` | La question est déjà dans la page : le préchargement au survol de Turbo 8 coûterait une requête et 18 Ko pour rien | Non |
| 2026-10-05 | La bande des cours réutilise le contrôleur `communication--carousel` | Mêmes cibles, même comportement, sans nouveau JavaScript (budget de l'ADR-0051) | Non : UDR-0076 §4 le note |

## Mesures

Environnement de test, base locale, mêmes données des deux côtés : 3 matières, 9 exercices, 6 assignés, 5 terminés, 1 annonce, des exercices de 5 questions. Médiane de 25 requêtes. `Develop` = `08239e2c`.

| Mesure | Avant (`Develop`) | Après | Lecture |
|---|--:|--:|---|
| **Requêtes en série pour passer à la question suivante** | **2** (POST de la réponse, GET de la session) | **1** (POST de la réponse) | Un aller-retour de moins par question : 107 ms au point de mesure depuis le déménagement à Amsterdam, 227 ms avant (ADR-0076 §4.3) ; davantage en 3G |
| Octets reçus par question (verdict + question suivante) | 2 814 + 17 848 = 20 662 | 6 778 | −13,9 Ko par question : le stream porte la seule carte de la question, pas la page entière |
| Requêtes SQL par question | 27 + 11 = 38 | 27 | La question suivante était déjà lue par `SessionPlayQuery` pour le verdict : la joindre ne coûte aucune requête |
| `GET /students` : SQL · HTML · médiane | 20 · 49,7 Ko · 41,0 ms | 21 · 52,0 Ko · 41,4 ms | Une requête de plus (les matières), constante |
| `GET /students/classroom` : SQL · HTML · médiane | 9 · 18,9 Ko · 18,6 ms | 18 · 40,3 Ko · 34,2 ms | La page montre trois sections de plus. Nombre de requêtes fixe (test « une ou cinq »), sous les budgets de l'ADR-0067 (100 ms, 150 Ko), aucun frame différé : toujours 1 aller-retour |
| `Cache-Control` des quatre réponses | `private` | `private` | Aucun ETag ajouté, aucun fragment, aucun `fresh_when` (ADR-0076 §4.1) |

Le temps de test n'est pas celui de la production (journal SQL, pas d'eager load) : il est pessimiste et ne sert qu'à comparer.

**Preuve d'exécution de « aucune requête »** : `test/system/assessment/exercise_session_test.rb` lit le Resource Timing du navigateur avant et après « Question suivante ». Sans l'action Stimulus, le test échoue (2 requêtes attendues, 3 lues) ; avec, il passe.

## Ce qui a dérapé

- **La copie locale de `Develop` avait plusieurs jours de retard.** J'ai d'abord conclu que les annonces n'existaient pas, et posé la question au porteur, qui a répondu qu'elles étaient affichées après « À faire ». Un `git fetch` d'abord aurait évité la question. Tout le cadrage a été repris sur le `Develop` à jour.
- Le numéro d'UDR 0075 était pris par `feature/annonces-v2` (non fusionnée) : vérifié sur toutes les branches distantes avant de numéroter, d'où l'UDR-0076.

## Ce qu'on a appris sur la codebase

- `StudentHomeQuery#late_material_slugs` était déjà calculé pour une grille qui n'existait pas encore (UDR-0062 §3.3) : la pastille ambre l'utilise enfin.
- Les propositions de toutes les questions des fabriques s'appellent « Proposition 1 » à « Proposition 4 ». Dès qu'une réponse porte deux questions, un test anti-fuite qui cherche le texte d'une proposition juste devient ambigu : le test de soumission donne à la 2ᵉ question ses propres textes.
- `assert_select` imbriqué ne cherche que dans les descendants : un attribut posé sur l'élément du bloc se vérifie dans le sélecteur du bloc lui-même.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Famille téléphone de l'accueil (UDR-0058 §3.2) | Hors périmètre ; elle gardera l'ordre de l'UDR-0076 | `interface-epuree`, phase 2 |
| `communication--carousel` sert deux contextes | Le promouvoir en contrôleur partagé est un refactoring | à ouvrir si une troisième bande apparaît |
| « Ma classe » lit deux fois l'audience de l'élève (une par query) | Une requête de plus, constante ; la partager changerait la signature de `StudentHomeQuery` | — |
| `script/perf/count_round_trips.rb` ne joue pas une session | Il simule Turbo sans JavaScript : il ne verrait pas la question jointe. La preuve est le test système | — |
