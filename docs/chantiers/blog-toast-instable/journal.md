# Journal — Le toast « Article créé » arrive parfois après la fin de l'attente du test

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Le délai des scripts asynchrones du fichier passe aussi à `UPLOAD_WAIT` | Pendant la reproduction, `drop_generated_image` a dépassé son délai (1 passage sur 2 sous charge) : Capybara donne à `evaluate_async_script` l'attente par défaut, 2 s (`capybara/selenium/driver.rb:137`), pour dessiner et compresser une image de 2000×1500. Même cause que le toast (un travail lourd jugé à 2 s), même fichier, même correctif : il entre dans le chantier | non |

## Ce qui a dérapé

- Une seconde instabilité, de même cause, est apparue pendant la reproduction (voir la décision). Reproduite à la demande par un processeur ralenti ×8, puis corrigée.

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. **Chaîne** : `hold_uploads` retient l'envoi de l'image → « Créer le brouillon » attend (l. 142-144) → `release.call` (l. 145) → le serveur traite l'image, le navigateur soumet alors le formulaire, le serveur crée l'article et répond le toast → `assert_toast` (l. 148, `test/support/turbo_assertions.rb:21`) l'attend **2 s**.
2. **Cause** : `test/system/teams/blog_management_test.rb:148` (et `test/system/assessment/question_image_test.rb:66`) attend avec le délai par défaut une réponse qui enchaîne deux requêtes, dont un traitement d'image. Toutes les autres assertions d'après envoi du fichier prennent `wait: UPLOAD_WAIT` ; celle-ci, sortie du bloc, l'a oublié.
3. **Pourquoi rien ne l'a vu** : seul, le test tient en moins de 2 s ; sous la charge de la suite parallèle, rarement non.

En une phrase sans les mots du symptôme : une assertion attend une réponse en deux requêtes avec le délai prévu pour une seule.

**Seconde cause, même famille** : `drop_generated_image` et `image_loaded?` (`evaluate_async_script`) héritent de Capybara un délai de script de 2 s ; dessiner une image de 2000×1500 pendant qu'une autre est réduite dans la page le dépasse sous charge (`ScriptTimeoutError`).

**Trou de test comblé** : tout ce qui suit un envoi ou traite une image attend `UPLOAD_WAIT` (20 s) ; une absence réelle de toast échoue toujours (vérifié). Le test ne ralentit pas : l'attente ne dure que jusqu'à la réponse.

**Effets de bord écartés** : `using_wait_time` ne vaut que pour son bloc ; aucune autre assertion du fichier ne change d'attente.

**À retenir** : dans Capybara, l'attente par défaut sert aussi de délai aux scripts asynchrones ; un script qui travaille (canvas, décodage) prend son propre délai.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |
