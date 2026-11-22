# PRD — Hors connexion total après installation

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Aujourd'hui, l'élève hors ligne ne retrouve que les pages qu'il a déjà ouvertes (ADR-0133). Une fois l'application installée, il doit pouvoir lire tout le catalogue auquel il a droit : son niveau d'abord, le reste en Wi-Fi ou sur demande. Il doit aussi pouvoir faire exercices et entraînements de notion, images comprises. L'enseignant relit hors ligne les pages déjà ouvertes de ses classes, donne ou archive un devoir et règle ses jours de cours ; tout part au retour du réseau, le serveur restant seul juge ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Télécharger les leçons, exercices, corrigés, entraînements et images **auxquels il a droit** (accès Billing), son niveau en premier ; les lire hors ligne ; faire un exercice ou un entraînement hors ligne, avec une note provisoire ; envoyer ses copies au retour du réseau, corrigées sur la version qu'il a eue | Télécharger du contenu payant sans accès ; lire hors ligne du contenu payant après la date de fin d'accès connue ; voir le contenu gardé pour un autre compte auquel il n'a pas droit |
| Teacher | Relire hors ligne les pages de ses classes **déjà ouvertes** (accueil, classe, fiche d'un élève, suivi d'un devoir, résultat d'une copie) ; hors ligne : donner un devoir (seul ou en lot), archiver un devoir, régler ses jours de cours ; voir sa file d'envoi et ses refus | Télécharger d'avance les données de ses élèves ; retirer un élève ou changer le lien d'invitation hors ligne ; écrire hors ligne sur une classe qu'il ne tient plus à la réception |
| Team, SchoolStaff, Parent | Rien de nouveau | Rien hors ligne (inchangé, ADR-0133) |

Règles d'autorisation, **rejouées par le serveur à la réception** : `StartSessionPolicy` et `StudentAccessPort` (copies) ; `AssignPolicy` et `SetSessionDaysPolicy` (écritures de l'enseignant), dans les use cases existants `AssignResource`, `AssignExerciseBatch`, `ArchiveAssignment`, `SetSessionDays`.

## 3. Parcours utilisateur

### Chemin nominal — élève

1. L'élève installe l'application et l'ouvre connecté.
2. Une carte « Hors connexion » de l'accueil lui annonce la taille de son niveau et la place libre, puis lance le téléchargement : en Wi-Fi tout de suite ; en données mobiles seulement s'il touche « Télécharger quand même ».
3. La progression s'affiche (« 34 / 61 leçons · 18 Mo sur 52 Mo ») ; il peut mettre en pause et reprendre.
4. Son niveau fini, le reste du catalogue auquel il a droit se télécharge en Wi-Fi seulement, ou sur demande (« Télécharger tout le reste »).
5. Sans réseau, il ouvre n'importe quelle leçon téléchargée, ses images, un exercice (« Commencer » mène à la copie hors ligne) ou un entraînement de notion ; il voit sa note « provisoire ».
6. Au retour du réseau, ses copies partent. Le serveur les corrige sur la version que l'élève a eue, et la liste du catalogue est mise à jour : leçons modifiées retéléchargées, leçons retirées effacées.

### Chemin nominal — enseignant

