# Memo — Annonces ciblées, programmables et écartables

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `feature/annonces` |
| **Programme** | `refonte-application`, vague **V6a** ([feuille de route §5, V6](../refonte-application/feuille-de-route.md#v6--communication)) — sortie du backlog par le porteur le 2026-10-03 |

---

## Le problème

Lnclass n'a aucun moyen de faire passer une information à ses utilisateurs. L'équipe ne peut prévenir ni les élèves d'une nouveauté du catalogue, ni les enseignants d'un changement, ni les directions d'une campagne. Une direction ne peut rien dire à ses propres enseignants ou élèves par l'application.

L'ancienne application avait des annonces, mais elles ne tenaient pas leurs promesses (inventaire CO-01 à CO-12) :

- une annonce s'ouvrait par son adresse **pour n'importe qui**, quelle que soit son audience et même avant sa publication ;
- la programmation était un statut sans effet : rien ne publiait à l'heure dite ;
- « ne plus afficher » se perdait en changeant d'appareil ;
- les pièces jointes n'étaient pas contrôlées et disparaissaient au redéploiement ;
- l'espace direction affichait un bloc d'annonces toujours vide.

La refonte n'a rien repris de tout cela : aujourd'hui, il n'y a pas d'annonces du tout.

## Pour qui

- **L'équipe (Team)** : elle rédige, programme, modifie et archive ses annonces, nationales ou pour un établissement, pour toute audience. Elle voit toutes les annonces et peut **retirer** n'importe laquelle.
- **La direction (SchoolStaff)** : elle publie pour son seul établissement, à destination de ses élèves, de ses enseignants ou des directions ; ses annonces sont **officielles** (non masquables). Elle peut retirer les annonces des enseignants de son établissement.
- **L'enseignant (Teacher)** : il publie pour une ou plusieurs des classes où il enseigne, et lit les annonces qui lui sont destinées.
- **L'élève (Student)** : il lit sur son accueil les annonces publiées qui lui sont destinées, en écoute l'audio, et masque celles qui ne sont pas officielles.

Chaque auteur ne modifie que ses propres annonces.

## Pourquoi maintenant

Le porteur ouvre la V6 le 2026-10-03. La V1 est en production, et la V2 simple (espace direction) est livrée : l'audience « directions » a désormais des destinataires réels.

Le porteur a validé une maquette de l'accueil élève (2026-10) où les annonces signées sont un bloc à part entière : le bloc existe dans le design, il n'a encore ni données ni règles.

## Hors périmètre

- Messagerie de classe, échanges entre utilisateurs, réponses à une annonce (retirées du plan le 2026-09-22).
- Notification en temps réel, sans recharger la page (CO-08, écartée).
- Envoi hors de l'application — WhatsApp, SMS, e-mail : c'est le chantier `canal-whatsapp`, qui vient après.
- Annonces factices en développement (CO-13, écartée) : remplacées par des données d'amorçage de développement.
- Reprise des annonces de l'ancienne application : aucune donnée réelle n'existe (décision F-12).
- Statistiques de lecture : qui a vu, masqué ou écouté une annonce, et combien.
- Ciblage par niveau ou par série (« toutes les 3ème ») : seul l'enseignant cible des classes ; la direction et l'équipe ciblent par rôle.
- Annonces automatiques et personnelles (« Ton abonnement se termine dans 7 jours ») : l'abonnement et le paiement n'existent pas.
- Enregistrer sa voix depuis le navigateur : l'auteur téléverse un fichier déjà enregistré.
- Lecture vocale du texte par le téléphone (synthèse vocale) : écart assumé avec le design system §10.
- Page de détail d'une annonce : la carte est l'annonce.
- Réponses, commentaires ou réactions à une annonce : une annonce est à sens unique.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La direction peut-elle publier pour son établissement ? L'ADR-0045 dit oui, le PRD du programme dit non, et l'espace direction simple est en lecture seule | **Oui**, comme l'ADR-0045 : pour son seul établissement, à destination des élèves, des enseignants ou des directions | La direction devient un **auteur** : un parcours de rédaction côté direction, et un refus « autre établissement » à tester. L'espace direction cesse d'être en lecture seule : **amendement de l'ADR-0065** (« lecture seule », accepté, contrat d'une vague livrée). Le PRD du programme est à corriger, et la contradiction à inscrire au registre de la feuille de route |
| Qui modifie ou archive une annonce existante ? (plusieurs directions par établissement, modération par l'équipe) | **L'auteur seulement**. L'équipe ne touche pas aux annonces des directions ; un collègue de direction non plus | La règle de gestion est « auteur = acteur », sans exception de rôle : un refus à tester pour un collègue de la même école **et** pour l'équipe. Trou ouvert : une annonce dont l'auteur quitte l'établissement ou dont le compte est anonymisé n'a plus personne pour l'archiver (question suivante). *Revu plus bas : l'équipe et la direction peuvent retirer* |
| Combien de temps une annonce publiée reste-t-elle visible ? | **Une date de fin obligatoire**, 30 jours après la publication par défaut, modifiable par l'auteur | Comble le trou de la question précédente : rien ne traîne indéfiniment. **Amendement de l'ADR-0045** : une colonne de fin non nulle, une contrainte « fin après publication », et un filtre « non expirée » dans la query **et** dans la policy (une annonce expirée donne 404 à son audience, comme une annonce non publiée). L'auteur garde la vue de ses annonces expirées |
| Que peut contenir une annonce ? (la feuille de route dit « riches », l'ADR-0045 dit texte simple) | **Texte simple, au plus une image et un fichier audio**, comme l'ADR-0045 | « Riches » veut dire « avec image et audio », pas « texte mis en forme » : la fiche V6 est à préciser. Les pièces jointes sont dans le périmètre : type vérifié par le contenu, refus d'un fichier déguisé ou trop lourd, à tester. Le texte est rendu échappé : aucun HTML de l'auteur n'atteint la page |
| Que fait « écarter » une annonce ? *(question interrompue : le porteur renvoie à sa maquette de l'accueil élève et au design system Lnclass §10)* | Une croix de 44 px retire l'annonce du carrousel, et un toast « Message masqué · Annuler » permet de revenir en arrière pendant 5 s. **Une annonce de la direction est officielle : badge vérifié, pas de croix, elle ne peut pas être masquée** | « Annuler » rétablit l'annonce, y compris sur les autres appareils. Le refus d'écarter une annonce officielle est vérifié **côté serveur**, pas seulement par l'absence de croix. L'ADR-0045 ne connaît pas la notion d'« officiel » : à amender |
| Les enseignants publient-ils ? (la maquette dit oui, l'ADR-0045 dit non, et la messagerie de classe a été retirée du plan) | **Oui, à leurs classes** : un enseignant publie pour une ou plusieurs des classes où il enseigne, et seuls les élèves de ces classes la voient | Troisième auteur, troisième parcours de rédaction. Nouvelle audience « classes ciblées » : **amendement de l'ADR-0045**. Refus à tester : une classe où il n'enseigne pas, une classe d'un autre établissement. Frontière avec la messagerie de classe : une annonce reste à sens unique, sans réponse ni fil (hors périmètre) |
| Que fait le bouton « Écouter » ? (la maquette lit le texte par la voix du téléphone ; l'ADR-0045 prévoit un fichier) | **Un fichier audio téléversé seulement**, comme l'ADR-0045 (mp3 ou m4a, 10 Mo au plus). Pas de lecture vocale du texte | Le bouton n'apparaît que sur une annonce qui a un fichier : **écart avec le design system §10**, que l'UDR doit trancher explicitement. Le fichier ne se télécharge qu'au premier appui (forfaits data chers). La réponse « texte + image + audio » de la question 4 est confirmée au sens de l'ADR |
| Qu'est-ce qui occupe la place de l'image dans la carte ? (l'ADR-0045 prévoit une image téléversée ; la maquette montre des illustrations plates) | **Les deux** : une illustration choisie dans une bibliothèque fixe de Lnclass, et une image téléversée facultative qui la remplace | Toute annonce a une illustration, même sans image. La bibliothèque d'illustrations (liste fermée, dessins du design system) est à fixer dans l'UDR. **Amendement de l'ADR-0045** : un choix d'illustration en plus de l'image facultative. Deux chemins d'affichage à tester (illustration seule, image qui la remplace) |
| Comment signe la direction ? (la maquette écrit « Mme Kamaté · ACE », mais aucune fonction de direction n'est en base) | **« M./Mme Nom · Direction »**, libellé fixe. L'enseignant signe « M./Mme Nom · Matière », l'équipe signe « Lnclass » avec le logo | Aucune donnée nouvelle : civilité tirée du genre, matière du profil enseignant. Les fonctions précises de direction restent dans l'espace direction complet (backlog). La signature se calcule à l'affichage : un auteur qui change de nom ou est anonymisé change la signature (cas limite) |
| Quel ordre et quel plafond pour le carrousel ? (8 profs × 2 annonces + direction + équipe = une vingtaine de cartes) | **Par émetteur, 5 au plus** : direction, puis enseignants, puis Lnclass ; la plus récente d'abord dans chaque groupe. Au-delà, un lien « Toutes les annonces » | Aucune catégorie à saisir : l'équipe tient la place du « marketing » du design system. Une **page « Toutes les annonces »** existe donc (CO-04). Tri et plafond à tester avec 6 annonces de trois émetteurs |
| Une annonce masquée disparaît-elle aussi de « Toutes les annonces » ? | **Non** : masquer la retire du carrousel de l'accueil, sur tous les appareils ; elle reste dans la liste jusqu'à sa date de fin, marquée « masquée » | Le rejet ne filtre que le carrousel, pas la liste ni l'URL. Deux tests : masquée absente du carrousel, présente dans la liste |
| Où le prof, la direction et l'équipe lisent-ils et gèrent-ils les annonces ? (la maquette ne montre que l'accueil élève) | **Une page « Annonces »** dans la navigation de chaque rôle adulte, avec deux onglets : « Reçues » et « Mes annonces » (rédiger, programmer, modifier, archiver). Le carrousel reste propre à l'accueil élève | Les accueils enseignant et équipe ne changent pas ; CO-11 (espace direction) est couvert par la page ; CO-12 (widget équipe, jamais exécuté) est **écarté**. L'élève atteint la même page par « Toutes les annonces », onglet « Reçues » seul. La navigation est un fichier partagé : elle va au Lot 0 |
| Un enseignant publie un contenu déplacé à des élèves mineurs : qui le retire, si seul l'auteur gère ? | **L'équipe** retire n'importe quelle annonce ; **la direction** retire celles des enseignants de son établissement. Retirer = archiver, jamais modifier ; chaque retrait est journalisé | **Revient sur la question 2** : la modification reste à l'auteur seul, mais le retrait a trois titulaires. Pour retirer, il faut voir : l'équipe voit toutes les annonces (comme l'ADR-0045), la direction celles de son établissement — un troisième regard dans la page « Annonces ». Refus à tester : une direction sur l'annonce d'un enseignant d'une autre école ; un enseignant sur l'annonce d'un collègue |
| Le texte est-il court, ou long avec une page de détail ? (l'ADR-0045 prévoit une page de détail filtrée par audience) | **Court, sans page de détail** : le texte tient dans la carte ; l'audio porte les détails si besoin | Texte plafonné court (140 caractères, à figer au PRD). **CO-05 n'est plus une page** : la carte est l'annonce, dans le carrousel comme dans « Toutes les annonces ». Ce qu'une URL directe peut encore exposer, ce sont **l'image et l'audio** : ils ne sont servis qu'après la même règle de lecture que l'annonce (audience, publication, date de fin), sinon 404 — c'est là que portent les tests « par URL directe » de l'ADR-0045. **Amendement de l'ADR-0045** (pas de page de détail, texte plafonné) |
| Quelles demandes voisines refuser explicitement ? (statistiques de lecture, ciblage par niveau, annonces automatiques, enregistrement de la voix) | Pas de préférence exprimée : **les quatre sont refusées par défaut**, en cohérence avec les réponses précédentes | Quatre lignes de plus dans `Hors périmètre`. Le porteur peut en rouvrir une avant le PRD |
| L'auteur modifie une annonce publiée : que voient ceux qui l'avaient masquée ? | **Elle revient** dans leur carrousel, marquée « Modifiée » | Une modification efface les rejets de l'annonce. Garde-fou : une annonce **retirée** par l'équipe ou la direction ne peut pas être republiée par son auteur en la modifiant, sinon le retrait ne vaut rien (refus à tester) |

## Cas limites identifiés

- **Zéro annonce** : pas de bande d'annonces sur l'accueil élève, pas de bande grise vide. La page « Annonces » affiche un état vide.
- **Une annonce** : une carte, sans points de pagination.
- **Six annonces ou plus** : cinq cartes dans l'ordre direction → enseignants → Lnclass, puis « Toutes les annonces ».
- **Élève sans classe active** (pas encore rejoint, classe archivée) : il ne voit que les annonces nationales.
- **Élève qui change de classe** : il perd les annonces de l'ancienne classe et voit celles encore valides de la nouvelle. Un élève n'a qu'une classe principale : une annonce ciblant deux classes ne lui apparaît jamais deux fois.
- **Enseignant qui n'enseigne plus** dans une classe ciblée : son annonce reste jusqu'à sa date de fin, et il la gère encore. Il ne peut plus cibler cette classe dans une nouvelle annonce.
- **Auteur anonymisé, direction retirée, enseignant parti** : l'annonce reste jusqu'à sa date de fin, sa signature suit le compte, et l'équipe ou la direction peut la retirer.
- **Dates incohérentes** : une date de fin antérieure à la publication, ou une publication programmée dans le passé, est refusée à l'enregistrement.
- **Date de fin atteinte** pendant qu'un élève a la page ouverte : l'annonce disparaît au prochain affichage, et son image et son audio répondent 404.
- **Annonce retirée** : son auteur la voit « retirée » dans « Mes annonces », sans pouvoir la republier.
- **Fichiers** : un PDF renommé en `.png`, une image de plus de 2 Mo, un audio de plus de 10 Mo ou d'un autre format sont refusés. Une image supprimée laisse revenir l'illustration.
- **Audio illisible sur le téléphone** : le message « Audio indisponible sur ce téléphone. » s'affiche, jamais un échec silencieux.
- **Annonce officielle** (direction) : la croix n'existe pas, et une demande de masquage forgée est refusée par le serveur.
- **Masquée puis modifiée** : elle revient, marquée « Modifiée ».
- **Plusieurs comptes de direction** dans un établissement : chacun ne modifie que ses annonces, mais chacun peut retirer celles des enseignants de l'établissement.

## Questions encore ouvertes

- **Durée maximale** de la date de fin : 30 jours par défaut, mais quel plafond (90 jours, fin de l'année scolaire) ? À figer au PRD.
- **Limites de longueur** : texte court (140 caractères ?), titre (l'ADR-0045 dit 120, c'est trop pour une carte de 15 px : 60 ?). À figer au PRD avec l'UDR.
- **Bibliothèque d'illustrations** : combien, lesquelles (examen, devoirs, réunion, fiches, calendrier, info, fête, Lnclass ?). À fixer dans l'UDR avec le design system.
- **Audience d'une annonce d'enseignant** : les élèves des classes ciblées seulement, ou aussi les autres enseignants de ces classes ? Par défaut : les élèves seulement.
- **Officiel** : toute annonce de direction est officielle, quelle que soit son audience ? Par défaut : oui.
- **Retrouver une annonce à retirer** parmi toutes celles du pays (équipe) : filtre par établissement dans « Annonces » ? À trancher dans l'UDR.
- **Registre des contradictions** de la feuille de route : inscrire PRD cadre ↔ ADR-0045 (la direction publie), design system §10 ↔ ADR-0045 (audio, image, auteurs), ADR-0065 ↔ ce chantier (lecture seule).
