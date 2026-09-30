# Journal — Le QR code d'enrôlement reste valable quand la page est rouverte

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-30 | Réutiliser le secret non confirmé plutôt que d'en tirer un par visite | Rend la page d'enrôlement idempotente : un `GET` ne doit pas invalider un QR déjà affiché | Non (pas architectural) |
| 2026-09-30 | Pas de durée de validité pour un secret non confirmé | Il n'est montré qu'à la session PIN de son titulaire, et la réinitialisation le supprime ; une expiration demanderait une règle nouvelle, donc une feature | Non |

## Ce qui a dérapé

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

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| En 422, le QR réaffiché vient du secret **envoyé par le navigateur** (`submitted_enrollment`), pas de la base | Correct une fois la cause corrigée ; lire la base en 422 change le contrat du contrôleur | à ouvrir (`refactor`) |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
