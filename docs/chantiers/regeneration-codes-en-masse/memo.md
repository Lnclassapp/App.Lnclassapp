# Memo — Régénérer en une fois les codes d'établissement et les liens des classes

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | exécution : Q0 tranchée par le porteur le 2026-10-16 (gardé, élargi aux liens des classes) ; recommandations Q1 à Q7 appliquées, **à confirmer par le porteur** |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `feature/regeneration-codes-en-masse` |
| **Programme** | `refonte-application`, vague V2 : sorti de [`gestion-etablissement-direction`](../gestion-etablissement-direction/memo.md) (précision du porteur, 2026-10-01) |

---

## Le problème

Le 2026-10-01, le porteur demande un bouton de l'équipe qui régénère **d'un coup** le code de plusieurs établissements, par exemple ceux d'une DRENA. À cette date, le code d'établissement était aussi le **lien d'inscription des enseignants** (`/e/<code>`, ADR-0057) : régénérer le code fermait le lien.

**Ce n'est plus vrai depuis le 2026-10-07.** L'[ADR-0083](../../decisions/adr/0083-inscription-enseignant-en-deux-voies.md) a retiré le code de tout le parcours enseignant :

- le lien d'inscription des enseignants est `/i/<jeton>`, avec deux jetons par établissement (`direction_invite_token`, `team_invite_token`) et le jeton de parrainage de chaque enseignant ;
- ces jetons sont **stables par décision** : ni « Changer le lien » ni « Régénérer » (Q10 d'[`inscription-enseignant`](../inscription-enseignant/memo.md)) ;
- le code d'établissement ne sert plus qu'à **l'inscription de la direction** (ADR-0077, plafond de 3 par le code), jusqu'au chantier `inscription-direction-sans-code`, qui doit le supprimer avec « Régénérer le code ».

La demande d'origine n'a donc plus d'objet tel qu'elle est écrite. Ce qui reste vrai : le code ouvre encore un compte direction, qui lit les enseignants et le travail des élèves de l'établissement. Aujourd'hui, l'équipe ne peut le changer qu'**un établissement à la fois**, depuis la fiche. Avec ~3 900 établissements, fermer d'un coup les codes d'une DRENA ou de tout le pays demande des milliers de clics.

## Ce qui existe : la régénération un par un

| Pièce | Fichier | Ce qu'elle fait |
|---|---|---|
| Use case | `app/domain/use_cases/school/regenerate_school_code.rb` | Lit l'établissement par `public_id`, autorise **après** la lecture, tire un code (`Entities::School::SchoolCode.generate`), l'écrit avec `school_code_rotated_at` ; 5 tirages au plus en cas de collision, puis `:conflict` ; une transaction |
| Policy | `app/domain/policies/school/manage_school_structure_policy.rb` | Toute l'équipe (`admin`, `content`, `field`), ou la direction sur son seul établissement actif (ADR-0071). La direction n'a plus de route depuis l'ADR-0083 (« Changer le lien » retiré) |
| Port, adaptateur | `SchoolRepositoryPort#replace_school_code` ; `SchoolRepository#replace_school_code` | `update!` dans un savepoint ; l'index unique `index_schools_on_school_code` change une collision en `:conflict` sans casser la transaction |
| Audit | dans le use case | `school.changed`, sujet l'établissement, `{ change: "code_regenerated", public_id: }` ; **une ligne par établissement**. Aucune action d'audit nouvelle à créer |
| Delivery | `PATCH /teams/schools/:public_id/code` → `Teams::SchoolCodesController#update` | Toast « Nouveau code d'établissement : K7M-4QZ. », en-tête de la fiche remplacé (Turbo Stream), repli HTML vers la fiche |
| Vue | `app/views/teams/schools/_header.html.erb` | Menu ⋮ « Régénérer le code », modale de confirmation, bloc « Code d'établissement » avec « Copier le code » ; libellé « Pour l'inscription de la direction » |
| Secrets hors cache | `secret_response` (chantier [`secrets-hors-cache`](../secrets-hors-cache/memo.md)) | **Le code d'établissement n'y est pas** : il a été écarté comme « code partagé et durable, fait pour circuler ». Depuis l'ADR-0083, l'infobulle le dit pourtant « code secret à transmettre à la direction ». Voir Q6 |
| Lecteurs du code | `RegisterSchoolStaff` (inscription de la direction) ; `ImportSchools` (tirage à l'import) | Plus aucun lecteur côté enseignant |
| Tests | `test/domain/use_cases/school/regenerate_school_code_test.rb`, `test/controllers/teams/school_codes_controller_test.rb`, `test/system/teams/school_code_test.rb` | — |

Précédent pour une action de masse de l'équipe : la **génération des classes manquantes** ([ADR-0056](../../decisions/adr/0056-generation-des-classes-manquantes.md)) : job Solid Queue par lots de 200, compte rendu dans `import_reports` avec un `kind` sans fichier, suivi par l'écran des imports, une seule à la fois.

## Pour qui

- **L'équipe (Team), membres `admin`** : elle ferme d'un geste les codes d'un ensemble d'établissements (une DRENA, un filtre, tous), par exemple après la diffusion d'une liste de codes ; et, depuis le 2026-10-16, les liens des classes de ces établissements, ou d'un seul établissement depuis sa fiche (un lien de classe qui a trop circulé).
- **La direction (SchoolStaff)** : celle qui est inscrite n'est pas touchée (elle se connecte par numéro et code secret, et ne voit pas le code). Celle qui s'inscrira devra recevoir le nouveau code de l'équipe.
- **L'enseignant, l'élève** : rien ne change pour le code d'établissement. Pour les **liens des classes** (élargissement du 2026-10-16) : l'ancien lien `/c/<jeton>` d'une classe régénérée cesse de marcher ; l'élève déjà inscrit reste dans sa classe ; l'enseignant et la direction partagent le nouveau lien depuis la page de la classe, comme après « Changer le lien ».

## Pourquoi maintenant

Le porteur a demandé de lancer les vagues V2 à V6 (2026-10-16). Mais la raison d'origine a disparu le 2026-10-07 (ADR-0083) et le porteur a dit, le même jour, qu'**aucun lien `/e/<code>` n'avait été partagé** (Q11 d'`inscription-enseignant`). L'urgence est à confirmer : voir Q0.

## Hors périmètre

- **Régénérer les jetons des liens d'invitation** (`/i/<jeton>` : direction, équipe, parrainage) : stables par décision (ADR-0083 §4.1).
- **Les classes archivées** : leur lien ne marche déjà plus ; le geste de masse ne les touche pas.
- **Ajouter un audit à « Changer le lien »** (un par un) : le geste unitaire reste inchangé (réponse du porteur).
- **Transmettre les nouveaux codes ou liens** : ni export, ni envoi par SMS, WhatsApp ou annonce, ni liste des codes à l'écran. L'équipe lit le code sur la fiche, comme aujourd'hui (Q6).
- **Retirer les directions inscrites avec un ancien code** : le geste existe un par un (ADR-0077) ; aucun retrait en masse.
- **Annuler une régénération** (rendre les anciens codes) : impossible, comme un par un.
- **Une rotation automatique** et planifiée des codes.
- **Rendre « Changer le lien » à la direction**, ou un geste de masse à la direction.
- **Supprimer le code d'établissement** : chantier `inscription-direction-sans-code`.
- **Mettre la fiche de l'établissement sous `secret_response`** : constat noté au journal, pas traité ici.

## Ce que le grill a révélé

> Questions posées au porteur le 2026-10-16. Aucune réponse encore : la colonne « Réponse » porte la **recommandation** de l'agent, à confirmer ou à changer. Le PRD, l'ADR, les UDR et le plan sont écrits **sous ces recommandations**.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| **Q0 (bloquante). Le lien des enseignants ne contient plus le code depuis l'ADR-0083 : que doit-on régénérer en masse, et le chantier a-t-il encore lieu d'être ?** | *Recommandation* : **suspendre jusqu'à ce que l'ordre avec `inscription-direction-sans-code` soit fixé.** Si ce chantier, qui supprime le code, passe dans les prochaines semaines : **abandonner** celui-ci (on construirait un job pour un code voué à disparaître). Sinon, le garder, **réduit au code d'établissement** (inscription de la direction). Jamais les jetons `/i/` : stables par décision. | Gardé : le périmètre est le code seul (hypothèse de ce cadrage). Abandonné : le dossier reste comme trace, la ligne du backlog est retirée à la clôture. |
| Q1. Quelle sélection : une DRENA, un filtre, tous ? | *Recommandation* : **les filtres de la liste « Établissements »** (DRENA, type, cycle, statut, recherche). Ce qu'on voit est ce qu'on régénère. Sans filtre : tous les établissements. Pas de cases à cocher ligne par ligne. | Une seule action couvre les trois cas. La sélection est rejouée au lancement, pas copiée : un établissement importé après le lancement n'est pas pris (il a déjà un code neuf). Tous les statuts que le filtre laisse passer sont pris (un établissement inactif réactivé ne ressort pas avec un vieux code). |
| Q2. Quelle confirmation ? | *Recommandation* : une **modale** qui donne le nombre d'établissements, la DRENA s'il y en a une et les conséquences. **Hors d'une seule DRENA** (plusieurs DRENA ou tous), l'équipe **tape le nombre** d'établissements pour confirmer. | Le serveur recompte au lancement : un nombre tapé qui ne correspond plus (liste changée entre-temps) est refusé avec le nouveau nombre. UDR-0104. |
| Q3. Prévient-on les directions ? | *Recommandation* : **non.** Une direction inscrite n'utilise plus le code (elle se connecte par numéro et code secret) et ne le voit nulle part depuis l'ADR-0083. Seule une direction **à venir** en a besoin, et c'est l'équipe qui le lui donne. **La fiche affiche la date du dernier changement** (« Changé le 16 octobre 2026 »), pour qu'un appel « mon code ne marche pas » se comprenne. | Aucune notification, aucun canal. UDR-0106 sur la fiche. |
| Q4. En job ou dans la requête ? | *Recommandation* : **en job** (Solid Queue), comme la génération des classes (ADR-0056) : ~3 900 établissements ne tiennent pas dans une requête HTTP. Lots de 200 par transaction, une régénération de masse à la fois, compte rendu dans `import_reports` (`kind` `school_codes`, sans fichier), suivi sur l'écran des imports. | ADR-0096. Un nouveau `kind` dans la contrainte `import_reports_kind_values` (migration). L'équipe est renvoyée vers le rapport, rechargé tant qu'il tourne. UDR-0105. |
| Q5. Quel membre de l'équipe ? | *Recommandation* : **`admin` seulement.** Le geste un par un reste ouvert à toute l'équipe, comme aujourd'hui. | Policy nouvelle `RegenerateSchoolCodesPolicy`. Le menu n'affiche pas l'action aux rôles `content` et `field`. |
| Q6. Montre-t-on les nouveaux codes à la fin (liste, export) ? | *Recommandation* : **non.** Le rapport donne des nombres, jamais de code : `import_reports.details` est un JSON gardé en clair et sans limite de durée, et l'écran des imports n'est pas sous `secret_response`. Un export des codes serait un chantier à part, avec sa menace écrite. | Rien de secret dans le rapport ; pas de `secret_response` à poser. Coût : pour transmettre un code, l'équipe ouvre la fiche, comme aujourd'hui. |
| Q7. Si un établissement est régénéré un par un pendant que le job tourne ? | *Décidé par l'agent (technique)* : le job saute un établissement dont le code a changé **après le lancement** ; il le compte « déjà changé ». | Le job peut reprendre après une panne sans changer deux fois un même code. |

## Cas limites identifiés

- **Sélection vide** (filtre sans résultat) : l'action est refusée, rien n'est mis en file.
- **Une régénération de masse déjà en cours** : on est renvoyé vers son rapport, avec un message d'information (comme la génération des classes).
- **Collision** entre un code tiré et un code pris entre-temps (import, régénération un par un) : le lot est rejoué établissement par établissement, avec les 5 tirages de l'ADR-0057 ; un établissement qui échoue encore passe « en erreur », les autres sont écrits.
- **Job interrompu** : après un arrêt propre, Solid Queue rejoue le job et la reprise ne touche que ce qui n'a pas changé depuis le lancement ; un processus tué net laisse le rapport « bloqué » (dit à l'écran après 10 minutes sans avancée), libéré par le lancement suivant (`fail_stale`), qui change de nouveau ce qui l'avait été.
- **Une direction en train de s'inscrire** avec l'ancien code : son envoi reçoit l'erreur neutre « Code d'établissement invalide » (`RegisterSchoolStaff`, inchangé).
- **Droit retiré pendant le job** (le compte `admin` perd son rôle) : le job revérifie la policy de l'auteur au démarrage et passe le rapport en échec, comme l'ADR-0056.
- **Import d'établissements pendant le job** : les établissements créés après le lancement ne sont pas pris.
- **Établissement inactif ou en brouillon** dans la sélection : son code change aussi (il ne sert à rien tant qu'il n'est pas actif).
- **« Tous » sans filtre, ~3 900 établissements** : 20 lots de 200 ; cible de durée au PRD §7.

