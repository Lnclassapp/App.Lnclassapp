# ADR-0073 : La validation des enseignants inscrits sans code est en pause : leur demande est validée à l'inscription
<!-- index
titre: La validation des enseignants inscrits sans code est en pause : leur demande est validée à l'inscription
statut: Accepté *(porteur, 2026-10-02)* — *amende 0063*
problematique: `RegisterPendingTeacher` crée puis valide la demande (`approve`, `via: "auto"`, sans décideur) : rattachement immédiat, arrivée sur la sélection des classes ; migration qui valide les demandes encore en attente ; la future certification par DRENA réutilisera la trace. Chantier `validation-enseignants-en-pause`.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-02 : « mettre en pause la partie validation des comptes »)* |
| **Date** | 2026-10-02 |
| **Chantier** | `docs/chantiers/validation-enseignants-en-pause` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis l'ADR-0063, un enseignant qui s'inscrit sans le code secret de son établissement (code national, ou établissement choisi dans sa DRENA) obtient un compte sans école et une demande `pending`. Il ne voit que l'écran d'attente jusqu'à ce que l'équipe ou un collègue garant valide sa demande ; un établissement a au plus 5 demandes en attente.

Personne ne valide encore : l'équipe n'a pas atteint les établissements, et peu d'enseignants y sont actifs. Le porteur veut qu'un enseignant atteigne son premier usage utile le plus vite possible. La validation reviendra plus tard, sous le nom de **certification**, DRENA par DRENA, par les collègues et les directions, avant le premier versement aux enseignants.

## 2. Moteurs de décision

- Le temps entre l'inscription et le premier usage.
- Garder la trace des inscriptions sans code, pour la future certification.
- Rester réversible : la certification réutilisera les demandes.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Supprimer les demandes et rattacher directement | Plus simple | Perd la trace « inscrit sans code » dont la certification aura besoin |
| B — Accès partiel en attendant (catalogue seul) | Garde la validation | L'enseignant ne peut toujours pas assigner : pas de premier usage |
| C — **Demande validée à l'inscription, voie `auto`, sans décideur** | Accès immédiat ; trace gardée ; mêmes écritures que les autres validations | Une valeur de plus dans `decided_via` |

## 4. Décision

> **Pendant la pause, `Identity::RegisterPendingTeacher` crée la demande puis la valide dans la même transaction : `JoinRequestRepositoryPort#approve(id:, decided_by_id: nil, via: "auto", at:)`, qui rattache l'enseignant à l'établissement comme école principale. L'enseignant arrive sur la sélection de ses classes, comme après une inscription par code.**

- `Entities::School::JoinRequest::AUTO = "auto"` ; la contrainte `school_join_requests_decided_via_values` accepte `team`, `sponsor`, `auto`.
- Un refus de la validation (`:conflict`) annule toute l'inscription.
- La migration `20261003120000_pause_teacher_join_request_review` valide par la même voie les demandes encore `pending` qu'une inscription d'aujourd'hui aurait pu faire (compte non anonymisé, établissement actif, aucun retrait ouvert de cet établissement, ADR-0071), et rattache leurs enseignants (sauf école principale existante) ; les autres restent `pending`, les refusées restent refusées. Un enseignant déjà lié à l'établissement sans y être rattaché la fait échouer, plutôt que de valider une demande qui ne rattache personne. Son `down` rétablit la contrainte et échoue s'il existe une demande `auto`.
- La validation `auto` n'écrit pas d'événement d'audit : la trace est `decided_via = 'auto'` et `decided_at` sur la demande.
- Inchangés : le plafond de 5 demandes en attente, la limite de débit, la validation par l'équipe et par un garant (pour une demande d'avant la pause), l'écran d'attente (comptes refusés), la mesure de croissance (une demande validée compte comme une inscription).

## 5. Conséquences

### 🟢 Positives

- Un enseignant inscrit sans code assigne son premier exercice dans la même session.
- La certification saura qui s'est inscrit sans code (`decided_via = 'auto'`).

### 🔴 Coûts consentis

- **N'importe qui peut rejoindre n'importe quel établissement** en le choisissant dans la liste publique. La direction et l'équipe le retirent par les gestes existants (ADR-0071) ; la certification le filtrera avant tout versement.
- **Le code secret d'un établissement ne protège plus rien pendant la pause**, et un enseignant rattaché sans code reçoit le lien d'invitation qui le contient. À la reprise de la validation, l'équipe régénère les codes des établissements concernés.
- Le plafond de 5 demandes, la section « Enseignants en attente » et la carte des collègues en attente ne servent plus qu'aux demandes d'avant la pause.

## 6. Notes d'implémentation

```ruby
request = written(@join_requests.create(teacher_id: user.id, school_id: school.id, at: now, max_pending: …))
written(@join_requests.approve(id: request.id, decided_by_id: nil, via: Entities::School::JoinRequest::AUTO, at: now))
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/identity/register_pending_teacher_test.rb` : la demande est validée par `auto` sans décideur ; un refus de validation annule l'inscription.
- `test/controllers/identity/pending_teacher_registrations_controller_test.rb` : rattachement, voie `auto`, redirection vers la sélection des classes.
- `test/db/pause_teacher_join_request_review_test.rb` : demandes en attente validées et rattachées ; refusées intactes ; école principale existante gardée ; compte anonymisé, établissement inactif et retrait ouvert laissés en attente ; lien non principal → échec.
- `test/system/identity/cold_start_test.rb` : l'enseignant atteint le catalogue sans écran d'attente.

## 8. Remplace, complète, amende

- **Amende l'ADR-0063** §4 « Démarrage à froid » et « Validation » : la demande n'est plus `pending` après l'inscription ; la voie `auto` s'ajoute à `team` et `sponsor`.
