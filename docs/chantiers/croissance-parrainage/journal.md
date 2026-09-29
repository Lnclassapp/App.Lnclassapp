# Journal — Croissance par parrainage, démarrage à froid et mesure du k-factor

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Le porteur garde la limite de 5 demandes en attente par établissement, malgré le risque de saturation (M1) | Accepté en l'état ; la vérification du numéro par WhatsApp (hook n8n) viendra dans un chantier suivant | Oui — ADR-0063, amendement du 2026-09-28 (décision du porteur) |
| 2026-09-28 | Défauts appliqués sans arbitrage : badge à 3 filleuls, 5 demandes en attente par établissement, un seul garant, compte refusé conservé, nom du parrain non affiché | Le porteur a demandé d'avancer ; chaque défaut est listé « à confirmer » dans le memo | Oui — ADR-0063, UDR-0050 (statut *Proposé*) |
| 2026-09-28 | Table `referrals` plutôt que `users.referred_by_id` | Source (lien / garant), date et établissement lisibles par les métriques ; `users` inchangé | Oui — ADR-0063 §3 |
| 2026-09-28 | Jeton de parrainage tiré par la base (`DEFAULT`), pas par le domaine | Aucun chemin d'écriture à toucher (inscription, seeds, fabriques, existant) ; le jeton n'a pas de sens métier | Oui — ADR-0063, coût consenti |
| 2026-09-28 | Compte en attente = enseignant sans `teacher_schools` + ligne `school_join_requests` | L'écran d'attente existait déjà pour « enseignant sans école » (ADR-0030) | Oui — ADR-0063 §3 H |
| 2026-09-28 | Audit des décisions sous `school.changed` (`change: join_request_*`), sans nouvelle action d'audit | Même forme que la régénération du code (ADR-0057) ; la liste fermée n'est pas touchée (le chantier photo-de-profil la modifie aussi) | Non |
| 2026-09-28 | Partage compté par `navigator.sendBeacon` sur un vrai lien | Le lien s'ouvre même si l'envoi échoue ; aucune redirection vers un domaine tiers depuis notre serveur | Oui — ADR-0063 §4 |
| 2026-09-28 | La décision d'une demande (`approve`) écrit la décision **et** la ligne `teacher_schools` dans le repository, en un point de sauvegarde | `UPDATE … WHERE status = 'pending'` rend la concurrence équipe / garant sûre ; un enseignant qui a déjà une école annule la décision | Oui — ADR-0063 §4 |
| 2026-09-28 | Garde « enseignant sans école → écran d'attente » dans `AuthenticatedController`, pas dans chaque contrôleur | Un seul endroit ; la condition de `TeachingSelectionsController` devient inutile et est retirée ; deux tests existants (profil, déclaration d'une classe) décrivent désormais la redirection | Oui — ADR-0063, amendement ADR-0030 |
| 2026-09-28 | Le lien de classe partagé sur WhatsApp garde le code en majuscules (`/c/KFM37`) | UDR-0027 interdit le code en minuscules dans la page ; `/c/` normalise la casse | Non (UDR-0050 §3) |
| 2026-09-28 | L'inscription sans code réutilise la page et le formulaire de l'inscription (`@pending`) et le frame public DRENA → établissement (UDR-0024) | Un seul formulaire à tenir ; la liste publique retrouve un usage | Oui — UDR-0050 |
| 2026-09-28 | Les compteurs de la page Croissance en une requête (sous-requêtes scalaires) : 4 requêtes au total | Page lue par l'équipe seulement, mais bornée quel que soit le volume | Oui — ADR-0063 §4 |

## Ce qui a dérapé