## Questions encore ouvertes

- Q0 : tranchée (gardé, élargi aux liens des classes). Q1 à Q7 : recommandations appliquées, à confirmer par le porteur.
- **Le code sur la fiche n'est pas sous `secret_response`**, alors que l'infobulle le dit « secret » depuis l'ADR-0083. Hors périmètre ; à signaler à `inscription-direction-sans-code`, qui supprimera le code, ou à traiter en bugfix si ce chantier tarde.

## Réponses du porteur (2026-10-16)

1. Le porteur demande « le code de quoi exactement ». Réponse : le **code d'établissement** (6 caractères, par exemple `k7m2qx`), qui ne sert plus qu'à inscrire une direction. Recommandation de l'agent : abandonner.
2. **Réponse du porteur : « non, garde la régénération des codes d'établissement et de la classe »**, et travail en toute autonomie.

**Q0 tranchée : on garde le chantier, élargi aux liens des classes.** « Le code de la classe » du porteur est le **jeton du lien de classe** `/c/<jeton>` (ADR-0085) : depuis l'ADR-0085, une classe n'a plus d'autre code (inventaire ci-dessous). Le chantier livre donc **deux gestes de masse** : régénérer les codes d'établissement d'une sélection, régénérer les liens des classes d'une sélection.

**Conflit noté, décision prise en connaissance de cause.** Le chantier prévu `inscription-direction-sans-code` doit supprimer le code d'établissement et « Régénérer le code ». S'il passe, la moitié « codes d'établissement » de ce chantier partira avec lui (use case, job, `kind` `school_codes`, menu) ; la moitié « liens des classes » reste. Le porteur a gardé les deux en sachant cela : ce chantier ne retarde ni ne bloque l'autre, et l'ADR-0096 dit ce qu'il faudra retirer.

