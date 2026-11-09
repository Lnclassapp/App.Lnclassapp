# PRD — CRM des écoles (« Lnclass Intelligent »)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'équipe démarche les établissements, mais le suivi de chaque relation (étape, responsable, contacts, échanges, relances) vit hors de l'application. Ce chantier greffe ce suivi sur l'espace équipe existant : un bloc « Suivi » sur la fiche établissement, un pipeline sur la liste « Établissements », une liste « À relancer » calculée d'après l'usage réel, et quatre assistants par modèle de langage (fiche de briefing, compte rendu dicté, rapport pédagogique pour la direction, brouillon de relance WhatsApp). Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe `admin` (second facteur vérifié) | Tout ce que peut `field` ; voir et réattribuer les relances de n'importe quel membre, dont celles d'un destinataire indisponible | — |
| Équipe `field` (second facteur vérifié) | Lire le suivi de toute école ; changer l'étape saisie et le responsable ; gérer les contacts ; noter un échange ; créer, terminer et réattribuer une relance ; lancer les quatre assistants | Modifier ou supprimer un échange noté |
| Équipe `content` | — | Voir le bloc « Suivi », les filtres du pipeline, « Mes relances » : bloc absent, 403 sur les adresses du suivi |
| Enseignant, élève, direction (`school_admin`) | — | Toute adresse du suivi : 403 |
| Visiteur | — | Toute adresse du suivi : redirection vers la connexion |

Règle : une nouvelle policy du contexte `crm` qui autorise `team` avec `team_role` ∈ {`admin`, `field`} (même population que « Gérer établissements » dans la matrice de l'ADR-0038). La policy existante de gestion des établissements, qui laisse passer `content`, n'est **pas** réutilisée. Réattribuer la relance d'un autre membre : `admin`, ou le responsable de l'école.

## 3. Parcours utilisateur

### Chemin nominal

1. Le membre ouvre « Établissements », filtre par étape « Démo faite » et par responsable « Moi » : la liste affiche l'étape de chaque école.
2. Il ouvre une fiche : le bloc « Suivi » montre l'étape, le responsable, les chiffres d'usage (comptes, élèves actifs, dernière activité), les contacts, les relances ouvertes et le journal.
3. Il clique « Préparer l'appel » : une fiche de briefing de 5 lignes au plus apparaît dans le bloc.
4. Après l'appel, il clique « Dicter un compte rendu », parle, arrête : le formulaire « Noter un échange » s'ouvre pré-rempli (type, interlocuteur, résultat, prochaine étape, note, date de relance proposée). Il corrige et enregistre : l'échange entre dans le journal, la relance proposée est créée s'il l'a gardée.
5. Le lendemain, l'Accueil équipe montre la carte « À relancer » : ses écoles et la raison de chacune. Il ouvre « Mes relances », clique « Rédiger un message » sur une relance : un brouillon WhatsApp apparaît, il le copie ou l'ouvre dans WhatsApp, l'envoie lui-même, puis marque la relance « Faite ».
6. Pour une école active, il clique « Préparer le rapport pédagogique » : une page imprimable présente les chiffres des 30 derniers jours et un texte de synthèse, qu'il partage à la direction.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| École jamais suivie | Étape calculée (Prospect, Inscrite ou Active), « Aucun responsable », états vides des contacts, relances et journal |
| Marquer « Perdue » sans motif | Refusé, le formulaire montre l'erreur, rien n'est enregistré |
| Saisir « Active » ou « Inscrite » | Impossible : ces étapes ne figurent pas dans le choix |
| Responsable anonymisé ou devenu `content` | École « sans responsable » ; ses relances ouvertes « destinataire indisponible », réattribuables par un `admin` |
| Responsable choisi qui n'est pas `admin`/`field` | Refusé (422) |
| Numéro de contact invalide | Refusé ; format `0[157]` + 8 chiffres, comme les comptes |
| Retirer un contact cité par un échange | Le contact disparaît de la liste ; l'échange garde son nom |
| Terminer une relance déjà faite | Sans effet, pas d'erreur |
| École désactivée | Suivi lisible et modifiable, jamais dans « À relancer » |
| Service de modèles non configuré | Les boutons des assistants sont remplacés par « Assistant non configuré » ; le reste du suivi fonctionne |
| Service de modèles en erreur ou trop lent (> 30 s, > 90 s pour une dictée) | « L'assistant n'a pas répondu. Réessayer » ; aucune donnée du suivi n'est modifiée |
| Une génération du même type déjà en cours pour l'école | Pas de second appel ; l'écran montre la génération en cours |
| Briefing demandé sans changement depuis le dernier | Le dernier briefing est réaffiché, sans appel au modèle |
| Enregistrement vocal > 3 min, > 10 Mo ou format hors `audio/webm`, `audio/ogg`, `audio/mp4` | Refusé avant envoi au modèle, message clair |
| Réponse du modèle inexploitable pour un compte rendu | Formulaire pré-rempli avec la seule transcription dans la note |
| École sans donnée pédagogique sur la période | Le rapport l'écrit (« Pas encore assez d'activité ») et n'appelle pas le modèle |
| Rôle autre que `admin`/`field` | 403 |