1. En ligne, il ouvre ses classes ; ces pages sont gardées (Lot D de l'ADR-0133).
2. Hors ligne, il donne un devoir, l'archive ou règle ses jours de cours. L'action entre dans sa file (« 2 actions à envoyer »), et la page montre l'état attendu avec la mention « en attente d'envoi ».
3. Au retour du réseau, la file part. Chaque action est rejouée par son use case, et le devoir porte « donné hors ligne le …, arrivé le … ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Place libre insuffisante pour le niveau | Le téléchargement ne démarre pas ; message « Il faut 52 Mo, il en reste 20 sur ce téléphone » ; rien n'est écrit |
| Téléchargement coupé (réseau, application fermée) | Il reprend au prochain lancement, sans retélécharger ce qui est déjà gardé et à jour |
| Données mobiles, l'élève n'a pas accepté | Rien ne part ; la carte propose « Télécharger quand même » |
| Navigateur sans information de réseau (Safari) | Traité comme « données mobiles » : l'élève accepte une fois, son choix est retenu sur l'appareil |
| Abonnement expiré, hors ligne | Le contenu payant est masqué au-delà de la date de fin d'accès ; la page montre « Accès terminé le … » ; le gratuit reste lisible |
| Abonnement expiré, retour du réseau | Le contenu payant est effacé de l'appareil, sauf s'il sert encore à un autre compte de l'appareil qui y a droit |
| Deuxième compte sur l'appareil, sans accès au payant | Il ne voit aucune page payante gardée pour le premier compte ; sa liste ne porte que ce à quoi il a droit |
| Déconnexion | Les leçons communes restent ; corrigés, copies envoyées, pages de compte et liste du compte sont effacés ; la file non envoyée est gardée 30 jours, jamais envoyée sous un autre compte (ADR-0133) |
| Aucun compte connecté, hors ligne | Seule la page « Pas de connexion » s'affiche |
| Exercice modifié pendant la copie hors ligne | La copie est corrigée sur la version reçue, gardée 30 jours |
| Version reçue gardée depuis plus de 30 jours | Copie refusée, motif « exercice modifié depuis plus de 30 jours » |
| Leçon dépubliée | Effacée au retour du réseau ; une copie faite dessus est refusée (`forbidden`) |
| Devoir donné hors ligne sur une classe archivée ou une classe que l'enseignant ne tient plus | Refusé à la réception ; montré « non envoyé » avec son motif, gardé 30 jours |
| Même action envoyée deux fois | Exécutée une fois ; le second envoi rend le premier résultat |
| Retirer un élève ou changer le lien hors ligne | Le bouton est désactivé hors ligne, avec « Disponible avec du réseau » |

## 4. Critères d'acceptation

```gherkin
# CA-1 Liste du catalogue filtrée par l'accès
Étant donné un élève de 3e sans accès au payant et un catalogue avec des leçons gratuites et payantes
Quand l'appareil demande la liste du catalogue
Alors la liste ne contient que les leçons auxquelles il a droit
Et chaque entrée porte sa version et sa taille
Et les leçons de 3e viennent en premier
Et la réponse est marquée no-store

# CA-2 Date de fin d'accès
Étant donné un élève abonné jusqu'au 30 novembre
Quand l'appareil demande la liste du catalogue
Alors la liste porte la date de fin d'accès du 30 novembre

# CA-3 Liste refusée hors rôle
Étant donné un enseignant, un membre de l'équipe ou un visiteur non connecté
Quand il demande la liste du catalogue
Alors il reçoit un refus et aucune leçon

# CA-4 Pages de leçon neutres
Étant donné une leçon demandée pour le téléchargement
Quand le serveur rend la page
Alors elle ne contient ni nom d'élève, ni progression, ni note, ni clé d'appareil
Et elle porte l'en-tête Lnclass-Offline: catalog

# CA-5 Téléchargement priorisé, reprise et pause
Étant donné une liste de 3 leçons de 3e et 2 leçons d'autres niveaux
Quand le téléchargement tourne en Wi-Fi
Alors les 3 leçons de 3e sont gardées avant les autres
Et une coupure puis une reprise ne retélécharge pas une leçon déjà gardée à la même version
Et une pause arrête toute nouvelle demande

# CA-6 Données mobiles
Étant donné un appareil en données mobiles et un élève qui n'a pas accepté
Quand la carte s'affiche
Alors aucune leçon n'est demandée
Et le bouton « Télécharger quand même » lance le téléchargement du niveau

# CA-7 Place insuffisante
Étant donné une place libre inférieure à la taille du niveau
Quand l'élève lance le téléchargement
Alors rien n'est demandé et le message donne la taille et la place libre

# CA-8 Lecture hors ligne d'une leçon jamais ouverte
Étant donné une leçon téléchargée jamais ouverte et un élève connecté qui y a droit
Quand il l'ouvre sans réseau
Alors la page et ses images s'affichent

# CA-9 Filtre par compte sur un appareil partagé
Étant donné une leçon payante gardée pour un compte abonné
Quand un autre compte sans accès l'ouvre sans réseau sur le même appareil
Alors il voit la page « Pas de connexion » et non la leçon

# CA-10 Fin d'accès hors ligne
Étant donné une leçon payante gardée et une date de fin d'accès passée
Quand l'élève l'ouvre sans réseau
Alors il voit « Accès terminé le … » et non la leçon

# CA-11 Purge au retour du réseau
Étant donné une leçon gardée qui n'est plus dans la liste du compte et d'aucun autre compte de l'appareil
Quand la liste est relue au retour du réseau
Alors la leçon, ses images et ses corrigés sont effacés

# CA-12 Déconnexion
Étant donné un élève qui a téléchargé son niveau et a une copie non envoyée
Quand il se déconnecte
Alors les leçons communes restent sur l'appareil
Et ses corrigés, ses pages de compte et sa liste sont effacés
Et sa copie non envoyée est gardée sous sa clé

# CA-13 Corrigés en lot, livraison tracée
Étant donné un élève qui a droit à 40 exercices
Quand l'appareil demande les jetons de corrigé du lot
Alors il reçoit un jeton signé par exercice à son nom
Et chaque remise est enregistrée comme une remise de paquet (ADR-0133 §4.4)
Et un exercice auquel il n'a pas droit n'a pas de jeton

# CA-14 Version gardée
Étant donné un exercice dont un paquet a été servi à la version V1
Quand l'exercice passe à la version V2
Alors la version V1 reste lisible par le serveur pendant 30 jours

# CA-15 Copie corrigée sur l'ancienne version
Étant donné une copie hors ligne faite sur V1 et un exercice passé en V2 il y a 3 jours
Quand la copie est envoyée
Alors elle est corrigée selon V1 et comptée

# CA-16 Ancienne version expirée
Étant donné une copie faite sur V1 et une V1 remplacée il y a 31 jours
Quand la copie est envoyée
Alors elle est refusée avec le motif « version expirée »

# CA-17 Entraînement de notion hors ligne
Étant donné un entraînement de notion téléchargé
Quand l'élève y répond sans réseau
Alors ses réponses sont corrigées sur l'appareil avec la même table de cas que le serveur
Et rien n'est envoyé au serveur

# CA-18 Images
Étant donné une image de question publiée d'une leçon téléchargée
Quand le téléchargement passe
Alors elle est gardée
Et une image non publiée (no-store), une photo de profil ou un fichier de message ne l'est jamais

# CA-19 Pages de l'enseignant gardées
Étant donné un enseignant connecté
Quand il ouvre son accueil, une classe, la fiche d'un élève, le suivi d'un devoir ou le résultat d'une copie
Alors la page porte Lnclass-Offline: keep
Et aucune autre page de l'enseignant ne le porte

# CA-20 Devoir donné hors ligne
Étant donné un enseignant hors ligne sur la page « Donner un devoir » d'une classe qu'il tient
Quand il valide
Alors l'action entre dans sa file
Et au retour du réseau AssignResource crée le devoir une seule fois
Et le devoir porte son heure d'origine et son heure de réception

# CA-21 Écritures rejouées avec leurs droits
Étant donné un devoir donné hors ligne sur une classe archivée entre-temps
Quand l'action est envoyée
Alors elle est refusée avec son motif et aucun devoir n'est créé

# CA-22 Idempotence des actions
Étant donné une action déjà reçue
Quand elle est envoyée une seconde fois
Alors aucun effet nouveau n'a lieu et le premier résultat est rendu

# CA-23 Action d'un autre compte
Étant donné une action rangée sous la clé d'un enseignant A
Quand un enseignant B se connecte sur l'appareil
Alors l'action n'est jamais envoyée sous le compte B

# CA-24 Actions en ligne seulement
Étant donné un enseignant hors ligne sur la page d'une classe
Alors « Retirer de la classe » et « Changer le lien » sont désactivés avec « Disponible avec du réseau »

# CA-25 Jours de cours hors ligne
Étant donné un enseignant hors ligne qui règle ses jours de cours deux fois
Quand la file part
Alors les deux actions sont rejouées dans l'ordre et le dernier réglage est celui gardé
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Port `Ports::Catalog::OfflineCatalogPort` (liste filtrée) ; port `Ports::Assessment::ExerciseVersionRepositoryPort` (versions gardées 30 jours) ; port `Ports::Shared::OfflineActionReceiptPort` (idempotence des actions) ; use case `UseCases::Assessment::IssueOfflinePacks` (jetons en lot + remises) ; use case `UseCases::Classroom::SyncOfflineAction` (aiguille vers les use cases existants) ; `SyncOfflineCopy` amendé (version gardée au lieu de `stale`) ; `Entities::Billing::Access#ends_on` |
| Infrastructure | Migrations : `exercise_versions` (exercise_id, digest, questions jsonb, first_served_at, superseded_at ; unique exercise_id + digest) ; `offline_action_receipts` (user_id, client_action_id uuid, kind, result jsonb ; unique user_id + client_action_id) ; `assignments.made_offline_at`, `assignments.received_at`. Query `Queries::Catalog::OfflineCatalogQuery` ; repositories des deux ports |
| Delivery | `GET /offline/catalog` (JSON, no-store, élève) ; `POST /offline/packs` (jetons en lot, JSON, no-store, 30/min) ; `POST /offline/actions` (JSON, enseignant, 30/min, 20 actions au plus) ; rendu neutre `Lnclass-Offline: catalog` (concern `OfflineKeepable` étendu) sur leçon, sujet, copie hors ligne, entraînement ; `keep_offline` sur les pages enseignant du Lot D |
| UI | Programme d'arrière-plan : caches `lnclass-catalog-v1` (pages communes), `lnclass-media-v1` (images), filtre par la liste du compte ; Stimulus `offline-download`, `offline-actions` ; carte « Hors connexion » de l'accueil élève ; file de l'enseignant ; entraînement hors ligne (`grader.js` étendu) |

## 6. Décisions rattachées

- ADR-XXXX-hors-connexion-total-catalogue-telecharge — amende l'ADR-0133 (§1 « rien n'est téléchargé d'avance », §4.3, §4.5 `stale`, §4.6) et l'ADR-0119 §4.
- UDR-XXXX-hors-connexion-telechargement-et-file-enseignant — carte « Hors connexion » de l'élève, file et mentions de l'enseignant.
- Menace : [`menace.md`](menace.md).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons lisibles hors ligne après installation, sans visite préalable | 0 | toutes celles du niveau, puis toutes celles auxquelles le compte a droit | |
| Copies hors ligne refusées pour exercice modifié (`stale`) | refusées | 0 sous 30 jours | |
| Poids téléchargé pour un niveau (texte + images) | — | mesuré au Lot A, annoncé à l'élève | |
| Programme d'arrière-plan : navigation en ligne | réseau d'abord | inchangé (aucune page en ligne servie depuis le cache) | |
