# Journal — Annuaire de l'équipe (« Comptes »)

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Grill avec le porteur : nom, genre, numéro modifiables ; désactiver avant d'anonymiser ; anonymisation automatique à 30 jours ; « Comptes » remplace « Débloquer un compte » ; ni soi-même ni le dernier admin ; recherche par nom partiel, numéro et matricule entiers | Memo de la branche `feature/annuaire-equipe` (`510171ce`) | ADR-0093 (Proposé) |
| 2026-10-16 | Cadrage repris sur `Develop` plutôt que sur `feature/annuaire-equipe` | Cette branche part de `feature/espace-direction` (au backlog) : ses numéros d'ADR ne correspondent plus à `Develop`, et elle suppose un matricule qui n'existe pas | non |
| 2026-10-16 | Le matricule sort du périmètre | Aucune colonne sur `Develop` ; il arrive avec `espace-direction` complet | non |
| 2026-10-16 | La direction garde le retrait de l'ADR-0077 (recommandation Q2) | Un seul mécanisme par population, déjà purgé à 30 jours | ADR-0093 §4.3 |
| 2026-10-16 | Les résultats d'un élève anonymisé restent effacés | ADR-0036, amendement 2 (accepté le 2026-10-02), postérieur au grill | non (déjà décidé) |
| 2026-10-16 | ADR-0093, UDR-0095 à 0097 écrits « Proposé », avec les recommandations Q1 à Q8 ; en attente du porteur | Rien ne se code avant ses réponses | — |

## Ce qui a dérapé

- Le grill du 2026-09-28 a été écrit contre la branche `espace-direction`, pas contre `Develop` : trois de ses points étaient faux ou dépassés à la reprise (matricule inexistant ; ADR-0065 et ADR-0066 cités avec les numéros de cette branche ; « résultats gardés » contredit par l'amendement 2 de l'ADR-0036). À retenir : un grill fait sur une branche de backlog se relit contre `Develop` avant d'en tirer un PRD.
- La décision du porteur du 2026-10-02 (« pas d'anonymisation, les données doivent rester accessibles comme archive ») contredit le point 3 du grill ; personne ne l'avait reportée dans le memo de l'annuaire. D'où Q1.

## Ce qu'on a appris sur la codebase

- `/teams/accounts` existe déjà : c'est « Débloquer un compte » (`Teams::AccountLookupsController`, `resource :account_lookup, path: "accounts"`). La page « Comptes » garde l'URL.
- « Débloquer un compte » n'est plus une entrée de navigation depuis l'UDR-0068 : c'est un bouton de `teams/homes/_shortcuts`.
- Deux recherches de comptes coexistent : `AccountLookupQuery` (numéro entier, tous rôles) et `AccountSearchQuery` (nom, ou 4 chiffres, élèves et enseignants, index trigramme `index_users_on_searchable_*`).
- `DeleteUserPolicy` refuse tout sauf l'élève (« lot R ») ; l'invariant « toujours un admin » de l'ADR-0038 n'est codé nulle part.
- Le refus de connexion d'une direction archivée est dans `UserRepository#authenticate` (`archived_school_admin?`) : la désactivation s'ajoute au même endroit.
- `PurgeArchivedStaff` (ADR-0077) est le modèle de la tâche des 30 jours : une transaction par compte, échec isolé, compte restauré sauté.
- Cinq fichiers appellent `teams_account_lookup_path` (accueil, demandes de suppression, réinitialisation du second facteur, suppression) : le renommage est au Lot 0.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Recherche et affichage du matricule | Le matricule n'existe pas sur `Develop` | `espace-direction` |
| Élève désactivé marqué dans les listes de classe (Q8) | Vues `classroom` et `school_admin`, hors de ce chantier | à ouvrir si l'enseignant le demande |
| Filtre par établissement (Q6) | Liste cherchable de 3 900 établissements | à ouvrir sur demande |
| Purges techniques de l'ADR-0036 §6 | Hors périmètre | non planifié |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0093 (Proposé) |
| **UDR produits** | UDR-0095, UDR-0096, UDR-0097 (Proposé) |