- TDD : chaque lot a d'abord tourné rouge (constantes, colonnes, routes absentes), puis vert.
- `db:migrate` sur PostgreSQL 16 local a réécrit toutes les `CHECK` du `schema.rb` (précédents : generer-classes, code-etablissement) : seules les lignes du chantier ont été gardées, par un script qui reprend l'ancienne ligne de chaque contrainte nommée.
- `bun.lock` est recréé par la construction des assets et s'est glissé dans le premier commit : retiré par `--amend` avant tout push.
- Dans un test d'intégration, `@request` est l'objet requête de Rails : nommer ainsi une demande casse tout le test. Renommé `@join_request`.
- `def message` dans un test masque l'assistant de Minitest : renommé `share_message`.
- `assert_select … text: /…validé(e)…/` : les parenthèses d'un message traduit sont des métacaractères ; `Regexp.escape`.
- La session a été interrompue (limite) en plein Lot 4 : PostgreSQL était arrêté à la reprise (`service postgresql start`), rien n'était perdu dans le worktree.
- Fusion d'`origin/Develop` (PR #49 fusionnée, puis PR #48) : **le côté Develop avait perdu la route `resource :code` des codes d'établissement et les lignes ADR-0057 / UDR-0044 des index** (résolution de conflit de la PR #48). La fusion de ce chantier les rétablit ; à vérifier sur Develop.
- Couverture de branches à 99,7 % au premier passage complet : trois gardes devenues mortes avec la garde générale (`school_id.nil?`, `&.`) retirées, deux cas de test ajoutés (concurrence équipe / garant, garant sans école).

### Retour du challenger (916b6e01 rendu KO)

| Constat | Correction (test rouge d'abord) |
|---|---|
| B1 — supprimer un établissement ayant une demande ou un parrainage : 500 (clé étrangère) | `referenced?` compte `school_join_requests` et `referrals` → `:conflict` |
| B2 — 12 inscriptions simultanées laissaient 7 demandes en attente | comptage et insertion sous `FOR UPDATE` sur la ligne de l'école ; test de concurrence (rouge sans le verrou : 12 au lieu de 5) |
| `period[]=7` → 500 ; `drena_public_id=%00` → 500 | période lue en texte ; DRENA cherchée seulement si connue, identifiants hors alphabet oubliés par le DTO |
| Demande décidée par l'URL d'un autre établissement | 404 |
| Oracle du code national, « trop de demandes » révélé tôt | ordre : formulaire, matière, établissement ; plafond dans la transaction, après le compte |
| Garant d'un autre établissement : 403 ≠ 404 | 404 pour les deux |
| Partages sans limite ; en attente redirigé au lieu de 403 ; sans profil compté | 30/h, 403, rien compté |
| Cohorte avec comptes en attente, conversion avec garants, classement avec inactifs | exclus |
| k à deux décimales, « 67% », partage natif sans url, en-tête HITL sur 4 lignes | corrigés |
| M1 — saturation des 5 places par un attaquant | **décision du porteur (2026-09-28) : la limite de 5 est gardée.** Parade prévue plus tard : vérification du numéro par WhatsApp via un hook n8n (voir « Suites prévues ») |

## Mesures

| Mesure | Valeur |
|---|---|
| Requêtes de `GrowthMetricsQuery` | 4, identiques avec 5 parrainages et 10 partages de plus (test de comptage) |
| Requêtes de `ReferralQuery` (bloc d'invitation) | 2 |
| Suite complète | 2 081 tests, 0 échec ; couverture 100 % lignes (7 566) et 100 % branches (1 712) |
| Tests système | 168, 0 échec (dont bureau et 390 px pour chaque parcours du chantier) |
| Budget JavaScript | `javascript_bundle_test` vert (contrôleur `identity--share` ajouté) |

## Ce qu'on a appris sur la codebase

- `allow_roles` et la garde du second facteur s'exécutent avant les filtres de `AuthenticatedController` : l'acteur y est toujours présent.
- `ActiveModel` cherche les traductions d'erreurs dans les ancêtres : un DTO qui hérite de `TeacherRegistrationInput` en reprend tous les messages.
- Un partiel rendu par `render "form"` depuis une vue appelée par un autre contrôleur est cherché d'abord dans le dossier de ce contrôleur : chemins complets pour la page partagée.
- Une constante déclarée dans le bloc de `Data.define` va dans la portée englobante : on la pose après, comme `Actor::ROLES`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Confirmer les défauts (seuil Ambassadeur 3, 5 demandes en attente, un seul garant, compte refusé conservé, nom du parrain non affiché) | Décisions du porteur | — |
| Mesurer les partages du lien de **classe** | Hors périmètre ; l'amplification se lit par les élèves entrés | — |
| Notifier le garant ou l'enseignant en attente (SMS) | Hors périmètre V1 | — |
| Validation des comptes en attente par la direction (`school_admin`) | V2 | — |
| Récompense (monétaire ou non) au-delà du badge ; classement visible des enseignants | Décision du porteur | — |
| Vérifier sur Develop la route des codes d'établissement et les index ADR-0057 / UDR-0044 perdus à la fusion de la PR #48 | Constaté pendant la fusion, corrigé dans cette branche seulement | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0063 ; amendements ADR-0057, ADR-0030 |
| **UDR produits** | UDR-0050 ; amendements UDR-0018, UDR-0026, UDR-0036, UDR-0044 |

## Suites prévues

- **Vérification du numéro par WhatsApp** (demande du porteur, 2026-09-28) : à l'inscription sans code, un code envoyé sur WhatsApp par un hook **n8n** confirme le numéro avant que la demande n'entre dans la file de l'établissement. Réduit la saturation des 5 places (M1) et la réservation du numéro d'un tiers. Chantier ouvert au backlog : [`verification-whatsapp`](../verification-whatsapp/memo.md) ; rien n'est livré ici.
