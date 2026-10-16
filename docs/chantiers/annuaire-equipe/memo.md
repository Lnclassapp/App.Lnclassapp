# Memo — Annuaire de l'équipe (« Comptes »)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision — en attente de la validation du porteur (questions Q1 à Q8) |
| **Ouvert le** | 2026-09-28 (grill) · cadrage repris le 2026-10-16 sur `Develop` |
| **Branche** | `docs/cadrage-annuaire-equipe` (cadrage) · `feature/annuaire-equipe` (code, après validation) |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) — ID-18, ID-21, ID-22, ID-23, TR-20, TR-21, TR-22 |

> Le grill du 2026-09-28 a été fait sur la branche `feature/annuaire-equipe` (commit `510171ce`), partie de `feature/espace-direction` qui est au backlog. Ce cadrage le reprend sur `Develop` du 2026-10-16 : entre-temps, `pilotage-equipe`, `fonctions-espace-eleve` (lots R, R2, R3) et `inscription-direction` ont livré une partie du périmètre, et le porteur a pris le 2026-10-02 une décision qui contredit un point du grill (Q1).

---

## Le problème

L'équipe ne peut pas **gérer** un compte. Elle sait en trouver un de deux façons, sans lien entre elles :

- « Débloquer un compte » (`/teams/accounts`, UDR-0020) : un numéro **entier**, un seul résultat, une mini-fiche avec le code de récupération du PIN, la réinitialisation du second facteur et, pour un élève, la demande de suppression ;
- la recherche de « Pilotage » (UDR-0049) : un nom ou 4 chiffres d'un numéro, **élèves et enseignants seulement**, une liste qui ne mène à aucune fiche.

Elle ne peut ni corriger un nom, un genre ou un numéro mal saisi, ni empêcher un compte de se connecter sans l'effacer, ni anonymiser un enseignant ou un membre de l'équipe : l'anonymisation (`AnonymizeUser`) n'accepte qu'un élève (`DeleteUserPolicy`, « lot R »). Un enseignant parti, un faux compte ou un doublon restent actifs, ou se traitent en console.

## Pour qui

- **L'équipe (Team)**, au support : un parent, un élève, un enseignant ou une direction appelle ; l'équipe retrouve le compte, le consulte, le corrige, le désactive, le réactive ou l'anonymise.
- **Le titulaire du compte** : son compte est corrigé ou fermé par l'équipe, jamais exposé à un autre utilisateur.

## Pourquoi maintenant

Le porteur a lancé les vagues V2 à V6 ; `annuaire-equipe` est le chantier restant de la V2 (7 features). `sous-roles-equipe` (V4) l'attend pour réécrire les policies de l'équipe (feuille de route, tableau de collision). Et chaque correction de compte passe aujourd'hui par la console de production.

## Inventaire — ce qui existe déjà sur `Develop` (2026-10-16)

