# Journal — Les tests « aucun id révélé » des questions à relier et à ordonner échouent sans fuite

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Les tests forcent des ids bas plutôt que de les éviter | Le pire cas joué à chaque passage : un test d'absence de fuite doit tenir quand l'id ressemble à tout | non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. **Chaîne** : `setup` crée les réponses (`create_kind_question` → `Orm::Answer`, ids tirés de `answers_id_seq`, non remise à zéro entre les tests) → `get exercise_session_path` rend la question (`select` dont les options valent les indices d'affichage `0..n-1`, chemins SVG des icônes, « Question 1 sur 2 ») → le test compare les ids à **tout** nombre de la page.
2. **Cause** : `test/integration/assessment/question_matching_test.rb:96` et `question_ordering_test.rb:89` cherchent l'id comme un mot dans le HTML entier (`/\b#{id}\b/`) ; `question_matching_test.rb:36-37` et `question_ordering_test.rb:36-38` comparent les ids aux valeurs des attributs `value` et `data-index`, qui sont aussi des indices d'affichage. Un id de 1 à 3, ou égal à un nombre du texte, passe pour une fuite.
3. **Pourquoi rien ne l'a vu** : en local, les ids du fichier joué seul sont grands, ou du moins différents des nombres de la page. Ils ne sont petits que selon l'ordre des tests du processus (graine aléatoire, partage entre workers), d'où un rouge rare, jamais reproduit en rejouant le fichier.

En une phrase sans les mots du symptôme : les deux tests prennent pour un identifiant tout entier de la page, alors que la page contient légitimement des petits entiers.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |
