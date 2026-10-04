# Memo — Suites de l'inscription de la direction

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `fix/suites-inscription-direction` |
| **Programme** | — |

---

## Le problème

Trois écarts relevés à la phase 5 d'[`inscription-direction`](../inscription-direction/journal.md), chacun contre une règle déjà écrite.

### Symptômes

1. **Accord.** Une direction femme retirée est annoncée au masculin. Le toast dit « Aya Kouassi a été retiré de la direction. », l'accueil de l'équipe « … · retiré le 4 octobre 2026 » et la fiche « Retiré le … par … · Supprimé le … ». Constaté par le challenger dans Chromium. La règle de la langue de l'interface (UDR-0007) est le français correct, et le genre du compte est connu.
2. **Invitation.** Le numéro d'une direction invitée reste en clair dans `invitations.contact` après la suppression de son compte par la suppression automatique à J+30. La suppression par l'équipe (`AnonymizeUser`) ne vise que des élèves (`DeleteUserPolicy`), qui n'ont pas d'invitation : elle est corrigée par cohérence avec l'ADR-0036 §4, et couverte par les seuls tests unitaires. Constaté par la revue de sécurité, puis reproduit en base. L'ADR-0036 §4 prévoit pourtant « sessions, second facteur, codes et **invitations supprimés** ».
3. **Titre.** Sur téléphone, trois pages n'ont aucun `h1` visible : inscription de la direction, inscription enseignant, acceptation d'une invitation. La page « rejoindre une classe » a déjà le sien dans sa carte ; le test la vérifie quand même. Le titre principal est dans la colonne `hidden md:flex`, et l'écran ne montre qu'un `h2`. Constaté par le challenger à 390 px. UDR-0054 : le `h1` porte le nom de la page.

### Reproduction

1. Archiver une direction de genre `female` (fiche de l'équipe → « Retirer de la direction ») : le toast est au masculin.
2. Inviter une direction (`0700000099`), accepter l'invitation, l'archiver depuis 31 jours, puis lancer `School::PurgeArchivedStaffJob.perform_now` : `Orm::Invitation.where(contact: "0700000099")` existe toujours.
3. Ouvrir `/school-staff-signup`, `/teacher-signup` ou `/invitations/<jeton>` à 390 px : `page.all("h1", visible: true)` est vide.

### Portée

- (1) Depuis la livraison d'inscription-direction (2026-10-04) : toutes les directions femmes.
- (2) Depuis l'ADR-0065 : toute direction invitée, puis supprimée. Aucune suppression de direction n'a encore eu lieu en production, car la purge vient d'être livrée. Les élèves n'ont pas d'invitation. **Aucune donnée à réparer.**
- (3) Depuis la reprise des pages d'inscription (UDR-0024), sur tous les téléphones.

## Pour qui

L'équipe et la direction (1), toute personne dont le compte est supprimé (2), tout visiteur sur téléphone (3).

## Pourquoi maintenant

Les trois points sont ouverts dans le journal du chantier livré, et le porteur a demandé leur correction le 2026-10-04.

## Hors périmètre

- **L'adresse IP du journal d'audit** : le porteur a choisi « gardée 12 mois puis effacée », pour tous les comptes. C'est une règle nouvelle (job de rétention), traitée dans le chantier feature `retention-ip-audit`.
- « retiré(e) » de l'enseignant retiré (`school_admin.teachers`) : même problème d'accord, mais sur un autre parcours. Noté au journal.
- La protection de la branche `Develop` (CI obligatoire) : un réglage GitHub du porteur.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document fixe le comportement attendu ? | (1) UDR-0007, français correct ; (2) ADR-0036 §4 ; (3) UDR-0054 | Les trois sont des bugs, pas des features |
| L'IP du journal d'audit est-elle à effacer à la suppression ? | Porteur : « Gardée 12 mois puis effacée », pour tous | Sort de ce chantier : chantier feature `retention-ip-audit` |
| Des données sont-elles déjà fausses en base ? | Aucune direction supprimée en production ; les élèves n'ont pas d'invitation | Pas de réparation |
| Quels autres acteurs passent par le même chemin ? | (2) `AnonymizeUser` (élève) et la purge (direction) ; (3) élève et enseignant | Les deux use cases et les trois pages sont corrigés |

## Cas limites identifiés

- Une invitation **envoyée par** le compte supprimé (`invited_by_id`) contient le numéro d'une autre personne : elle reste.
- Une invitation en attente ou expirée **pour** le numéro du compte, jamais acceptée : elle est supprimée elle aussi, puisque le numéro est le sien.
- Un compte sans genre connu n'existe pas : `users.gender` est non nul (`male`, `female`).

## Questions encore ouvertes

- Aucune.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (constats (1) et (3) du challenger d'`inscription-direction` dans Chromium, (2) en base par la revue de sécurité ; chacun reproduit ici par un test rouge)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application (Chromium, 390 et 1280 px : les trois points sont OK, ainsi que le cas symétrique de l'inscription et de la restauration)
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