| Besoin du grill | Existe | Où | Reste à faire |
|---|---|---|---|
| Recherche par nom partiel | ✅ insensible à la casse et aux accents, index trigramme, 20 par page | `Queries::Identity::AccountSearchQuery` (pilotage-equipe, TR-11, UDR-0049) | l'étendre aux rôles `team` et `school_admin`, aux filtres rôle et état, et mener à une fiche |
| Recherche par numéro | ⚠️ deux règles : **entier** (Débloquer, `AccountLookupQuery`) et **4 chiffres au moins** (Pilotage) | idem | une seule règle (Q3) |
| Recherche par matricule | ❌ **le matricule n'existe pas** : aucune colonne, il vit sur la branche `feature/espace-direction`, au backlog | — | hors périmètre |
| Fiche d'un compte | ⚠️ mini-fiche dans le frame de « Débloquer un compte », trouvée par numéro entier | `teams/account_lookups/_result` | une page par `public_id`, tous rôles, avec état et dates |
| Débloquer (code PIN, second facteur) | ✅ | `account_pin_recovery_codes`, `teams/second_factor_resets` (UDR-0020) | déplacer les boutons sur la fiche, sans changer leur parcours |
| Modifier nom, genre, numéro par l'équipe | ❌ seul le titulaire change son nom et son numéro (`UpdateOwnName`, `ChangeOwnContact`) ; le genre ne se change nulle part | — | **tout** |
| Désactiver / réactiver un compte | ❌ pour élève, enseignant, équipe ; ✅ pour la **direction** : retrait archivé, restaurable 30 jours, connexion refusée | ADR-0077, `ArchiveSchoolStaff`, `RestoreSchoolStaff`, `school_staffs.archived_at` | élève, enseignant, équipe ; réutiliser l'ADR-0077 pour la direction (Q2) |
| Anonymiser | ⚠️ élève seulement, `admin` seul, résultats effacés, demande de suppression close | `AnonymizeUser`, `DeleteUserPolicy`, `account_deletion_requests` (ADR-0036, amendement 2) | enseignant et équipe ; garde « soi-même » et « dernier admin » |
| Demandes de suppression | ✅ enregistrer, annuler, liste par échéance, carte de rappel au 25e jour | `RecordDeletionRequest`, `CancelDeletionRequest`, `teams/deletion_requests` | rien : la fiche les héberge déjà par frame |
| Anonymisation automatique à 30 jours | ✅ pour la **direction** retirée (`PurgeArchivedStaffJob`, 4 h) ; ❌ ailleurs, et **retirée** par le porteur le 2026-10-02 pour le « départ » | ADR-0077 §4.5 ; ADR-0036, amendement retiré | dépend de Q1 |
| Invariant « toujours un `admin` » | ❌ écrit dans l'ADR-0038, **jamais codé** | — | garde sous verrou |
| Retirer une direction | ✅ depuis la fiche de l'établissement | ADR-0077, `teams/school_staff_members` | l'offrir aussi depuis la fiche du compte (Q2) |
| Entrée « Débloquer un compte » | bouton de l'accueil équipe (pas une entrée de navigation depuis l'UDR-0068) | `teams/homes/_shortcuts` | devient « Comptes », même URL `/teams/accounts` |

**Périmètre retenu** : la page « Comptes » (recherche étendue, filtres), la fiche d'un compte, la modification par l'équipe, la désactivation et la réactivation, l'anonymisation des enseignants et de l'équipe, la garde du dernier admin, et — selon Q1 — l'anonymisation automatique 30 jours après une désactivation.

## Hors périmètre

