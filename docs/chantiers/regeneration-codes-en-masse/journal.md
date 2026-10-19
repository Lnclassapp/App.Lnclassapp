# Journal — Régénérer en une fois les codes d'établissement et les liens des classes

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Menace écrite (avant le code, 2026-10-16)

Le chantier ne lit aucun fichier envoyé. Il écrit en masse deux secrets d'accès : le code d'établissement (ouvre l'inscription d'une direction) et le jeton du lien de classe (fait entrer un élève, lève un retrait).

| Menace | Qui | Ce qui fuit ou casse | Parade |
|---|---|---|---|
| Déclencher une régénération de masse | Tout compte qui atteint `POST /teams/schools/code-regenerations` | Des milliers de codes ou de liens coupés d'un coup : directions à venir sans code, liens de classe partagés morts | `Teams::BaseController` (équipe + second facteur) puis `RegenerateCodesInBulkPolicy` (`admin` seulement), dans le use case et revérifiée par le job pour l'auteur ; 403 pour `content`, `field`, direction, enseignant ; jeton CSRF de Rails ; nombre à taper hors d'une DRENA ou d'un établissement |
| « Tous » par mégarde | Un `admin` | Tout le pays à recommuniquer | Nombre tapé vérifié par le serveur, recompté au lancement |
| Un code ou un jeton dans un rapport | Toute l'équipe lit les rapports ; `import_reports.details` est en clair, sans durée ; l'écran des imports n'est pas sous `secret_response` | Les codes d'une DRENA entière lisibles par `content`/`field` et par le cache du navigateur | Le rapport ne garde que les filtres, le nombre attendu et des compteurs ; les erreurs portent un libellé (nom), jamais un code ; test de garde sur `import_reports` |
| Un code ou un jeton dans l'audit | Lecteurs du journal d'audit | Idem | Métadonnées : `public_id` de l'établissement ou de la classe et du rapport, `change` ; jamais `school_code` ni `link_token` ; test de garde sur `audit_events.metadata` |
| Un code ou un jeton dans les journaux Rails | Lecteurs des logs | Idem | Les `UPDATE` sont envoyés par `exec_query` avec des binds : les valeurs n'apparaissent pas dans le log SQL de production (niveau `info`) ; les paramètres du `POST` ne contiennent que filtres et nombre ; aucun `Rails.logger` ajouté |
| Écraser un remplacement un par un | Un enseignant, la direction ou l'équipe pendant le job | Le lien qu'un enseignant vient de partager meurt une seconde fois | Garde dans l'`UPDATE` : `rotated_at IS NULL OR rotated_at < lancement` |
| Rejouer un rapport | Solid Queue (relance), un opérateur (`perform_now`) | Codes changés deux fois | `claim` puis `resume` seulement d'un rapport en cours ; la même garde |
| Collision de code ou de jeton | — | Deux établissements avec le même code, deux classes avec le même lien | Index uniques ; lot rejoué objet par objet, 5 tirages au plus |

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sous les recommandations Q1 à Q7, en attente du porteur ; Q0 bloquante | La demande d'origine (2026-10-01) précède l'ADR-0083, qui a retiré le code du lien des enseignants | Non (memo) |
| 2026-10-16 | Sélection = filtres de la liste, rejoués par lots, bornés à `created_at <= lancement` | Ce que l'équipe voit ; pas d'état de cases à cocher entre pages | ADR-0096 §3, §4.5 |
| 2026-10-16 | Aucun code dans le rapport ni dans l'audit | `import_reports.details` en clair et sans durée ; écran des imports hors `secret_response` | ADR-0096 §2 |
| 2026-10-16 | **Porteur : on garde, élargi aux liens des classes** | « garde la régénération des codes d'établissement et de la classe » | ADR-0096 amendé |
| 2026-10-16 | Deux `kind`, deux jobs, un moteur commun | Un rapport compte un seul genre d'objet ; « une seule à la fois » par genre | ADR-0096 §3, §4.3 |
| 2026-10-16 | Garde de course dans l'`UPDATE … RETURNING id` ; `classrooms.link_token_rotated_at` ajoutée, posée aussi par « Changer le lien » | Atomique ; sert la reprise ; le geste unitaire ne change pas pour l'utilisateur | ADR-0096 §3, §4.4 |
| 2026-10-16 | Reprise réelle : `resume` d'un rapport `validating`/`importing` quand Solid Queue relance le job | Sans elle, un job arrêté proprement puis relancé re-change tout *(corrigé le 2026-10-19 : Solid Queue ne rejoue pas un processus tué net)* | ADR-0096 §4.3 |
| 2026-10-19 | Revue (sécurité, échecs silencieux, tests) : rapport dit « bloqué » à l'écran, `fail_stale` sur `updated_at` après la validation, `advance`/`finish` gardés, rejeu sur collision seulement, mise en file refusée → `:unavailable`, auteur anonymisé refusé, motifs `forbidden` / `not_enqueued` au rapport | La revue de sécurité n'a trouvé aucune faille exploitable ; les échecs silencieux laissaient un rapport « en cours » pour toujours et cinq tentatives sur toute cause | ADR-0096 §4.8, ADR-0026 (septième code) |
| 2026-10-16 | `admin` seulement ; ni affichage ni export ; aucune notification ; gestes unitaires inchangés ; classes archivées non touchées ; année en cours par défaut | Recommandations appliquées, **à confirmer par le porteur** | ADR-0096 §4.7 |
| 2026-10-16 | Lots exécutés dans l'ordre 0 → B → A → C | Le lancement (A) met en file le job (B) : son test de contrôleur a besoin des jobs | Non |
| 2026-10-16 | Le menu « Codes » est remplacé par un `turbo-stream` glissé dans chaque réponse du frame « schools » | Hors du frame, il gardait les filtres du premier chargement : filtrer une DRENA puis ouvrir « Codes » comptait toute la liste (RM-01) | Non (UDR-0104 §3 l'annonçait sans dire comment) |
| 2026-10-16 | Le 422 « nombre faux » recompte par la query de la modale, pas par `Result#value` | `Shared::Result.failure` ne porte pas de valeur ; la query lit les mêmes scopes (ADR-0096 §4.5) | Non |
| 2026-10-16 | Champs du formulaire sous `code_regeneration[…]` (`target`, `selection[…]`, `current_year_only`, `typed_count`) | `ui_field` lit un objet de formulaire ; la sélection voyage toujours en champs cachés, jamais une liste d'identifiants | Non |
| 2026-10-16 | Le 422 répond en `turbo-stream` (remplace le frame « modal ») ; le formulaire vise `_top` | Une redirection vers le rapport doit quitter le frame ; une erreur doit rester dans la modale | Non |
| 2026-10-16 | Durée du test système enregistrée à 3,0 s, ramenée à l'échelle du poste de référence | Poste à 4 cœurs, charge ~40 : `school_code_test` y prend 2,2 fois sa durée enregistrée ; mesuré ici 6,5 s hors démarrage de Puma | Non |

## Mesures (`PERF=1`, 2026-10-16)

`test/performance/school/regenerate_codes_in_bulk_performance_test.rb`, base PostgreSQL de test, poste de 4 cœurs partagé par une dizaine d'agents :

| Geste | Volume | Durée | Requêtes SQL |
|---|---|---|---|
| Codes d'établissement | 3 900 établissements (20 lots) | 4,2 s | 132 |
| Liens des classes | 20 000 classes (100 lots) | 33,1 s | 611 |

Le nombre de requêtes par lot est fixe (~6 : lecture, savepoint, `UPDATE … RETURNING`, `INSERT` de l'audit, avancement). La durée des liens est sous la cible de 60 s ; 60 000 classes en production feraient ~100 s, ce qui reste un job d'arrière-plan suivi par son rapport.

## Ce qui a dérapé

- **Le menu « Codes » gardait les filtres du premier chargement.** Hors du frame « schools », il ne voyait pas un filtre changé dans la liste : la modale recomptait juste, mais sur toute la liste. Vu en écrivant le test système ; corrigé par un `turbo-stream` dans la réponse du frame.
- **Le premier `bin/ci-quiet` (2026-10-16, charge ~40 sur 4 cœurs) a trouvé trois vrais défauts** : les deux use cases concrets recevaient `policy:` par `**` (le garde ADR-0028 lit la signature), `new.html.erb` n'appelait pas `page_title` (seul son partial le faisait), une branche du moteur (lot entièrement « déjà changé ») sans test. Corrigés ; les autres échecs (minuterie d'`ImageHeader`, concurrence de `StaffRestore`, cinq tests système d'autres écrans) sont passés relancés seuls.
- **Une infobulle dans un `<p>`.** `ui_info_tip` est un `<details>` : dans un paragraphe, le navigateur fermait le `<p>` et l'icône tombait seule sous la ligne. Vu sur les captures ; le conteneur est un `<div>`.

- **La ligne du backlog était périmée.** « Régénère le code d'établissement (donc le lien d'inscription des enseignants) » était vrai le 2026-10-01, faux depuis le 2026-10-07 (ADR-0083). Rien dans le backlog ne le signalait.
- **Le cadrage avait exclu les liens de classe** (« stables ou un par un ») ; le porteur les voulait. « Le code de la classe » n'existait plus dans le code depuis l'ADR-0085 : il fallait traduire la demande en « jeton du lien de classe ».
- **Revue de la PR #257 (2026-10-19).** Le commentaire du moteur et l'ADR disaient qu'un job « tué » était rejoué par Solid Queue : faux (1.7 ne rejoue qu'après un arrêt propre). Un processus tué net laissait donc le rapport « en cours » jusqu'au prochain lancement. Les trois revues ont aussi relevé : `fail_stale` appelé avant la validation et jugé sur `started_at` (donc un rapport qui avance pouvait être rendu `failed`), `advance` et `finish` qui réécrivaient un rapport déjà `failed`, un rejeu ×5 sur toute cause (pas seulement une collision), `perform_later` qui rend `false` sans lever, et l'auteur anonymisé qui gardait son droit. Corrigés ensemble ; ce qu'on retient : **tout ce qu'une file « garantit » se vérifie dans la version installée avant de l'écrire dans un ADR.**

## Ce qu'on a appris sur la codebase

- `School::RegenerateSchoolCode` autorise **après** la lecture (ADR-0071 §4.2) par `ManageSchoolStructurePolicy`, qui accepte encore la direction sur son établissement actif ; aucune route de la direction ne l'appelle depuis l'ADR-0083.
- `TransactionPort#attempt` change déjà une violation d'unicité en `failure(:conflict, errors: { base: [:write_failed] })`.
- La sélection de la liste vivait dans une méthode **privée** de `Queries::School::SchoolsQuery` : d'où le scope partagé `Orm::School.list_filtered`.
- `classrooms.link_token` est tiré par la base (`DEFAULT` et `LINK_TOKEN_SQL`), jamais par le domaine ; « Changer le lien » n'écrit pas d'audit et n'avait aucune date de changement.
- Un lien d'une classe **active d'une année passée** marche encore (`JoinPreviewQuery#link` ne lit pas l'année) : l'option « année en cours » a un effet réel.
- `Entities::Catalog::ImportReport` n'exposait pas `created_at` : le lancement n'était lisible que par `started_at`, posé au `claim`.
- `report_text` (`Teams::ImportsController`) cherche déjà `teams.imports.status.by_kind.<kind>.<clé>` avant la clé commune.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| La fiche affiche le code sans `no-store` ni exemption du cache Turbo | Hors périmètre ; disparaît avec le code | `inscription-direction-sans-code`, ou un bugfix s'il tarde |
| `ManageSchoolStructurePolicy` autorise encore la direction à régénérer le code, sans route | Aucun effet visible | `inscription-direction-sans-code` |
| « Changer le lien » (un par un) n'écrit pas d'audit, la masse si | Le porteur a gardé l'unitaire inchangé | à ouvrir si le porteur le demande |
| La date de changement d'un lien de classe n'est affichée nulle part | Pas d'UDR sur la page de la classe | à ouvrir si utile |
| Recette par un rôle distinct (parcours RM-01 → RM-02, RM-15 → RM-18 dans l'application) | L'agent n'a pas d'autre rôle que l'auteur | le porteur, sur la PR |
| Q1 à Q7 et les choix du memo (admin seul, ni export ni notification, année en cours par défaut) appliqués sans confirmation | Réponses attendues du porteur | ce chantier, si le porteur en change un |
| Export ou envoi des nouveaux codes et liens | Rien de secret dans un rapport ; demande sa propre menace | à ouvrir si le porteur le demande |
| Moitié `school_codes` à retirer avec le code d'établissement | Décision du porteur en connaissance de cause | `inscription-direction-sans-code` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 (PR prête vers `Develop`, non fusionnée) |
| **PR** | voir la PR de la branche `feature/regeneration-codes-en-masse` |
| **ADR produits** | ADR-0096 *(Accepté, amendé)* |
| **UDR produits** | UDR-0104, UDR-0105, UDR-0106 *(Acceptées, amendées)* |
