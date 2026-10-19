# Journal — Espace direction, ce qui reste de la V2

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le chantier repart d'un dossier neuf sur `Develop`, sans reprendre la conception du 2026-09-28 (branche `feature/espace-direction`) | Six chantiers livrés depuis en couvrent la plus grande part ; le code de classe a disparu (ADR-0085) ; les numéros ADR-0065 à 0067 et UDR-0052, 0053 de cette branche sont pris | Non (memo, Q9) |
| 2026-10-16 | Périmètre réduit à quatre manques vérifiés dans le code : fonctions et droits, changement de classe, recherche d'un élève, recette du PIN côté direction | Inventaire du memo | Non |
| 2026-10-16 | PRD, ADR-0092 et UDR-0092 à 0094 écrits sur les recommandations de l'agent, en attendant les réponses du porteur (Q1 à Q9) | Le porteur valide le cadrage avant le code | ADR-0092 (Proposé) |

## Ce qui a dérapé

- 2026-10-16 : `git checkout -b` a créé la branche de cadrage et mis à jour l'arbre, mais n'a pas basculé `HEAD` (verrou de `.git/config` tenu par un autre agent, écriture de l'amont refusée). Corrigé par `git symbolic-ref`, l'index étant déjà identique à `origin/Develop`. À surveiller quand plusieurs agents créent des branches en même temps dans des worktrees du même dépôt.

## Ce qu'on a appris sur la codebase

- La fiche V2 de la feuille de route (2026-09-28) est périmée : elle donne 22 features restantes à `espace-direction` ; au 2026-10-16, 12 sont faites ou sans objet et 2 sont sorties de la V2. La feuille de route n'a pas été mise à jour par `gestion-etablissement-direction`, `inscription-direction`, `accueil-direction` ni `archivage-classes`.
- `invitations.position` existe depuis l'ADR-0044 et n'est jamais écrite : la fonction choisie à l'invitation a déjà sa colonne.
- `MembershipRepositoryPort#add_primary` rouvre une adhésion close (retrait levé) : le changement de classe n'a besoin d'aucune méthode de port nouvelle.
- Les drapeaux d'affichage des gestes de la direction sont calculés de trois façons (`@school.active?` dans la vue, `@manageable` dans le contrôleur, lambda de policy pour le bloc « Direction ») : le Lot 0 les unifie par la policy avant que le Lot C change les règles.
- Le changement de lien d'invitation par la direction a été retiré par l'ADR-0083 (Q10 d'`inscription-enseignant`) : « code d'établissement » dans l'index du backlog ne désigne plus un geste à faire.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Matricule MENA | Recommandé hors périmètre (Q7) | `abonnement-mobile-money` s'il en a besoin |
| Tableau de bord par période, historique, export | Recommandé hors périmètre (Q8) | à ouvrir après retour de directions réelles |
| Forcer le choix de la fonction des comptes antérieurs | Recommandé : garder leurs droits (Q4) | à décider après comptage en production |
| Second facteur de la direction | Hors périmètre (ADR-0065) | — |
| Feuille de route §5 et §6 périmées pour la V2 | Interdit de toucher les index pendant le cadrage | clôture de ce chantier |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-0092 (Proposé) |
| **UDR produits** | UDR-0092, UDR-0093, UDR-0094 (Proposé) |