## 4. Critères d'acceptation

Chacun devient un test.

```gherkin
# Accès
Scénario: CA-01 un membre content ne voit pas le suivi
  Étant donné un membre de l'équipe de sous-rôle content
  Quand il ouvre la fiche d'un établissement
  Alors le bloc « Suivi » est absent
  Et toute adresse du suivi lui répond 403

Scénario: CA-02 enseignant, élève, direction refusés
  Étant donné un enseignant connecté
  Quand il appelle une adresse du suivi
  Alors il reçoit 403

# Étape et responsable
Scénario: CA-03 étape calculée d'une école jamais suivie
  Étant donné une école sans aucun compte rattaché
  Alors son étape affichée est « Prospect » et son responsable « Aucun »

Scénario: CA-04 l'usage l'emporte sur une saisie « Perdue »
  Étant donné une école marquée « Perdue »
  Et une session d'exercice d'un de ses élèves il y a 3 jours
  Alors son étape affichée est « Active »

Scénario: CA-05 « Abonnée » l'emporte toujours
  Étant donné une école marquée « Abonnée » sans activité depuis 30 jours
  Alors son étape affichée est « Abonnée »

Scénario: CA-06 « Perdue » exige un motif
  Quand un membre field marque une école « Perdue » sans motif
  Alors l'étape n'est pas modifiée et le formulaire signale le motif manquant

Scénario: CA-07 changer l'étape et le responsable est journalisé
  Quand un membre field passe une école à « Démo faite » et s'en nomme responsable
  Alors la fiche affiche « Démo faite » et son nom
  Et le journal d'audit contient crm.stage_changed et crm.owner_changed

Scénario: CA-08 responsable invalide refusé
  Quand un membre choisit comme responsable un membre content
  Alors la réponse est 422 et le responsable ne change pas

# Contacts
Scénario: CA-09 ajouter et retirer un contact
  Quand un membre ajoute « Mme Kouassi, directrice, 0701020304 »
  Alors elle apparaît dans les contacts de l'école
  Quand il la retire
  Alors elle disparaît des contacts mais les échanges qui la citent gardent son nom

Scénario: CA-10 numéro invalide refusé
  Quand un membre saisit le numéro « 12345 »
  Alors le contact n'est pas enregistré et l'erreur est affichée

# Journal
Scénario: CA-11 noter un échange
  Quand un membre note un appel, résultat positif, avec une note
  Alors l'échange apparaît en tête du journal avec son auteur et sa date

Scénario: CA-12 le journal est en ajout seul
  Alors aucune adresse ne permet de modifier ou supprimer un échange

# Relances
Scénario: CA-13 créer et terminer une relance
  Quand un membre crée une relance pour demain, destinataire lui-même
  Alors elle apparaît dans « Mes relances »
  Quand il la marque « Faite »
  Alors elle quitte les relances ouvertes

Scénario: CA-14 relance d'un destinataire indisponible
  Étant donné une relance ouverte dont le destinataire a été anonymisé
  Alors un admin la voit marquée « destinataire indisponible » et peut la réattribuer
  Et un membre field qui n'est pas responsable de l'école ne peut pas la réattribuer

# À relancer (règle calculée)
Scénario: CA-15 signal « relance échue »
  Étant donné une relance ouverte à échéance hier
  Alors l'école figure dans « À relancer » avec la raison « Relance échue »

Scénario: CA-16 signal « perte d'usage »
  Étant donné une école active il y a 20 jours et inactive depuis
  Alors elle figure dans « À relancer » avec la raison « Perte d'usage »

Scénario: CA-17 signal « démo sans suite »
  Étant donné une école « Démo faite » sans échange depuis 8 jours
  Alors elle figure dans « À relancer » avec la raison « Démo sans suite »

Scénario: CA-18 signal « inscrite sans démarrage »
  Étant donné une école dont le premier enseignant est rattaché depuis 15 jours, sans aucune activité
  Alors elle figure dans « À relancer » avec la raison « Inscrite sans démarrage »

Scénario: CA-19 exclusions
  Étant donné une école désactivée, ou « Perdue » sans usage
  Alors elle ne figure jamais dans « À relancer »

Scénario: CA-20 carte de l'Accueil
  Étant donné trois écoles à relancer dont deux ont pour responsable le membre connecté
  Alors la carte « À relancer » de son Accueil en compte 2 et mène à l'onglet « À relancer » de la page « Relances »

# Pipeline
Scénario: CA-21 filtrer la liste par étape et responsable
  Quand un membre filtre « Établissements » par étape « Démo faite » et responsable « Moi »
  Alors seules ses écoles en « Démo faite » sont listées, avec la colonne « Étape »
  Et l'adresse porte les deux filtres

# Assistants
Scénario: CA-22 fiche de briefing
  Étant donné le modèle simulé
  Quand un membre clique « Préparer l'appel »
  Alors une fiche de 5 lignes au plus s'affiche dans le bloc « Suivi »
  Et un second clic sans nouvel échange ne rappelle pas le modèle

Scénario: CA-23 assistant non configuré
  Étant donné aucune clé OpenRouter
  Alors les boutons des assistants sont remplacés par « Assistant non configuré »

Scénario: CA-24 assistant en erreur
  Étant donné le modèle simulé en échec
  Quand un membre demande un briefing
  Alors il voit « L'assistant n'a pas répondu » et peut réessayer

Scénario: CA-25 compte rendu dicté
  Étant donné le modèle simulé qui rend un compte rendu structuré
  Quand un membre envoie un enregistrement de 40 secondes
  Alors le formulaire « Noter un échange » s'ouvre pré-rempli
  Et rien n'est enregistré tant qu'il ne valide pas
  Et l'enregistrement audio est supprimé après traitement

Scénario: CA-26 enregistrement refusé
  Quand un membre envoie un fichier de 12 Mo ou au format audio/wav
  Alors il est refusé sans appel au modèle

Scénario: CA-27 réponse inexploitable
  Étant donné le modèle simulé qui rend un texte non structuré
  Alors le formulaire est pré-rempli avec la seule transcription dans la note

Scénario: CA-28 brouillon de relance WhatsApp
  Quand un membre clique « Rédiger un message » sur une relance
  Alors un brouillon de 600 caractères au plus s'affiche avec « Copier » et « Ouvrir dans WhatsApp »
  Et aucun message n'est envoyé par l'application

Scénario: CA-29 rapport pédagogique
  Étant donné une école avec de l'activité sur 30 jours
  Quand un membre prépare le rapport pédagogique
  Alors une page imprimable montre élèves actifs, taux de rendu des devoirs, réussite par matière, 5 lacunes les plus fréquentes, et un texte de synthèse

Scénario: CA-30 rapport sans donnée
  Étant donné une école sans activité sur 30 jours
  Alors le rapport affiche « Pas encore assez d'activité » sans appeler le modèle
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Contexte `crm`. Entités : `Account` (étape saisie, responsable, motif de perte), `Stage` (résolution de l'étape affichée, pure), `Contact`, `Interaction`, `FollowUp`, `FollowUpSignals` (règle « À relancer », pure), `Generation`. Ports : comptes, contacts, échanges, relances, générations, `LanguageModelPort`. Use cases : `SetStage`, `AssignOwner`, `AddContact`, `ArchiveContact`, `RecordInteraction`, `ScheduleFollowUp`, `CompleteFollowUp`, `ReassignFollowUp`, `RequestBriefing`, `RequestPedagogyReport`, `RequestWhatsappDraft`, `SubmitDictation`. Policy : `ManageCrmPolicy` |
| Infrastructure | Tables `crm_accounts`, `crm_contacts`, `crm_interactions`, `crm_follow_ups`, `crm_generations` (+ pièce audio Active Storage). `Orm::CrmAccount`, `Orm::CrmContact`, `Orm::CrmInteraction`, `Orm::CrmFollowUp`, `Orm::CrmGeneration` (fichiers à plat dans `app/infrastructure/orm/`, comme l'existant), repositories. Queries : usage par école (comptes, dernière activité, premier rattachement), membres assignables, « À relancer », pédagogie d'une école. Adaptateur OpenRouter (Net::HTTP), jobs de génération |
| Delivery | `config/routes/teams.rb` (adresses du suivi sous `/teams/schools/:public_id/…` et `/teams/follow-ups`). Contrôleurs `Teams::Crm::*`. Filtres `stage`, `owner` sur `Teams::SchoolsController#index` |
| UI | Bloc « Suivi » de la fiche (frame paresseux), colonne et filtres de la liste, carte « À relancer » de l'Accueil, page « Mes relances », panneaux des assistants, page imprimable du rapport, contrôleur Stimulus d'enregistrement vocal |

## 6. Décisions rattachées

- ADR-XXXX-contexte-crm-suivi-des-ecoles — nouveau contexte borné, tables, étape calculée, policy, journal d'audit.
- ADR-XXXX-modeles-de-langage-par-openrouter — port des modèles, adaptateur OpenRouter sans nouvelle gemme, générations asynchrones, enregistrement vocal.
- UDR-XXXX-bloc-suivi-de-la-fiche-etablissement — bloc « Suivi » de la fiche.
- UDR-XXXX-pipeline-et-relances — filtres et colonne de la liste, carte de l'Accueil, page « Mes relances ».
- UDR-XXXX-assistants-du-suivi — briefing, compte rendu dicté, brouillon WhatsApp, rapport pédagogique.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL du bloc « Suivi » | — | constant quel que soit le nombre d'échanges | |
| Requêtes SQL de « Mes relances » | — | constant quel que soit le nombre d'écoles | |
| Temps d'une fiche de briefing (p50) | — | < 10 s | |
