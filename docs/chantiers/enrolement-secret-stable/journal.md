# Journal — Le QR code d'enrôlement reste valable quand la page est rouverte

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | Réutiliser le secret non confirmé plutôt que d'en tirer un par visite | Rend la page d'enrôlement idempotente : un `GET` ne doit pas invalider un QR déjà affiché | Non (pas architectural) |
| 2026-09-30 | Pas de durée de validité pour un secret non confirmé | Il n'est montré qu'à la session PIN de son titulaire, et la réinitialisation le supprime ; une expiration demanderait une règle nouvelle, donc une feature | Non |

## Ce qui a dérapé

- Le cadrage affirmait qu'« aucun document » ne décrivait le remplacement du secret. C'était faux : le commentaire du port (`second_factor_repository_port.rb:15`, « Remplace un secret non confirmé. ») le décrivait. Vu à l'exécution, quand le correctif a rendu ce commentaire mensonger. Il datait du socle (`94368383`), sans ADR : description de l'implémentation, pas décision. Corrigé dans le même commit ; memo rectifié. Leçon : au cadrage d'un bugfix, lire le **port** de la méthode fautive, pas seulement l'ADR et les tests.
- L'enquête est partie d'un « Code incorrect. » à la **vérification** sur Develop (compte déjà enrôlé). Ce chantier ne corrige pas ce cas : il supprime la cause la plus probable des entrées fantômes dans l'application d'authentification, qui y mènent.

## Ce qu'on a appris sur la codebase

**Rapport de root cause**

1. **Chaîne d'appels**
   `GET /identity/second-factor/enrollment/new`
   → `Identity::SecondFactorEnrollmentsController#new` (`second_factor_enrollments_controller.rb:14`)
   → `UseCases::Identity::BeginSecondFactorEnrollment#call` (`begin_second_factor_enrollment.rb:19`)
   → `Repositories::Identity::SecondFactorRepository#begin_enrollment` (`second_factor_repository.rb:20`).
   Puis `POST /identity/second-factor/enrollment` → `#create` → `ConfirmSecondFactorEnrollment#call` → `SecondFactorRepository#verify_code` (`confirm_second_factor_enrollment.rb:27`), qui vérifie contre le secret **en base**.

2. **Fichier et ligne fautifs** : `app/infrastructure/repositories/identity/second_factor_repository.rb:21-23`. `begin_enrollment` tire un secret neuf (`ROTP::Base32.random`), **supprime** la ligne non confirmée et en crée une autre, à chaque appel. Comme il est appelé par une action `GET`, chaque affichage de la page invalide le QR code affiché auparavant.
   Aggravant : en 422, `submitted_enrollment` (`second_factor_enrollments_controller.rb:44`) réaffiche le secret renvoyé par le formulaire, donc l'ancien. L'utilisateur reste bloqué sur un QR périmé.

3. **Pourquoi aucun test ne l'a vu** : le test d'infrastructure `begin_enrollment replaces an unconfirmed secret` (ajouté avec le repository, `7ae42d45`) **exige** ce remplacement, sans qu'aucun document ne le décide ; et tous les tests du contrôleur ouvrent la page **une seule fois** avant d'envoyer le code. Aucun test ne combinait deux affichages et une confirmation. Le test de reproduction se place donc au repository (niveau de la cause), doublé d'un test contrôleur qui rejoue le parcours.

**Cause en une phrase, sans les mots du symptôme** : une lecture HTTP (`GET`) réécrit l'état persistant qu'une requête ultérieure utilise pour valider.

- Aucun lien de l'app ne pointe vers la page d'enrôlement (seulement des redirections, depuis `Authentication` et `SecondFactorsController`). Les doubles `GET` des logs viennent de rechargements, d'onglets multiples ou de redirections successives.

## Preuve (phase 5)

- **Test de reproduction** : rouge avant le correctif, pour la bonne raison — secrets différents (`second_factor_repository_test.rb`), `422` avec le premier QR (`second_factor_enrollments_controller_test.rb`), secret écrit en premier écrasé (test de course). Vert après.
- **Portes locales** (la CI GitHub est à l'arrêt, quota épuisé, chantier `ci-quota`) : suite `identity` 670 runs verts ; suite unitaire complète 2557 runs, couverture 100 % lignes et branches ; rubocop, Brakeman, gardes verts.
- **Challenger** (rôle distinct, application lancée en local, HTTP réel) — 6 scénarios, tous verts :
  1. Reproduction : deux ouvertures → même secret ; le code du premier onglet active le second facteur (10 codes de secours, une ligne confirmée).
  2. Symétrique : une ouverture, bon code → activé.
  3. Mauvais code → `422` « Code incorrect. », même secret réaffiché, puis bon code → activé.
  4. Réinitialisation puis réenrôlement → nouveau secret, qui fonctionne.
  5. Compte déjà enrôlé → redirection, le secret confirmé n'est jamais affiché.
  6. 8 ouvertures en parallèle → 8 × `200`, un seul secret, une ligne ; le chemin de course (insertion refusée puis relecture) s'est réellement exécuté.
  Test de course plus dur au repository : 8 fils synchronisés, 40 tours, 70 insertions refusées, 0 erreur, 0 secret divergent, y compris dans une transaction englobante.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| En 422, le QR réaffiché vient du secret **envoyé par le navigateur** (`submitted_enrollment`), pas de la base | Correct une fois la cause corrigée ; la vérification se fait toujours contre la base, l'affichage seul est concerné ; lire la base en 422 change le contrat du contrôleur | à ouvrir (`refactor`) |
| Un autre onglet confirme **entre** `leave_when_enrolled` et `begin_enrollment` → `RecordNotUnique` non rattrapée (500) | Fenêtre de quelques millisecondes, comportement identique avant le correctif, non déclenché en HTTP par le challenger | à ouvrir si observé |

## Clôture

| | |
|---|---|
| **Livré le** | *(à la fusion)* |
| **PR** | [#108](https://github.com/Lnclassapp/App.Lnclassapp/pull/108), vers `Develop` |
| **ADR produits** | — |
| **UDR produits** | — |