**Recommandations appliquées sans attendre, à confirmer par le porteur :**

| Sujet | Appliqué | Pourquoi |
|---|---|---|
| Qui lance | **Membres `admin` de l'équipe seulement**, pour les deux gestes de masse. `content`, `field`, la direction et l'enseignant n'ont ni le menu ni la route (403). | Un geste qui coupe des milliers de liens en un clic ; `DeleteUserPolicy` fait déjà ce tri. |
| Transmission | Les nouveaux codes et liens **ne sont ni affichés ni exportés en masse** : le rapport donne des nombres, jamais un code ni un jeton. | `import_reports.details` est en clair, sans durée, et l'écran des imports n'est pas sous `secret_response` (Q6). |
| Notification | **Aucune** : ni direction, ni enseignant, ni élève. | Q3 ; un lien de classe se repartage depuis la page de la classe. |
| Geste un par un | **Inchangé** : « Régénérer le code » sur la fiche (toute l'équipe) et « Changer le lien » d'une classe (enseignant de la classe, direction, équipe). | Le porteur n'a rien demandé sur l'unitaire. |
| Ancien lien de classe | **Cesse aussitôt de fonctionner**, comme après « Changer le lien » : l'élève qui l'ouvre arrive sur l'inscription standard avec l'alerte « lien invalide ». | Même règle que le geste un par un (ADR-0085 §4.1). |
| Classes touchées | Les classes **actives** des établissements de la sélection ; option « année scolaire en cours seulement », cochée par défaut. Une classe archivée n'est pas touchée (son lien ne marche déjà plus, et « Changer le lien » la refuse). | Un lien d'une classe active d'une année passée marche encore (`JoinPreviewQuery#link` ne lit pas l'année) : l'option a un effet réel. |
| Sélection des classes | Depuis la liste « Établissements » : les classes des établissements filtrés. Depuis la fiche d'un établissement : ses classes. | Demande du porteur relayée par le cadrage. |

