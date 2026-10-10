# Memo — Archiver une classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-09 |
| **Branche** | `Develop` (branche désignée de la session ; pas de `feature/<slug>`) |
| **Programme** | — *(ou `<programme>` si le chantier est une vague d'un programme — voir `docs/workflows/programme.md`)* |

---

## Le problème

Tous les établissements importés reçoivent désormais les classes de la 6ème à la Terminale (chantier import-second-cycle-force). Un collège, ou un établissement sans second cycle, se retrouve donc avec des classes qui n'existent pas sur le terrain. Aujourd'hui personne ne peut les mettre de côté : la seule action possible est de supprimer la dernière classe d'un niveau, et seulement si elle n'a jamais servi.

## Pour qui

La direction d'un établissement (SchoolStaff) et l'équipe (Team), quelques mois après l'import, quand le terrain a montré quels niveaux n'existent pas.

## Pourquoi maintenant

L'import des établissements force le second cycle partout : sans archivage, les classes en trop restent visibles de tous (élèves, enseignants, direction) et faussent les effectifs.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Les rôles « Drena manager » et « DE » : ils n'existent pas dans l'application et ne sont pas créés ici.
- Supprimer définitivement une classe.
- Archiver en masse **par établissement** (tous les niveaux d'un coup) ; l'archivage par niveau, lui, est dans le périmètre.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui archive : « Drena managers » / « DE », ou direction et équipe ? | Direction et équipe (porteur) | Aucun nouveau rôle. Droit de la direction limité à son établissement, comme pour les autres actions de structure |
| Une classe avec des élèves peut-elle être archivée ? | Oui, avec un message de confirmation (porteur, revient sur sa première réponse) | Aucun refus pour cause d'élèves ; la confirmation dit combien d'élèves sont concernés |
| Que voit un élève dont la classe est archivée ? | Option A (porteur) : compte et historique gardés ; écran « Votre classe n'est plus active, rejoignez-en une avec le lien de votre enseignant ou de la direction » ; plus d'exercices à faire ; ses autres classes restent | Un élève sans autre classe active retombe sur cet écran ; un élève multi-classes n'est pas touché pour ses autres classes |
| Restaurer une classe : les élèves et l'enseignant reviennent-ils ? | Oui, automatiquement (porteur) : l'archivage ne touche ni adhésions ni assignations ; pendant l'archivage, le lien d'inscription refuse les nouveaux élèves | La restauration ne ressaisit rien ; une classe archivée n'accepte aucune nouvelle adhésion |
| Une classe à la fois, ou tout un niveau ? | Les deux (porteur), dans le menu ⋮ de la carte de la classe et dans celui du niveau | Deux actions : « Archiver la classe » et « Archiver le niveau » (confirmation avec le nombre de classes et d'élèves) ; l'archivage par niveau sort du hors périmètre |
| Une classe archivée reste-t-elle dans la liste ? | Visible 7 jours après l'archivage (badge « Archivée », menu ⋮ « Restaurer »), puis masquée derrière un bouton « Afficher les archives » (porteur) | Le délai se compte depuis la date d'archivage ; passé 7 jours la classe n'apparaît que sur demande ; restaurable à tout moment |
| Que voit un enseignant dont la classe est archivée ? | Recommandation acceptée (porteur) : la classe disparaît de sa liste, plus d'assignation possible ; assignations et résultats conservés, visibles à la restauration ; échéances de cette classe retirées du tableau de bord ; ses autres classes intactes | Pas de lecture seule pour l'enseignant ; toutes les lectures enseignant filtrent les classes actives |
| Une classe avec des enseignants rattachés ou des exercices assignés ? | Oui aussi, même confirmation (porteur) | Plus aucun blocage : seule la confirmation protège ; l'historique (adhésions, assignations) est conservé |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
