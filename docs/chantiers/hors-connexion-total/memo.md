# Memo — Hors connexion total après installation

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-22 |
| **Branche** | `feature/hors-connexion-total` |
| **Programme** | — *(suite du chantier `hors-connexion`, ADR-0133)* |

---

## Le problème

Une fois l'application installée, l'élève sans réseau ne retrouve que les pages qu'il a déjà ouvertes en ligne (ADR-0133). Une leçon jamais ouverte, une image, un entraînement de notion ou toute page de l'enseignant affichent « Pas de connexion ». Là où le réseau manque des jours entiers, l'application ne sert presque à rien hors ligne.

## Pour qui

- **Élève** : après l'installation, il lit tout le catalogue, fait exercices et entraînements, voit sa note provisoire ; tout part au retour du réseau.
- **Enseignant** : il relit hors ligne les pages déjà ouvertes de ses classes (rien n'est téléchargé d'avance pour lui), donne ou archive un devoir et règle ses jours de cours ; ses écritures partent au retour du réseau.

## Pourquoi maintenant

Décision du porteur du 2026-11-22 : passer du hors-ligne « pages ouvertes » au hors-ligne total. Le socle de l'ADR-0133 (clé d'appareil, purge, file, synchronisation des copies) est en production depuis le 2026-11-13.

## Hors périmètre

