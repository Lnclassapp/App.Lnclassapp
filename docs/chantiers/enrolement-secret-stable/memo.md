# Memo — Le QR code d'enrôlement reste valable quand la page est rouverte

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours — correctif prouvé, PR #108 en revue |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `fix/enrolement-secret-stable` |
| **Programme** | — |

---

## Symptôme

Un membre de l'équipe scanne le QR code d'activation du second facteur, saisit le code à 6 chiffres de son application d'authentification et obtient **« Code incorrect. »**. La page réaffiche **le même QR code** : chaque nouvel essai avec ce QR échoue à nouveau. Son application garde une entrée « Lnclass » qui ne fonctionnera jamais.

Constaté sur l'environnement Develop le 2026-09-29 (18:49–19:33) : ouvertures quasi simultanées de la page d'enrôlement, puis plusieurs envois refusés avant un succès.

## Comportement attendu et source

Le QR code affiché est celui du secret enregistré, tant que l'enrôlement n'est pas confirmé :

- `app/controllers/identity/second_factor_enrollments_controller.rb:43` — « Le formulaire re-rendu en 422 remontre le même QR code : le secret enregistré n'a pas changé. »
- `test/controllers/identity/second_factor_enrollments_controller_test.rb` — « a wrong code re-renders the same QR code in 422 ».
- ADR-0031, parcours §1 : la page d'activation montre le QR code à lire, puis le premier code l'active.

L'ADR-0031 ne décide nulle part qu'un secret non confirmé est remplacé à chaque visite. Deux traces le décrivent, sans le justifier : le commentaire du port (« Remplace un secret non confirmé. », socle `identity`, `94368383`) et le test d'infrastructure `begin_enrollment replaces an unconfirmed secret` (`7ae42d45`), écrits le même jour que l'implémentation. Ils la décrivent, ils ne tranchent rien. Ce chantier les aligne sur l'invariant du parcours ; la signature du port ne change pas.

## Reproduction

Rejouée le 2026-09-30 sur l'application lancée en local (`bin/rails server`, base de développement) :

1. Compte `team` sans second facteur (contact `0700000099`, PIN `2468`), aucune ligne `totp_credentials`.
2. Connexion par contact et PIN → redirection vers `/identity/second-factor/enrollment/new`.
3. **Onglet 1** : la page affiche le secret `LDORGJ…` et son QR code.
4. **Onglet 2** (ou rechargement de la page) : la page affiche un autre secret, `5Q46DL…`.
5. Dans l'onglet 1, saisir le code courant du secret `LDORGJ…` (celui du QR scanné).
6. **Obtenu** : `422`, « Code incorrect. », et la page réaffiche `LDORGJ…`. **Attendu** : le second facteur est activé et les codes de secours s'affichent.

## Portée

- **Depuis** : la création du repository (2026-09-25, `7ae42d45`). Le bug n'est pas une régression : il est présent depuis l'origine.
- **Acteurs touchés** : les comptes `team` à l'enrôlement, soit le premier enrôlement, soit le réenrôlement après une réinitialisation (ADR-0031, « Perte du téléphone »). Enseignants, élèves, parents et direction n'ont pas de second facteur : non concernés.
- **Multi-appartenance** : sans objet (le second facteur est lié au compte, pas aux classes ni aux écoles).
- **Données corrompues** : **non**. Un secret non confirmé est transitoire ; un secret confirmé est, par construction, celui dont l'utilisateur a saisi un code juste. Les entrées fantômes restent dans les téléphones, hors de la base : rien à réparer côté serveur.

## Hors périmètre

- Le formulaire en 422 réaffiche le secret **renvoyé par le navigateur** plutôt que celui de la base (`submitted_enrollment`). Une fois la cause corrigée, les deux coïncident ; revoir cette confiance fait l'objet d'un suivi (`journal.md`), pas de ce chantier.
- Une durée de validité pour un secret non confirmé.
- Toute modification de la vérification (`VerifySecondFactor`) ou de l'interface.

## Décision

Un secret **non confirmé** est **réutilisé** tant qu'il existe : rouvrir la page d'enrôlement montre le même QR code. Un nouveau secret n'est tiré que s'il n'en existe aucun, c'est-à-dire au premier enrôlement ou après une réinitialisation (qui supprime la ligne). Un secret confirmé n'est jamais renvoyé ni remplacé : le comportement actuel est conservé.

Ni ADR (la cause n'est pas architecturale : un repository ne respecte pas l'invariant de son appelant) ni UDR (l'écran ne change pas).

## Cas limites identifiés

- Deux ouvertures **simultanées** sans secret existant : les deux tentent l'insertion, l'index unique sur `user_id` refuse la seconde. Elle doit relire le secret créé par la première, pas lever une erreur 500.
- Secret déjà confirmé : `begin_enrollment` doit toujours lever (test `a confirmed secret is never replaced`) et **ne jamais renvoyer** le secret confirmé.
- Réinitialisation entre deux visites : la ligne est supprimée, la visite suivante tire un nouveau secret.

## Portes de sortie (lot unique)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Lot unique — Un secret non confirmé survit à la réouverture de la page

- **Couche**       : infrastructure (+ test contrôleur)
- **Fichiers**     : `app/infrastructure/repositories/identity/second_factor_repository.rb`
                     `test/infrastructure/repositories/identity/second_factor_repository_test.rb`
                     `test/controllers/identity/second_factor_enrollments_controller_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/repositories/identity/second_factor_repository_test.rb`
- **Done quand**   : ouvrir deux fois la page d'enrôlement puis saisir le code du premier QR active le second facteur

**Contrat d'exécution** (ordre imposé, sans exception) :

1. Réécrire `begin_enrollment replaces an unconfirmed secret` en **`begin_enrollment keeps the unconfirmed secret`** (deux appels → même secret, une seule ligne). Ajouter au test contrôleur : deux `GET` de la page, puis `POST` du code du **premier** secret → codes de secours rendus.
2. Lancer les deux fichiers et **les voir échouer pour la bonne raison** : secrets différents (repository), `422` « Code incorrect. » (contrôleur).
3. Corriger dans `SecondFactorRepository#begin_enrollment` : relire la ligne non confirmée, sinon en créer une ; sur `RecordNotUnique`, relire la ligne non confirmée créée entre-temps, et lever si seule une ligne confirmée existe.
4. Relancer : vert.
5. Relancer la suite `identity` (domaine, infrastructure, contrôleurs, système) : rien d'autre n'a bougé.

Un test qui passe du premier coup ne reproduit pas le bug : à jeter et à réécrire plus bas.

**Phase 5** : un challenger distinct rejoue la reproduction ci-dessus dans l'application et vérifie le cas symétrique (une seule ouverture de page, puis le bon code, active toujours le second facteur ; la réinitialisation suivie d'un réenrôlement tire un nouveau secret).
