# Plan d'exécution — Une classe s'inscrit ensemble depuis le wifi de l'école

## Lot A — Un débit propre au lien de classe

- **Couche**       : delivery
- **Fichiers**     : `app/controllers/classroom/joins_controller.rb` · `app/controllers/classroom/student_registrations_controller.rb`
                     (et tout contrôleur qui partage `LINK_RATE_LIMIT` pour le seul lien : `student_classroom_changes_controller.rb` s'il compte le lien)
                     `test/controllers/classroom/joins_controller_test.rb` · `test/controllers/classroom/student_registrations_controller_test.rb`
                     `docs/decisions/adr/0085-inscription-eleve-sans-code-de-classe.md` (amendement déjà écrit)
- **Dépend de**    : —
- **Test associé** : « 45 élèves d'une même adresse ouvrent le lien de la classe et s'inscrivent dans la minute : 45 comptes, aucun 429 » ; « le 61e envoi par lien dans la minute depuis la même adresse reçoit 429 » ; les tests existants du débit par code et de la voie standard restent tels quels (cas symétrique).
- **Done quand**   : une classe de 45 s'inscrit par son lien depuis une adresse sans 429 ; la voie standard et la vérification de code gardent 10 et 5 par minute et par adresse.

### Contrat d'exécution

1. Écrire les tests de reproduction (contrôleur), les lancer : **rouges** (429 au 11e lien / 6e inscription).
2. Correctif : `CLASS_LINK_RATE_LIMIT = { to: 60, within: 1.minute, scope: "classroom/links" }` par adresse, sur `GET/POST /c/:token` à la place de `LINK_RATE_LIMIT`, et sur `POST /student-signup` **quand l'envoi porte un jeton de lien valide en forme** (12 hex) — alors seul ce débit s'applique ; sans jeton, les deux débits actuels (10 partagé, 5 « signup ») restent.
3. Vert ; suite `test/controllers/classroom` et `test/system/classroom` au vert.
