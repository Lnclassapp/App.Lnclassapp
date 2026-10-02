# PRD — Validation des enseignants en pause

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un enseignant inscrit sans le code secret de son établissement attendait la validation de l'équipe ou d'un collègue garant, et ne pouvait rien faire en attendant. Le porteur met cette validation en pause le 2026-10-02 : l'enseignant doit atteindre au plus vite le moment où Lnclass lui sert. La validation reviendra sous la forme d'une **certification** par DRENA, avant le premier versement aux enseignants (chantier suivant).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Enseignant inscrit sans code | Utiliser Lnclass dès l'inscription, comme un enseignant inscrit par code : classes, catalogue, assignations, invitation de collègues | — |
| Collègue enseignant | Confirmer une demande encore en attente d'avant la pause (geste inchangé) | — |
| Direction | Voir et retirer l'enseignant de son établissement (gestes existants, ADR-0071) | — |
| Équipe | Retirer l'enseignant ; décider une demande encore en attente (gestes inchangés) | — |

Règles d'autorisation inchangées : `RegisterTeacherPolicy` à l'inscription, puis celles de tout enseignant rattaché.

## 3. Parcours utilisateur

### Chemin nominal

1. L'enseignant ouvre « Mon établissement n'a pas encore de code Lnclass » et remplit le formulaire avec le code national ou l'établissement de sa DRENA.
2. Son compte est créé, rattaché à l'établissement comme école principale, et il est connecté.
3. Il arrive sur la sélection de ses classes avec le message « Bienvenue ! Sélectionnez vos classes pour commencer. ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Établissement inconnu, inactif ou en brouillon ; matière inconnue ; formulaire mal rempli | Inchangé : 422 avec le message du champ, rien n'est écrit |
| Numéro déjà pris | Inchangé : 422, aucun compte |
| Plus de 5 envois par minute depuis une adresse | Inchangé : 429 |
| Établissement qui a encore 5 demandes en attente d'avant la pause | Inchangé : « Trop de demandes… » (ne se produit plus après la migration) |
| Validation refusée par la base pendant l'inscription | L'inscription entière est annulée : ni compte, ni demande, ni session |
| Demande en attente au déploiement | Validée « automatiquement », l'enseignant rattaché à l'établissement, sauf s'il a déjà une école principale |
| Demande refusée avant la pause | Reste refusée |

## 4. Critères d'acceptation

```gherkin
Étant donné un établissement actif de code national 012345
Quand un enseignant s'inscrit sans code avec le code national 012345
Alors il est rattaché à cet établissement comme école principale
Et sa demande est validée par la voie « automatique », sans décideur
Et il est connecté et arrive sur la sélection de ses classes avec « Bienvenue ! Sélectionnez vos classes pour commencer. »
```

```gherkin
Étant donné un enseignant qui vient de s'inscrire sans code
Quand il ouvre le catalogue
Alors il le voit, sans être renvoyé vers l'écran d'attente
```

```gherkin
Étant donné que la base refuse la validation de la demande
Quand un enseignant s'inscrit sans code
Alors l'inscription est annulée : ni compte, ni demande, ni session
```

```gherkin
Étant donné une demande en attente, une demande refusée, et une demande en attente d'un enseignant qui a déjà une école principale
Quand la base est mise à jour
Alors la première est validée « automatiquement » et son enseignant rattaché
Et la deuxième reste refusée, sans rattachement
Et la troisième est validée, l'école principale de son enseignant ne change pas
```

```gherkin
Étant donné une demande en attente d'avant la pause
Quand un collègue du même établissement la confirme
Alors l'enseignant est rattaché et le collègue devient son parrain
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::JoinRequest::AUTO` ; `UseCases::Identity::RegisterPendingTeacher` valide la demande créée (`approve`, `via: "auto"`, `decided_by_id: nil`) ; contrat du port : `via` accepte `"auto"` |
| Infrastructure | Migration `20261003120000_pause_teacher_join_request_review` : contrainte `decided_via` élargie à `auto`, demandes en attente validées et rattachées |
| Delivery | `Identity::PendingTeacherRegistrationsController#create` redirige vers `teacher_classrooms_path` |
| UI | Sous-titre du formulaire et message d'arrivée (locales) |

## 6. Décisions rattachées

- [ADR-0073](../../decisions/adr/0073-validation-des-enseignants-en-pause.md) — validation des enseignants en pause ; amende l'ADR-0063.
- [UDR-0050](../../decisions/udr/0050-inviter-un-collegue-et-croissance.md) — amendement du 2026-10-02 : textes de l'inscription sans code, arrivée sur la sélection des classes.