- Équipe, direction, parent : rien hors ligne (inchangé depuis l'ADR-0133).
- Identité (connexion, PIN, second facteur, profil), facturation : jamais hors ligne.
- Photos de profil et documents privés : jamais gardés.
- Enseignant : pas de téléchargement d'avance des données de ses élèves ; retirer un élève et changer le lien d'invitation restent en ligne.
- Apps Android Hotwire Native : chantier de suivi, recette sur un vrai appareil.
- Contenu payant auquel le compte n'a pas droit : jamais téléchargé.
- Annonces, badges et progression, archive des copies, « Mon compte » : pas hors ligne dans ce chantier (Q14, à trancher).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Décisions de départ (porteur, 2026-11-22) | Tout le catalogue téléchargé d'avance ; élève + enseignant **avec écriture** ; corrigé de l'entraînement de notion sur le téléphone ; images des leçons gardées | Amende l'ADR-0133 (« rien n'est téléchargé d'avance », enseignant lecture seule) et l'ADR-0119 (corrigé d'entraînement) |
| Mesure : poids du catalogue | 463 leçons, 98 Mo de JSON source, sans les images | Tout le catalogue sur chaque téléphone pèse plus de 100 Mo |
| Q1 — Comment télécharger 100 Mo et plus sur de petits téléphones aux forfaits limités ? | Son niveau d'abord, à l'installation ; le reste ensuite en Wi-Fi ou sur demande ; taille et progression affichées, pause possible | Téléchargement en deux temps ; un écran de téléchargement (UDR) ; détection Wi-Fi / données ; place libre vérifiée avant ; une liste du catalogue par niveau servie par le serveur |
| Q2 — Quelles écritures de l'enseignant hors ligne ? | Donner un devoir (seul ou en lot), l'archiver, régler ses jours de cours ; retirer un élève et changer le lien restent en ligne | Une seconde file d'envoi, pour l'enseignant ; le serveur rejoue chaque policy à la réception, comme pour les copies |
| Q3 — Conflit entre collègues sur les jours de cours ? | Impossible : chaque enseignant a les siens (confirmé dans le code) | Aucune règle de fusion pour les jours de cours : la dernière écriture de l'enseignant gagne |
| Q3 bis — Devoir donné hors ligne lundi, reçu jeudi ? | Créé à la réception, l'enseignant est prévenu. Un devoir n'a pas de date limite (vérifié), seulement des jours de cours | Le devoir porte son heure d'origine et son heure de réception ; l'enseignant voit « donné hors ligne le …, arrivé le … » |
| Q4 — Abonnement expiré ou absent ? | On ne télécharge que ce à quoi le compte a droit ; à l'expiration, le contenu payant s'efface au retour du réseau ; hors ligne, il reste lisible au plus jusqu'à la date de fin connue | La liste du catalogue est filtrée par le serveur selon l'accès Billing et porte la date de fin d'accès ; l'appareil cache le payant au-delà de cette date, même hors ligne |
| Q5 — Téléphone partagé : retélécharger à chaque changement de compte ? | Non : le texte et les images des leçons restent sur l'appareil ; tout ce qui est propre au compte s'efface ; sans compte connecté, rien ne s'affiche | Deux magasins : leçons communes (non purgées) et données du compte (purgées). Les pages de leçon gardées doivent être neutres (sans nom, progression ni note), et l'affichage filtré par les droits du compte connecté (Q4) |
| Q6 — Exercice modifié pendant qu'il est fait hors ligne ? | La copie est corrigée sur la version que l'élève a eue, gardée 30 jours | Le refus `stale` de l'ADR-0133 disparaît ; nouvel historique des versions d'exercice (et d'entraînement) côté serveur |
| Q7 — Données des élèves sur le téléphone de l'enseignant ? | Seulement les pages déjà ouvertes, comme prévu au Lot D de l'ADR-0133 | Pas de téléchargement d'avance pour l'enseignant ; le Lot D d'origine est repris tel quel, plus ses écritures (Q2) |
| Q8 — Quels appareils ? | La PWA seulement (Chrome Android, Safari iPhone) | Apps Android : chantier de suivi `hors-connexion-android` |
| Q9 — Élève désactivé, supprimé ou session révoquée pendant qu'il est hors ligne ? | Hors ligne, il continue ; au premier contact avec le serveur, tout ce qui est propre au compte est effacé et ses copies en attente sont refusées ; les leçons communes restent si un autre compte de l'appareil y a droit | Toute réponse du serveur à un compte non reconnu porte `Lnclass-Offline: forget` (déjà vrai pour un visiteur non connecté) ; la liste du catalogue rend 401 et le programme oublie la clé ; nouveau motif de refus `account_inactive` ; plafond de 30 jours sans contact inchangé |
| Q10 — Quand récupérer les leçons corrigées ou nouvelles ? | À chaque retour du réseau, relecture de la liste ; son niveau mis à jour même en données mobiles, les autres niveaux en Wi-Fi seulement | La liste doit rester légère (quelques Ko, pas d'URL en double) : versions par leçon et ETag de la liste (304 si rien n'a bougé). La mise à jour du niveau ne redemande pas l'accord « données mobiles » ; la carte n'est pas réaffichée pour une mise à jour |
| Q11 — Élève sur plusieurs niveaux, devoir d'un autre niveau ? | Un élève n'a qu'un niveau ; un devoir ne peut viser que le niveau de la classe (vérifié : refus `other_level` de l'attribution) | Priorité 0 = le niveau de l'élève, sans exception ; un changement de classe change la priorité au prochain relevé de la liste, l'ancien niveau passe dans « le reste » |
| Q12 — Enseignant : donner hors ligne un devoir qu'il n'a jamais ouvert ? | Sans préférence du porteur : option prudente appliquée, pages déjà ouvertes seulement (à trancher, journal) | La page « Donner un devoir » et ses écrans de choix entrent dans la liste gardable de l'enseignant (Lot D) ; un choix non gardé montre « Disponible avec du réseau ». Extension possible : télécharger le catalogue des niveaux de ses classes, sans corrigé ni donnée d'élève |
| Q13 — Premier lancement sans réseau, téléchargement jamais commencé ? | Sans préférence : option prudente, « Pas de connexion » avec la consigne d'ouvrir une fois avec du réseau (à trancher, journal) | `offline.html` reçoit la consigne ; l'invitation à installer (installation-pwa) dit de garder l'application ouverte jusqu'à la fin du téléchargement du niveau |
| Q14 — Frontière du « 100 % » : annonces, badges et progression, archive des copies, « Mon compte » ? | Sans préférence : option prudente, aucun de ces écrans hors ligne dans ce chantier (à trancher, journal). Grill arrêté ici par le porteur | Hors périmètre ; ces écrans montrent « Pas de connexion » ; extension possible dans un chantier de suivi `hors-connexion-ecrans-eleve` |

## Cas limites identifiés

- Place libre insuffisante pour le niveau entier : le téléchargement ne démarre pas, l'élève voit la taille demandée et la place disponible.
- Téléchargement coupé (réseau perdu, application fermée) : il reprend là où il s'est arrêté, sans retélécharger ce qui est déjà là.
- Safari efface les données d'un site non installé après 7 jours sans visite : on ne promet le hors-ligne total qu'à l'application installée.
- Élève qui change de niveau ou de classe : son nouveau niveau devient prioritaire, l'ancien reste comme « le reste ».
- Leçon dépubliée ou supprimée : elle disparaît de l'appareil au retour du réseau ; une copie faite dessus hors ligne est refusée avec son motif.
- Deux comptes sur un appareil, l'un abonné, l'autre non : le second ne voit pas le contenu payant gardé pour le premier.
- Devoir donné hors ligne sur une classe archivée entre-temps : refusé à la réception, montré « non envoyé » à l'enseignant.
- Enseignant retiré d'une classe avant la synchro : ses écritures sur cette classe sont refusées.
- Exercice modifié plus de 30 jours avant la réception : la version n'est plus gardée, la copie est refusée.

## Questions encore ouvertes

- Grill arrêté à Q14 par le porteur (2026-11-22) ; Q12, Q13 et Q14 appliquées dans leur option prudente, en `## À trancher` du journal.
- Angles non encore attaqués : enseignant dans deux établissements (pages gardées des deux), quota de stockage d'iPhone, charge serveur un jour de rentrée.
- Poids réel des images du catalogue : à mesurer en production avant de fixer la taille annoncée (aucun accès en écriture, mesure par requête de lecture).
- L'app Android : chantier de suivi.
