# Journal — Le toast « Article créé » arrive parfois après la fin de l'attente du test

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. **Chaîne** : `hold_uploads` retient l'envoi de l'image → « Créer le brouillon » attend (l. 142-144) → `release.call` (l. 145) → le serveur traite l'image, le navigateur soumet alors le formulaire, le serveur crée l'article et répond le toast → `assert_toast` (l. 148, `test/support/turbo_assertions.rb:21`) l'attend **2 s**.
2. **Cause** : `test/system/teams/blog_management_test.rb:148` (et `test/system/assessment/question_image_test.rb:66`) attend avec le délai par défaut une réponse qui enchaîne deux requêtes, dont un traitement d'image. Toutes les autres assertions d'après envoi du fichier prennent `wait: UPLOAD_WAIT` ; celle-ci, sortie du bloc, l'a oublié.
3. **Pourquoi rien ne l'a vu** : seul, le test tient en moins de 2 s ; sous la charge de la suite parallèle, rarement non.

En une phrase sans les mots du symptôme : une assertion attend une réponse en deux requêtes avec le délai prévu pour une seule.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |
