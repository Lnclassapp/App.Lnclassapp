# PRD — CRM des écoles (« Lnclass Intelligent »)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'équipe démarche les établissements, mais le suivi de la relation (qui, quand, quoi, quand relancer) vit hors de l'application, dans les téléphones et les mémoires. Le chantier ajoute à l'espace équipe un suivi des écoles : responsable, étape (saisie et calculée d'après l'usage réel), journal structuré des échanges, relances, une liste « à relancer » calculée, et quatre assistants IA (briefing, brouillon WhatsApp, rapport pour la direction, compte rendu dicté). Livraison avant le 15 novembre 2026 (projet de stage de Touré), sans marge : voir [memo](memo.md), réponse 8.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team `admin` | Tout voir ; noter un échange sur toute école ; planifier, faire, annuler une relance ; changer l'étape de toute école ; attribuer, réattribuer (une ou plusieurs écoles), retirer un responsable ; utiliser les quatre assistants IA ; télécharger le rapport pour la direction | — |
| Team `field` | Tout voir ; noter un échange sur toute école ; planifier une relance sur toute école, faire ou annuler les siennes ; changer l'étape **des écoles dont il est responsable** ; utiliser les quatre assistants IA ; télécharger le rapport | Changer l'étape d'une école d'un autre ; changer un responsable (le sien compris) ; prendre une école sans responsable |
| Team `content` | — | Voir le suivi (page, liste, fiche, assistants) : 403 sur toute route du suivi |
| Teacher, Student, SchoolStaff (direction), Parent | — | Voir le suivi, sous aucune forme. Le rapport leur parvient seulement en PDF, par l'équipe |

Règle d'autorisation : **`Policies::School::FollowSchoolPolicy`**, avec trois gestes distincts :

| Geste | Règle |
|---|---|
| `:read_and_note` | `actor.team?` et `team_role ∈ {admin, field}` |
| `:change_stage` | `:read_and_note` et (`admin` ou `actor.id == relationship.owner_id`) |
| `:assign_owner` | `admin` |

Les assistants IA et le rapport demandent `:read_and_note`. Faire ou annuler une relance : son destinataire, son auteur ou un `admin`.

## 3. Parcours utilisateur

### Chemin nominal

1. Touré (`field`) ouvre **Suivi** dans le shell équipe. Il arrive sur l'onglet **À relancer**, filtré sur ses écoles, et chaque ligne dit pourquoi l'école est là (relance due, inactive depuis N jours, démo sans suite).
2. Il ouvre une école et voit son étape, son responsable, son usage (comptes rattachés, dernier geste pédagogique et son auteur), ses relances ouvertes et son journal.
3. Avant d'appeler, il touche **Briefing** : un résumé de l'historique et de l'usage s'affiche en quelques secondes.
4. Après l'appel, il touche **Dicter le compte rendu**, enregistre ou choisit un fichier son, puis relit le formulaire d'échange que l'IA a pré-rempli (type, interlocuteur, résultat, note, relance proposée). Il corrige et enregistre.
5. Il planifie une relance dans 7 jours et passe l'étape à **Démo faite**.
6. La semaine suivante, il touche **Brouillon WhatsApp**, relit le texte, le copie et l'envoie depuis son téléphone. L'application n'envoie rien.
7. En fin de trimestre, il génère le **rapport pour la direction**, le corrige et le télécharge en PDF. La version téléchargée est gardée dans le journal.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| École sans compte ni échange | Étape Prospect, sans responsable ; absente de « À relancer » |
| Usage : au moins un compte rattaché | Une école Prospect ou Démo faite s'affiche **Inscrite** |
| Usage : un geste pédagogique (devoir donné, ou travail rendu sur un devoir de la classe) dans les 14 derniers jours | L'école s'affiche **Active** (si l'étape saisie est sous Abonnée) |
| École Abonnée sans geste depuis 14 jours | Reste Abonnée ; entre dans « À relancer » (motif « inactive ») |
| École Perdue : un geste pédagogique postérieur à la perte | Le passage quotidien remet l'étape saisie à Prospect et écrit « Reprise d'usage » dans le journal (date, ancienne étape). Il prévient le responsable par une alerte « À voir », ou tous les `admin` si l'école n'a pas de responsable. L'école s'affiche alors Active |
| `field` tente de changer l'étape d'une école d'un autre (requête forgée comprise) | 403, rien n'est écrit |
| `field` tente de changer un responsable | 403 |
| Choix de « Active » ou « Inscrite » à la main | Impossible : ces étapes ne figurent pas dans le formulaire et sont refusées côté serveur (422) |
| Passage à Perdue sans motif | 422, le motif est obligatoire |
| Échange noté par un autre que le responsable | Alerte « À voir » pour le responsable, si l'école en a un |
| Compte du responsable anonymisé | Ses écoles passent « sans responsable » ; ses relances ouvertes restent ouvertes, sans destinataire ; le bandeau « N écoles sans responsable » apparaît pour les `admin` |
| Réattribution (une ou plusieurs écoles) | Le journal de chaque école reçoit « Responsable : A → B » ; les relances ouvertes sans destinataire passent au nouveau responsable |
| `content`, enseignant, direction sur une URL du suivi | 403 |
| Modèle IA indisponible, trop lent (> 60 s), ou budget mensuel atteint | Le panneau affiche l'erreur et « Réessayer » ; le reste de la fiche fonctionne |
| Quota de l'utilisateur atteint (40 appels IA par jour) | Message « Limite du jour atteinte », pas d'appel au fournisseur |
| Fichier son : vide, d'un autre format que MP3 ou M4A, plus de 5 Mo, plus de 3 minutes, illisible | 422 avec le message du motif ; aucun appel au fournisseur |
| Sortie de l'IA hors du format attendu (compte rendu) | « Le compte rendu n'a pas pu être lu, notez l'échange à la main » ; le formulaire vide reste utilisable |
| Liste « Toutes les écoles » sur des milliers d'établissements | Filtrée (étape, responsable, DRENA, recherche) et paginée par 50 |

## 4. Critères d'acceptation

```gherkin
# Accès
Étant donné un membre de l'équipe de sous-rôle content
Quand il ouvre la page du suivi ou la fiche de suivi d'une école
Alors il reçoit une réponse 403

Étant donné un enseignant connecté
Quand il ouvre une URL du suivi
Alors il est refusé

# Étape affichée
Étant donné une école d'étape saisie Prospect sans aucun compte rattaché
Alors son étape affichée est Prospect

Étant donné une école d'étape saisie Démo faite avec un enseignant rattaché et aucun geste pédagogique
Alors son étape affichée est Inscrite

Étant donné une école d'étape saisie Prospect dont un enseignant a donné un devoir il y a 3 jours
Alors son étape affichée est Active

Étant donné une école d'étape saisie Prospect dont un élève a rendu un travail il y a 13 jours sur un devoir de sa classe
Alors son étape affichée est Active

Étant donné une école dont le seul geste pédagogique date de 15 jours
Et dont des enseignants se sont connectés hier
Alors son étape affichée est Inscrite

Étant donné une école Abonnée dont le dernier geste pédagogique date de 20 jours
Alors son étape affichée est Abonnée
Et elle figure dans « À relancer » avec le motif « inactive depuis 20 jours »

# Reprise d'une école perdue
Étant donné une école Perdue le 1er novembre, dont Touré est responsable
Et un devoir donné le 3 novembre dans une de ses classes
Quand le passage quotidien du suivi s'exécute
Alors l'étape saisie de l'école est Prospect
Et son journal contient « Reprise d'usage » avec l'ancienne étape Perdue
Et Touré a une alerte « À voir » pour cette école
Et un second passage n'ajoute ni entrée ni alerte

# Saisie de l'étape
Étant donné un field qui n'est pas le responsable de l'école
Quand il envoie un changement d'étape
Alors il reçoit 403 et l'étape est inchangée

Étant donné le responsable de l'école
Quand il envoie l'étape « active »
Alors il reçoit 422 et l'étape est inchangée

Étant donné le responsable de l'école
Quand il passe l'école à Perdue sans motif
Alors il reçoit 422

Étant donné le responsable de l'école
Quand il passe l'école à Démo faite
Alors le journal contient « Étape : Prospect → Démo faite » avec son nom

# Journal et alertes
Étant donné une école dont Touré est responsable
Quand Konan note un appel avec Mme Kouassi, résultat positif
Alors le journal de l'école affiche l'appel, Mme Kouassi, le résultat et l'auteur Konan
Et Touré a une alerte « À voir » pour cet échange
Et Konan n'a pas d'alerte

Étant donné une école sans responsable
Quand un field note un échange
Alors aucune alerte n'est créée

# Responsable
Étant donné un field
Quand il envoie une attribution de responsable
Alors il reçoit 403

Étant donné un admin et trois écoles sans responsable cochées
Quand il les attribue à Touré
Alors chacune a Touré pour responsable et son journal contient « Responsable : — → Touré »

Étant donné Touré responsable de 2 écoles avec une relance ouverte chacune
Quand son compte est anonymisé
Alors les 2 écoles sont sans responsable
Et les 2 relances sont ouvertes et sans destinataire
Et un admin voit « 2 écoles sans responsable »

# Relances et « À relancer »
Étant donné une relance de Touré due hier et non faite
Alors l'onglet « À relancer » de Touré liste l'école avec le motif « relance due »

Étant donné une école Démo faite sans échange depuis 8 jours
Alors elle figure dans « À relancer » avec le motif « démo sans suite »

Étant donné une école inactive avec un échange noté il y a 2 jours
Alors elle ne figure pas dans « À relancer » au motif « inactive »

Quand Touré marque sa relance faite
Alors elle disparaît de « À relancer » et le journal contient « Relance faite »

# Assistants IA
Étant donné un fournisseur de modèle simulé qui répond
Quand un field demande le briefing d'une école
Alors le briefing s'affiche
Et l'appel est tracé avec l'acteur, l'école, l'usage « briefing » et le fournisseur
Et le texte envoyé au fournisseur ne contient aucun nom d'élève

Étant donné un fournisseur simulé qui ne répond pas
Quand un field demande un brouillon WhatsApp
Alors le panneau affiche l'erreur et « Réessayer »

Étant donné un utilisateur qui a fait 40 appels IA aujourd'hui
Quand il demande un briefing
Alors le message « Limite du jour atteinte » s'affiche et le fournisseur n'est pas appelé

Étant donné un budget mensuel atteint
Quand un field demande un briefing
Alors le fournisseur n'est pas appelé et le panneau le dit

Étant donné une requête au fournisseur
Alors elle porte le réglage interdisant la conservation et l'entraînement sur les données

# Compte rendu dicté
Étant donné un fichier M4A de 40 secondes
Quand un field l'envoie comme compte rendu
Alors le formulaire d'échange s'affiche pré-rempli avec la réponse du fournisseur simulé
Et aucun échange n'est enregistré tant qu'il n'a pas validé
Et le fichier son n'est plus stocké après le traitement

Étant donné un fichier WAV, ou un MP3 de 4 minutes, ou un fichier de 6 Mo
Quand un field l'envoie comme compte rendu
Alors il reçoit 422 avec le motif et le fournisseur n'est pas appelé

Étant donné une réponse du fournisseur qui n'est pas au format attendu
Alors le message « Le compte rendu n'a pas pu être lu » s'affiche avec le formulaire vide

# Rapport pour la direction
Étant donné une école avec deux classes et des travaux rendus
Quand un field génère le rapport des 30 derniers jours
Alors un brouillon modifiable s'affiche avec la synthèse, l'usage par classe et les élèves à suivre
Quand il le télécharge
Alors il reçoit un PDF dont le texte est sa version corrigée
Et le journal de l'école contient « Rapport téléchargé » avec la période et son nom
Et le PDF n'est servi qu'à un admin ou un field connecté, en no-store
```

## 5. Modélisation préliminaire

Contexte borné : **`school`** (le suivi porte sur la relation avec un établissement). Les signaux d'usage sont lus en lecture seule dans `classroom` (devoirs) et `assessment` (travaux rendus) par une query du suivi ; aucun use case de ces contextes n'est touché.

| Couche | Éléments prévus |
|---|---|
| Domaine | Entités `School::Relationship` (étape saisie, responsable, motif de perte), `School::Interaction` (journal), `School::FollowUp` (relance), `School::TeamAlert`, `School::RelationshipStage` (calcul pur de l'étape affichée), `School::FollowUpRule` (motifs « à relancer »). Policy `FollowSchoolPolicy`. Use cases `NoteInteraction`, `ChangeStage`, `AssignOwner` (une ou plusieurs écoles), `PlanFollowUp`, `CompleteFollowUp`, `CancelFollowUp`, `DetectResumedSchools` (passage quotidien), `ReleaseOwnedSchools` (appelé à l'anonymisation), `RequestBriefing`, `RequestWhatsappDraft`, `DraftDirectorReport`, `DownloadDirectorReport`, `TranscribeDictation`. Ports `RelationshipRepositoryPort`, `LanguageModelPort`, `AiUsageLedgerPort` |
| Infrastructure | Tables `school_relationships`, `school_interactions`, `school_follow_ups`, `team_alerts`, `ai_requests`. Modèles `Orm::School::*`. Repositories. Queries `FollowedSchoolsQuery` (liste filtrée et paginée), `FollowUpQueueQuery` (« à relancer »), `SchoolUsageSignalsQuery` (comptes rattachés, dernier geste et son auteur), `DirectorReportDataQuery`. Adaptateur `OpenRouterLanguageModel` (Net::HTTP, bibliothèque standard). Jobs `School::DetectResumedSchoolsJob` (quotidien) et `School::AiRequestJob`. Gem `prawn` pour le PDF |
| Delivery | Routes sous `teams` : `follow_ups` (onglets), `schools/:id/relationship` (fiche), `interactions`, `stage`, `owner`, `owner_assignments` (en masse), `follow_up_tasks`, `alerts`, `ai_requests` (création + lecture par interrogation), `director_report` (brouillon + PDF), `dictations` |
| UI | Entrée « Suivi » du shell équipe (admin, field), page à onglets, fiche de suivi, formulaire d'échange, panneaux des quatre assistants, contrôleurs Stimulus `ai-request` (interrogation) et `audio-recorder` |

## 6. Décisions rattachées

- ADR-XXXX-suivi-commercial-des-ecoles : tables, étape calculée, règle « à relancer », passage quotidien, alertes, responsable libéré à l'anonymisation.
- ADR-XXXX-acces-aux-modeles-ia-par-openrouter : port, adaptateur sans gem, données envoyées par usage, non-conservation, trace, budget et quota, appels en tâche de fond.
- ADR-XXXX-compte-rendu-dicte-fichier-son : menace du fichier son, écrite avant le code.
- ADR-XXXX-rapport-direction-en-pdf : dépendance `prawn`, version gardée au journal.
- UDR-XXXX-suivi-des-ecoles : page Suivi, fiche de suivi, formulaires, réattribution, alertes.
- UDR-XXXX-assistants-ia-du-suivi : les quatre panneaux et leurs états.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de l'onglet « À relancer » (50 lignes) | — | ≤ 8, sans N+1 | |
| Temps d'un briefing (fournisseur réel) | — | ≤ 15 s | |
| Écoles avec un responsable, 1 semaine après livraison | 0 | ≥ 30 | |
