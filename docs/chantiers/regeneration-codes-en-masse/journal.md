# Journal — Régénérer en une fois le code de plusieurs établissements

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sous les recommandations Q1 à Q7, en attente du porteur ; Q0 bloquante | La demande d'origine (2026-10-01) précède l'ADR-0083, qui a retiré le code du lien des enseignants | Non (memo) |
| 2026-10-16 | Périmètre réduit au code d'établissement ; les jetons `/i/` et `/c/` sont exclus | Stables par décision (ADR-0083 §4.1, Q10 d'`inscription-enseignant`) | ADR-0096 §1 |
| 2026-10-16 | Sélection = filtres de la liste, rejoués par lots, bornés à `created_at <= lancement` | Ce que l'équipe voit ; pas d'état de cases à cocher entre pages | ADR-0096 §3, §4.5 |
| 2026-10-16 | Aucun code dans le rapport ni dans l'audit | `import_reports.details` en clair et sans durée ; écran des imports hors `secret_response` | ADR-0096 §2 |
| 2026-10-16 | Reprise : un établissement dont `school_code_rotated_at >= lancement` est sauté (Q7) | Ne pas changer deux fois un code après une panne ou une régénération unitaire concurrente | ADR-0096 §4.3 |

## Ce qui a dérapé

- **La ligne du backlog était périmée.** « Régénère le code d'établissement (donc le lien d'inscription des enseignants) » était vrai le 2026-10-01, faux depuis le 2026-10-07 (ADR-0083). Rien dans le backlog ne le signalait : une ligne de backlog n'est pas relue quand un ADR plus récent change son objet. Trouvé en lisant les en-têtes des vues (`teacher_invite_link_url(school.team_invite_token)` dans `teams/schools/_header`), pas dans la documentation du chantier source.

## Ce qu'on a appris sur la codebase

- `School::RegenerateSchoolCode` autorise **après** la lecture (ADR-0071 §4.2) par `ManageSchoolStructurePolicy`, qui accepte encore la direction sur son établissement actif ; aucune route de la direction ne l'appelle depuis l'ADR-0083 (« Changer le lien » retiré). Policy plus large que l'usage.
- `TransactionPort#attempt` change déjà une violation d'unicité en `failure(:conflict, errors: { base: [:write_failed] })` : le lot par `UPDATE … FROM (VALUES …)` n'a pas besoin de son propre `rescue`.
- La sélection de la liste vit dans une méthode **privée** de `Queries::School::SchoolsQuery` : un use case ne peut pas la joindre (CQRS). D'où le scope partagé `Orm::School.list_filtered` (ADR-0096 §4.5).
- `ImportReportRepositoryPort#create` n'accepte pas de `details` : le rapport de la génération des classes n'avait rien à mémoriser au lancement.
- `AuditLogPort` n'écrit qu'une ligne par appel (`record`) : 3 900 appels sans `record_many`.
- `report_text` (`Teams::ImportsController`) cherche déjà `teams.imports.status.by_kind.<kind>.<clé>` avant la clé commune : renommer les compteurs d'un `kind` ne demande que des locales.
- `ui_dropdown_item` sans `href` ni `dialog` se rend désactivé (`aria-disabled`) : utile pour la sélection vide.
- Le code d'établissement a été **écarté** de `secret_response` par `secrets-hors-cache` (« partagé et durable ») ; depuis l'ADR-0083, l'infobulle de la fiche le dit « secret à transmettre à la direction ».

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| La fiche affiche le code sans `no-store` ni exemption du cache Turbo, alors qu'il est devenu un secret de la direction | Hors périmètre ; disparaît avec le code | `inscription-direction-sans-code`, ou un bugfix s'il tarde |
| `ManageSchoolStructurePolicy` autorise encore la direction à régénérer le code, sans route | Aucun effet visible ; à retirer avec le code | `inscription-direction-sans-code` |
| Export ou envoi des nouveaux codes | Q6 : rien de secret dans un rapport ; demande sa propre menace | à ouvrir si le porteur le demande |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0096 *(Proposé)* |
| **UDR produits** | UDR-0104, UDR-0105, UDR-0106 *(Proposé)* |
