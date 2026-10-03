# PRD — Annonces ciblées, programmables et écartables

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass n'a aucun moyen de faire passer une information à ses utilisateurs ([memo](memo.md)). Ce chantier donne la parole à trois auteurs (l'équipe, la direction, l'enseignant), chacun pour une audience bornée, sous la forme de cartes courtes et signées que l'élève lit sur son accueil et que les adultes lisent dans une page « Annonces ». Il applique l'[ADR-0045](../../decisions/adr/0045-annonces-publication-programmee-et-audience.md), amendé par l'[ADR-0069](../../decisions/adr/0069-annonces-trois-auteurs-classes-ciblees-et-retrait.md) pour ce que le grill a changé.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Team** (tout sous-rôle) | Rédiger, programmer, modifier, archiver **ses** annonces, nationales ou pour **un** établissement, audience `all`, `students`, `teachers` ou `school_admins`. Voir toutes les annonces. **Retirer** n'importe quelle annonce d'un autre auteur | Modifier l'annonce d'un autre auteur. Cibler des classes. Masquer une annonce |
| **Direction** (`school_admin`) | Rédiger, programmer, modifier, archiver **ses** annonces, pour **son** établissement seulement, audience `students`, `teachers` ou `school_admins`. Lire celles qui lui sont destinées. Voir et **retirer** les annonces des enseignants de son établissement | Publier pour un autre établissement ou au national. Audience `all`. Modifier l'annonce d'un collègue de direction. Retirer une annonce de l'équipe ou d'une autre direction |
| **Teacher** | Rédiger, programmer, modifier, archiver **ses** annonces, pour une ou plusieurs des classes **actives où il enseigne**. Lire celles qui lui sont destinées | Cibler une classe où il n'enseigne pas. Cibler un rôle. Retirer une annonce |
| **Student** | Lire les annonces publiées qui lui sont destinées (carrousel de l'accueil, page « Toutes les annonces »), écouter leur audio, **masquer** une annonce non officielle et annuler ce masquage | Publier. Masquer une annonce officielle. Lire une annonce hors de son audience, non publiée, terminée, archivée ou retirée — ni ses fichiers |
| **Visiteur** | — | Tout : renvoyé vers « Se connecter » |

**Annonce officielle** : toute annonce dont l'auteur est une direction. Elle porte un badge vérifié et ne peut pas être masquée.

**Règles d'autorisation** (ADR-0069 §6) : `Policies::Communication::PublishPolicy` (rédiger, et pour qui), `Policies::Communication::ManageOwnPolicy` (modifier, programmer, archiver : l'auteur seul), `Policies::Communication::WithdrawPolicy` (retirer), `Policies::Communication::ReadFilePolicy` (servir l'image ou l'audio d'une annonce), `Policies::Communication::DismissPolicy` (masquer). La lecture des listes n'a pas de policy à part : elle passe par la **seule** définition SQL de la règle ci-dessous (`Queries::Communication::ReadableMessages`), que `ReadFilePolicy` consulte aussi.

### Règle de lecture (la seule, partagée par la query, la policy et le service des fichiers)

Une annonce est lisible par un acteur si **toutes** ces conditions tiennent :

1. Elle est `published`, sa date de publication est passée, et sa **date de fin** ne l'est pas.
2. Son audience couvre l'acteur :
   - annonce **par rôle** (équipe, direction) : l'audience vaut `all` ou le rôle de l'acteur (`students`, `teachers`, `school_admins`), **et** l'annonce est nationale ou porte l'établissement de l'acteur ;
   - annonce **par classes** (enseignant) : l'acteur est un élève, et sa classe principale active fait partie des classes ciblées.
3. L'établissement de l'acteur est : pour un élève, celui de sa classe principale active (ADR-0040) ; pour un enseignant, son établissement principal (ADR-0030) ; pour une direction, celui de son rattachement (ADR-0065). Sans établissement, l'acteur ne lit que les annonces nationales.

L'équipe lit tout. L'auteur lit toujours ses propres annonces, quel que soit leur état. La direction lit les annonces des enseignants de son établissement, pour pouvoir les retirer.

## 3. Parcours utilisateur

### Chemin nominal — un enseignant prévient ses classes

1. M. Kouassi (SVT) ouvre « Annonces » dans sa navigation, onglet « Mes annonces », et choisit « Nouvelle annonce ».
2. Il saisit un titre (60 caractères au plus) et un texte court (140 caractères au plus), choisit une illustration dans la bibliothèque, coche « 3ème B » et « 3ème C » parmi ses classes, joint un fichier audio de 2 min qui détaille, et garde la date de fin proposée (dans 30 jours).
3. Il publie maintenant. L'annonce apparaît dans « Mes annonces » avec le statut « Publiée ».
4. Awa, élève de 3ème B, ouvre son accueil : la carte « M. Kouassi · SVT — Nouvelles fiches » est dans le carrousel, après les annonces de la direction. Elle appuie sur ▶ : l'audio se télécharge et se lit.
5. Elle masque la carte par la croix ; le toast « Message masqué · Annuler » s'affiche 5 s. Sur son autre téléphone, la carte n'est plus dans le carrousel, mais reste dans « Toutes les annonces », marquée « Masquée ».

### Autres chemins nominaux

| Acteur | Parcours |
|---|---|
| Direction | « Annonces » → « Nouvelle annonce » : audience parmi Élèves / Enseignants / Directions de son établissement. Sa carte est signée « Mme Kamaté · Direction », badge vérifié, sans croix. Onglet « Enseignants » : les annonces des enseignants de son établissement, chacune avec « Retirer » |
| Équipe | « Annonces » → « Nouvelle annonce » : portée Nationale ou un établissement (recherche), audience Tous / Élèves / Enseignants / Directions. Signée « Lnclass ». Onglet « Toutes » : toutes les annonces publiées, filtrables par établissement, chacune avec « Retirer » |
| Tout auteur | Programmer : une date de publication future ; l'annonce est « Programmée » et paraît dans les 5 minutes qui suivent l'heure dite. Modifier une annonce publiée : elle revient chez ceux qui l'avaient masquée, marquée « Modifiée ». Archiver : elle disparaît pour tous, définitivement |
| Enseignant, direction | Onglet « Reçues » : les annonces qui leur sont destinées, plus récentes d'abord |

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Titre > 60 ou texte > 140 caractères, titre ou texte vide | Formulaire réaffiché (422), erreur sous le champ, rien n'est créé |
| Aucune classe cochée (enseignant), ou classe où il n'enseigne pas (requête forgée) | 422 « Choisis au moins une de tes classes. » ; classe forgée : refus, rien n'est créé |
| Direction qui force un autre établissement, la portée nationale ou l'audience `all` | Refus, rien n'est créé |
| Date de publication passée, date de fin avant la publication ou à plus de 90 jours d'elle | 422, erreur sous le champ |
| Image hors png/jpeg/webp ou > 2 Mo ; audio hors mp3/m4a ou > 10 Mo ; fichier déguisé | 422 « Ce fichier n'est pas accepté. » / « Ce fichier est trop lourd (2 Mo au plus). » — type lu dans le contenu |
| Modifier ou archiver l'annonce d'un autre auteur | 404 (l'annonce n'existe pas pour lui) — l'équipe et la direction comprises |
| Modifier une annonce retirée ou archivée | Refus : elle est figée |
| Retirer hors de son droit (enseignant ; direction sur une autre école ou sur l'équipe) | 404 |
| Masquer une annonce officielle (requête forgée) | Refus, aucun rejet enregistré |
| Fichier d'une annonce hors audience, non publiée, terminée, archivée ou retirée | 404 |
| Visiteur sur une page ou un fichier d'annonce | Renvoyé vers « Se connecter » |
| Audio non lisible par le téléphone | « Audio indisponible sur ce téléphone. » dans la carte, annoncé (`aria-live`) |

## 4. Critères d'acceptation

```gherkin
# AN-01 — Lots A et B
Étant donné le membre de l'équipe Fatou
Quand elle publie maintenant l'annonce nationale « Rentrée numérique » pour l'audience « Tous »
Alors un élève, un enseignant et une direction de deux établissements différents la lisent
Et chez l'élève, la carte est signée « Lnclass »

# AN-02 — Lots A et B
Étant donné l'équipe publie « Concours de maths » pour le « Collège Les Lauriers », audience « Élèves »
Alors les élèves de ce collège la lisent
Et ni ses enseignants, ni ses directions, ni les élèves du « Lycée de Bouaké » ne la lisent

# AN-03 — Lots A et B
Étant donné Mme Kamaté, direction du « Collège Les Lauriers »
Quand elle publie « Devoirs communs » pour l'audience « Élèves »
Alors les élèves de son collège la lisent, signée « Mme Kamaté · Direction », avec le badge officiel et sans croix
Et les élèves du « Lycée de Bouaké » ne la lisent pas

# AN-04 — Lot A
Étant donné Mme Kamaté
Quand elle envoie une annonce pour le « Lycée de Bouaké », pour la portée nationale, ou pour l'audience « Tous »
Alors aucune annonce n'est créée

# AN-05 — Lots A et B
Étant donné M. Kouassi, enseignant de SVT en 3ème B et 3ème C au « Collège Les Lauriers »
Quand il publie « Nouvelles fiches » pour la 3ème B et la 3ème C
Alors les élèves dont la classe principale active est la 3ème B ou la 3ème C la lisent, signée « M. Kouassi · SVT », avec une croix
Et les élèves de 3ème A, les enseignants et la direction du collège ne la lisent pas dans « Reçues »

# AN-06 — Lot A
Étant donné M. Kouassi
Quand il envoie une annonce ciblant la 3ème A, où il n'enseigne pas, ou aucune classe
Alors aucune annonce n'est créée
Et un élève qui demande le formulaire ou l'envoi d'une annonce reçoit 403

# AN-07 — Lot A
Étant donné une annonce programmée pour 10 h 00 et une autre pour 18 h 00
Quand la publication des annonces programmées tourne à 10 h 05
Alors la première est publiée et l'événement « message.published » est journalisé
Et la seconde reste programmée et illisible par son audience

# AN-08 — Lots A et B
Étant donné une annonce publiée le 1er octobre sans date de fin choisie
Alors sa date de fin est le 31 octobre
Et le 31 octobre, elle n'est plus lisible par son audience, ni dans le carrousel, ni dans la liste, ni par ses fichiers
Et son auteur la voit « Terminée » dans « Mes annonces »
Et une date de fin au 1er octobre ou au 31 décembre est refusée

# AN-09 — Lot B
Étant donné une annonce de M. Kouassi pour la 3ème B, avec une image et un audio
Quand un élève de 3ème A demande l'image ou l'audio par leur adresse
Alors il reçoit 404
Et il reçoit aussi 404 avant la publication, après la date de fin, après l'archivage et après un retrait
Et un élève de 3ème B, M. Kouassi et l'équipe reçoivent le fichier

# AN-10 — Lot B
Étant donné un élève de 3ème B destinataire de 6 annonces publiées : 1 de la direction, 3 de ses enseignants, 2 de l'équipe
Quand il ouvre son accueil
Alors le carrousel montre 5 cartes : la direction, puis les 3 enseignants de la plus récente à la plus ancienne, puis la plus récente de l'équipe
Et un lien « Toutes les annonces » ouvre la liste des 6

# AN-11 — Lot B
Étant donné un élève destinataire d'aucune annonce
Quand il ouvre son accueil
Alors aucune bande d'annonces n'est rendue
Et la page « Toutes les annonces » affiche « Aucune annonce pour le moment. »

# AN-12 — Lot B
Étant donné Awa, élève de 3ème B, et l'annonce « Nouvelles fiches » de M. Kouassi
Quand elle la masque
Alors elle n'est plus dans son carrousel, y compris dans une autre session
Et elle est dans « Toutes les annonces », marquée « Masquée »
Et si Awa choisit « Annuler », l'annonce revient dans le carrousel

# AN-13 — Lot B
Étant donné l'annonce officielle « Devoirs communs » de Mme Kamaté
Alors sa carte n'a pas de croix
Et une demande de masquage forgée est refusée sans enregistrer de rejet

# AN-14 — Lot A
Étant donné Awa a masqué « Nouvelles fiches »
Quand M. Kouassi modifie son texte
Alors la carte revient dans le carrousel d'Awa, marquée « Modifiée »

# AN-15 — Lot A
Étant donné « Devoirs communs » de Mme Kamaté
Quand M. Diallo, autre direction du même collège, l'équipe, ou M. Kouassi demandent à la modifier ou à l'archiver
Alors ils reçoivent 404 et l'annonce est inchangée

# AN-16 — Lot C
Étant donné l'annonce « Nouvelles fiches » de M. Kouassi
Quand Fatou (équipe) la retire
Alors plus aucun élève ne la lit, ni ses fichiers
Et l'événement « message.withdrawn » est journalisé avec Fatou pour auteur
Et M. Kouassi la voit « Retirée » dans « Mes annonces », sans pouvoir la modifier ni la republier

# AN-17 — Lot C
Étant donné Mme Kamaté, direction du « Collège Les Lauriers »
Alors elle peut retirer l'annonce d'un enseignant de son collège
Et elle reçoit 404 pour l'annonce d'un enseignant du « Lycée de Bouaké », pour une annonce de l'équipe et pour celle de M. Diallo
Et M. Kouassi reçoit 404 en voulant retirer l'annonce d'un collègue

# AN-18 — Lot A (validation) et Lot B (affichage)
Étant donné un auteur qui joint des fichiers
Quand il joint un PDF renommé « affiche.png », une image de 3 Mo, un fichier « .wav » ou un audio de 12 Mo
Alors l'annonce n'est pas enregistrée et l'erreur nomme le fichier refusé
Et une image png de 500 Ko remplace l'illustration dans la carte
Et une carte sans audio n'a pas de bouton ▶

# AN-19 — Lots A et B
Étant donné une annonce publiée de son auteur
Quand il l'archive
Alors elle n'est plus lisible par personne d'autre que lui et l'équipe
Et elle ne peut plus être modifiée ni republiée

# AN-20 — Lot 0 (entité) et Lot B (affichage)
Étant donné un auteur
Quand il saisit un titre de 61 caractères, un texte de 141 caractères, ou un texte vide
Alors l'annonce n'est pas enregistrée
Et un texte « <script>alert(1)</script> » publié s'affiche tel quel, sans être interprété

# AN-21 — Lot B
Étant donné un élève sans classe active, puis un élève passé de la 3ème B à la 4ème A
Alors le premier ne lit que les annonces nationales pour « Tous » ou « Élèves »
Et le second ne lit plus « Nouvelles fiches » (3ème B), mais lit les annonces valides ciblant la 4ème A

# AN-22 — Lot D (navigation) et Lot B (lien de l'élève)
Étant donné un enseignant, une direction et un membre de l'équipe connectés
Alors leur navigation comporte « Annonces »
Et la navigation de l'élève ne la comporte pas, mais son carrousel mène à « Toutes les annonces »
Et un visiteur qui demande une page d'annonces est renvoyé vers « Se connecter »

# AN-23 — Lot 0 (routes) et Lot A
Étant donné une direction connectée
Alors les routes d'écriture des annonces lui sont ouvertes
Et toute route sous /school-admin reste en GET seulement (DS-11, inchangé)
```

Chaque critère a son test ; la règle de lecture du §2 a en plus un test de query par condition, et chaque policy un test de refus par acteur.

## 5. Modélisation préliminaire

Détail et code : [ADR-0069 §6](../../decisions/adr/0069-annonces-trois-auteurs-classes-ciblees-et-retrait.md#6-notes-dimplémentation). Contexte borné : **`communication`** (créé par ce chantier).

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Communication::Message`, `Reader`, `AudioHeader` ; `Dtos::Communication::MessageInput` ; ports `MessageRepositoryPort`, `DismissalRepositoryPort`, `AttachmentStorePort`, `ReadableMessagesPort` ; policies `PublishPolicy`, `ManageOwnPolicy`, `WithdrawPolicy`, `DismissPolicy`, `ReadFilePolicy` ; use cases `CreateMessage`, `UpdateMessage`, `ArchiveMessage`, `WithdrawMessage`, `DismissMessage`, `RestoreMessage`, `ReadMessageFile`, `PublishScheduledMessages` ; `AuditAction::ALL` + `message.published`, `message.withdrawn` |
| Infrastructure | migrations `messages`, `message_classrooms`, `message_dismissals` ; `Orm::Message`, `Orm::MessageClassroom`, `Orm::MessageDismissal` ; `Repositories::Communication::MessageRepository`, `DismissalRepository`, `AttachmentStore` ; `Queries::Communication::ReadableMessages` (la règle de lecture), `InboxQuery`, `AuthoredMessagesQuery`, `ModerationQuery` ; job `Communication::PublishScheduledMessagesJob` et `config/recurring.yml` |
| Delivery | `config/routes/communication.rb` ; `Communication::InboxesController`, `AuthoredMessagesController`, `MessageArchivesController`, `MessageDismissalsController`, `MessageFilesController`, `ModerationsController`, `MessageWithdrawalsController` ; `Classroom::StudentHomesController` (carrousel) |
| UI | UDR-0056 : `communication/messages/_card`, `_carousel`, illustrations, `communication/shared/_tabs`, pages « Reçues », « Mes annonces », « Enseignants » / « Toutes », formulaire ; contrôleurs Stimulus `communication--audio`, `communication--carousel` ; `ui_toast(action:)`, `ui_checkbox_group` ; entrées de navigation |

## 6. Décisions rattachées

- [ADR-0045](../../decisions/adr/0045-annonces-publication-programmee-et-audience.md) — annonces : job de publication, audience filtrée, rejets en base, pièces jointes validées *(accepté)*.
- [ADR-0069](../../decisions/adr/0069-annonces-trois-auteurs-classes-ciblees-et-retrait.md) — amende l'ADR-0045 (enseignant auteur, classes ciblées, date de fin, officiel, illustration, texte court sans page de détail, retrait, rejets effacés à la modification) et l'ADR-0065 (la direction écrit des annonces, hors de `/school-admin`). **À accepter avant le Lot 0.**
- [UDR-0056](../../decisions/udr/0056-annonces.md) — carrousel de l'accueil élève, page « Annonces », formulaire d'annonce, navigation ; amende l'UDR-0006 (navigation) et l'UDR-0052 (espace direction) ; écart assumé avec le design system Lnclass §10 (audio). **À accepter avant le Lot 0.**

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL pour le carrousel de l'accueil élève | — (bloc absent) | Nombre fixe, indépendant du nombre d'annonces (ADR-0067) | |
| Poids ajouté à l'accueil élève sans appui sur ▶ | — | 0 octet d'audio téléchargé (`preload="none"`) | |