- **Le matricule** (recherche, affichage, libération d'un matricule usurpé) : il n'existe pas sur `Develop`. Il arrivera avec `espace-direction` complet, qui ajoutera son critère de recherche.
- **Changer le rôle ou le sous-rôle** d'un compte (grill, question 1 ; ADR-0038 pour le sous-rôle).
- **La matrice complète des sous-rôles** : `sous-roles-equipe` (V4) réécrit ces policies après ce chantier.
- **Marquer un élève désactivé dans les listes de classe** de l'enseignant et de la direction (Q8) : ce sont les vues d'autres contextes.
- **L'annuaire pour la direction** : elle a ses listes (UDR-0052).
- **L'export** de la liste des comptes, la sélection multiple, l'action en masse.
- **Un rappel par courriel ou WhatsApp** : l'application n'envoie pas de courriel (ADR-0036, amendement 2).
- **Le changement d'établissement** d'un élève ou le multi-établissement d'un enseignant (backlog).
- **Les purges techniques du §6 de l'ADR-0036** (tentatives de connexion, codes périmés).

## Ce que le grill a révélé

### Décisions prises (porteur, 2026-09-28), relues contre `Develop`

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. Que modifie l'équipe sur une fiche (ID-18) ? | **Nom, genre, numéro.** Jamais le rôle ; jamais le matricule. | Un use case `UpdateAccount`. Un numéro changé ferme les sessions du compte ; format et unicité vérifiés ; journal (qui, quand, quels champs, jamais les valeurs). La route générique `/users/:id/edit` n'est pas reprise. |
| 2. L'anonymisation est-elle immédiate (ID-23) ? | **Non : désactiver d'abord**, réversible, puis anonymiser. | Un état « désactivé » sur `users` (ADR-0093) : sessions fermées, connexion refusée avec le message neutre d'un PIN faux. |
| 3. Quand l'anonymisation définitive ? | **Automatiquement 30 jours après la désactivation** ; l'équipe peut anonymiser avant. | **Contredit par la décision du 2026-10-02** (voir Q1). |
| 4. Où placer l'annuaire ? | **« Comptes » remplace « Débloquer un compte ».** | Même URL `/teams/accounts` ; le bouton de l'accueil change de libellé. La navigation n'est pas touchée : « Débloquer » n'y est plus depuis l'UDR-0068. |
| 5. Peut-on désactiver ou anonymiser un compte équipe ou direction ? | **Oui, sauf soi-même et le dernier `admin` actif.** | Deux refus nommés, vérifiés sous verrou (deux désactivations simultanées ne retirent pas les deux derniers `admin`). |
| 6. Comment chercher parmi des milliers ? | **Une barre** : nom partiel, numéro et matricule entiers ; filtres rôle, état, établissement ; liste paginée. | Matricule : hors périmètre (n'existe pas). Numéro : deux règles en production (Q3). Filtre établissement : Q6. |

### Contradictions relevées par l'inventaire, et tranchées par une décision plus récente

| Point du grill | Décision plus récente | Retenu |
|---|---|---|
| « Les résultats restent dans les statistiques des classes » après anonymisation | ADR-0036, amendement 2 (porteur, 2026-10-02, **accepté**) : les résultats d'un compte supprimé sont effacés | L'amendement 2 : `AnonymizeUser` garde son effacement |
| « Un Proviseur désactivé laisse l'établissement sans Proviseur » (numéro ADR-0066 de la branche `espace-direction`, à renuméroter : sur `Develop`, l'ADR-0066 est l'import des DRENA) | Les fonctions de direction sont sur la branche `espace-direction`, au backlog ; sur `Develop`, la direction est retirée par l'ADR-0077 | La règle de l'ADR-0077 |

### Questions restantes, avec recommandation

| # | Question | Recommandation | Impact |
|---|---|---|---|
| **Q1** | Le grill veut une anonymisation **automatique** 30 jours après la désactivation. Le 2026-10-02, le porteur a retiré l'anonymisation automatique : « les données doivent être accessibles par l'établissement et l'élève comme archive ». Et anonymiser un élève **efface ses résultats** (amendement 2). Que garde-t-on ? | **Automatique pour les adultes** (enseignant, équipe), comme la direction (ADR-0077) ; **jamais pour un élève** : il reste désactivé sans échéance, et son anonymisation passe par la demande de suppression (existante, rappel à 30 jours) ou par le bouton « Anonymiser ». | Avec la recommandation : une tâche quotidienne de plus (Lot E), limitée aux adultes. Si tout est automatique : un élève désactivé perd ses résultats au 31e jour, sans demande. Si rien n'est automatique : le Lot E disparaît (5 lots au lieu de 6). |
| **Q2** | Désactiver une **direction** depuis la fiche : nouvel état, ou le retrait de l'ADR-0077 ? | **Le retrait de l'ADR-0077** : « Désactiver » appelle `ArchiveSchoolStaff`, « Réactiver » `RestoreSchoolStaff`. Un seul mécanisme, déjà purgé à 30 jours. | Aucun nouveau code métier pour la direction ; elle suit les règles de l'ADR-0077 (dont `field` qui retire, et la purge). |
| **Q3** | Recherche par numéro : **entier** seulement (grill), ou **4 chiffres au moins** (en production dans Pilotage, UDR-0049, acceptée le même jour) ? | **Garder la règle en production** : 4 chiffres au moins, numéro masqué dans la liste, complet sur la fiche. Un numéro entier trouve le compte en tête. L'équipe est derrière le second facteur. | Une seule requête pour les deux pages. Si « entier seulement » : la recherche de Pilotage change aussi, ou deux règles coexistent. |
| **Q4** | Que devient la recherche de **Pilotage** ? | **Elle quitte Pilotage** pour « Comptes » ; la carte de recherche est remplacée par un lien « Chercher un compte » (amendement de l'UDR-0049). | Une seule recherche à maintenir, Pilotage plus léger. Sinon : on garde les deux, et chaque ligne de Pilotage mène à la fiche. |
| **Q5** | Quel sous-rôle de l'équipe fait quoi ? | **Chercher et lire** : toute l'équipe (comme aujourd'hui). **Modifier, désactiver, réactiver** un élève ou un enseignant : `admin` et `field` (`field` émet déjà les codes PIN et gère les établissements). **Toucher un compte équipe** : `admin`. **Anonymiser** : `admin` seul (ADR-0038). | Une policy de plus (`ManageAccountPolicy`) ; `sous-roles-equipe` la reprendra. |
| **Q6** | Filtre par **établissement** (grill) ? | **Reporté.** Filtres rôle et état seulement. Un filtre sur 3 900 établissements exige une liste cherchable ; la fiche d'un établissement liste déjà ses enseignants et sa direction. | Une UDR plus simple, un lot plus court. |
| **Q7** | Anonymiser un **enseignant** : ses classes et ses devoirs ? | **Comme un retrait par la direction (ADR-0071)**, pour chacun de ses établissements : retiré de ses classes, devoirs actifs archivés ; ses annonces et contenus restent signés « Compte supprimé ». La **désactivation** ne touche à rien. | Le Lot D réutilise les ports de `DetachTeacher`. Sinon, ses classes gardent un enseignant fantôme. |
| **Q8** | Un élève désactivé est-il marqué « désactivé » dans les listes de sa classe (grill) ? | **Non dans ce chantier** : il ne se connecte plus, rien d'autre ne change. Un chantier `bugfix` ou `feature` suivra si l'enseignant le demande. | Évite de toucher les vues `classroom` et `school_admin`, et leurs UDR. |

## Cas limites identifiés

- **Son propre compte** : la fiche s'affiche, sans aucune action (comme aujourd'hui) ; une requête forgée reçoit `:forbidden`.
- **Dernier `admin`** : désactiver ou anonymiser le dernier compte `team` `admin` actif renvoie `:conflict` « dernier administrateur », compté sous verrou des lignes `admin`.
- **Numéro déjà pris** à la modification : « Ce numéro est déjà utilisé ». L'oracle est borné par le second facteur de l'équipe.
- **Numéro changé** : toutes les sessions du compte sont fermées ; le titulaire se reconnecte avec le nouveau numéro et son PIN.
- **Compte désactivé** : sessions fermées ; à la connexion, le message d'un PIN faux, qui ne dit pas que le compte existe ; un élève garde sa classe et ses résultats ; un enseignant garde ses classes.
- **Réactivation** : rend la connexion, rien d'autre ; annule l'échéance d'anonymisation.
- **Compte anonymisé** : absent de la recherche ; son URL de fiche répond 404.
- **Demande de suppression en attente** sur un compte désactivé : la fiche montre les deux ; l'anonymisation clôt la demande (existant).
- **Concurrence** : deux membres modifient la même fiche ; le dernier enregistrement gagne, le journal garde les deux.
- **Tâche des 30 jours** (si Q1) : quotidienne, idempotente, un compte réactivé entre-temps est sauté, un échec n'arrête pas les suivants et repasse le lendemain (même forme que `PurgeArchivedStaff`).
- **Zéro résultat** : l'état vide dit quoi essayer ; plus de 20 résultats : pagination.

## Questions encore ouvertes

Q1 à Q8 ci-dessus. Aucune ligne de code avant leur réponse : Q1 décide du Lot E, Q2 et Q7 du contenu des Lots C et D, Q4 du périmètre du Lot A.