## Inventaire côté classe (2026-10-16)

| Pièce | Fichier | Ce qu'elle fait |
|---|---|---|
| Stockage | `classrooms.link_token` (`db/schema.rb`) | 12 caractères hexadécimaux, `NOT NULL`, **unique** (`index_classrooms_on_link_token`), `CHECK` `^[0-9a-f]{12}$` (`classrooms_link_token_format`). Aucune date de changement avant ce chantier. |
| Génération | `DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)` ; `ClassroomRepository::LINK_TOKEN_SQL` | **Tiré par la base**, à la création comme au remplacement : une seule source de sa forme (ADR-0085 §4.1). `GenerateMissingClassrooms` et l'import ne le tirent pas. |
| Remplacement un par un | `UseCases::Classroom::ChangeClassroomLink` → `ClassroomRepositoryPort#rotate_link_token(id:)` | Sous le verrou de la classe (`lock_by_public_id`, le même que l'adhésion d'un élève) ; refusé pour une classe archivée (`:forbidden`, `classroom_archived`). |
| Policy | `Policies::Classroom::ManageClassroomMembersPolicy` | L'**enseignant de la classe**, la **direction** de son établissement, **toute l'équipe** (`admin`, `content`, `field`) ; hors périmètre : `:not_found` ; élève : `:forbidden`. |
| Delivery | `PATCH /classrooms/:public_id/link` → `Classroom::ClassroomLinksController#update` | Bloc `#classroom_link` remplacé (Turbo Stream) et toast ; repli HTML. Vu sur la page de la classe (enseignant, équipe) et sur celle de la direction. |
| Audit | — | **Aucun** : « Changer le lien » n'écrit pas au journal. Le geste de masse en écrit un (ADR-0096 amendé) ; l'asymétrie est notée au journal. |
| Ancien lien | `lock_by_link_token` → `nil` ; `JoinPreviewQuery#link` → `nil` ; `Classroom::JoinsController#load_link` | Jeton inconnu ou remplacé : la page d'inscription standard s'ouvre avec l'alerte « lien invalide », voie `standard`. Un élève déjà inscrit n'est pas touché. |
| Autre code de classe | `classrooms.join_code`, `join_code_rotated_at`, `Entities::Classroom::JoinCode` | **Supprimés** (ADR-0085 §4.1, dernier lot d'`inscription-eleve-sans-code`) : absents de `db/schema.rb`. Un ancien code de 5 caractères dans `/c/<code>` est traité comme un jeton inconnu. Il n'y a **plus aucun autre code de classe**. |
