# Memo — Croissance par parrainage entre enseignants, démarrage à froid et mesure du k-factor

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/croissance-parrainage` (part de `feature/code-etablissement-enseignants`, PR #49) |
| **Programme** | — |

---

## Le problème

Demande du porteur (2026-09-28) : « je voudrais un k-factor de +2 si possible avec nos programmes de growth ».

Aujourd'hui, un enseignant n'arrive sur Lnclass que si l'équipe a transmis à son établissement le code secret d'établissement (ADR-0057) et que l'établissement l'a relayé. Rien n'aide un enseignant déjà inscrit à faire venir ses collègues, rien ne mesure ce qui se passe quand il le fait, et un établissement dont personne n'a reçu le code est une impasse : l'enseignant motivé ne peut pas s'inscrire du tout.

Trois faits cadrent la réponse :

1. Le porteur **garde le code secret** pour l'inscription des enseignants.
2. Le **code national** d'un établissement (6 chiffres, public, publié dans les résultats du BEPC) ne peut donc pas servir de secret : n'importe qui le connaît.
3. Recommandation retenue : **A + C**. Le code secret sert au lien de parrainage, chemin rapide ; le code national est stocké et sert au démarrage d'un établissement sans enseignant, avec un compte **en attente** jusqu'à validation.

## Le modèle du k-factor, dit honnêtement

### La formule

> **k = i × c**
> *i* = invitations envoyées par utilisateur, *c* = taux de conversion d'une invitation en inscription.

Chaque génération d'utilisateurs en amène *k* fois plus. À *k* > 1 la croissance est virale ; à *k* < 1 elle s'éteint, mais **amplifie** l'acquisition directe d'un facteur 1 / (1 − k) (k = 0,5 double chaque inscription directe).

Pour **k = 2**, il faut par exemple :

| Invitations par enseignant (*i*) | Conversion (*c*) | k |
|---|---|---|
| 8 | 25 % | 2,0 |
| 4 | 50 % | 2,0 |
| 20 | 10 % | 2,0 |
| 3 | 25 % | 0,75 |

La vitesse compte autant que *k* : avec un **cycle viral** (délai entre l'inscription du parrain et celle du filleul) de *t* jours, une base de *N* enseignants devient environ *N × k^(jours / t)*. Un k de 1,2 en 3 jours bat un k de 2 en 30 jours sur un trimestre.

### Ce qui est réaliste

**Un k ≥ 2 soutenu est rare.** Les produits cités en exemple (messagerie, paiement entre particuliers) l'ont atteint quelques semaines, sur un marché vierge, avec un usage qui exige l'autre. Trois limites propres à Lnclass :

1. **Le lien de parrainage vise l'établissement du parrain** (c'est le code secret de son établissement). Un lycée compte de 40 à 120 enseignants : la boucle **sature** dès que l'établissement est couvert. Un k intra-établissement de 2 est plausible les deux premières semaines, puis tend vers 0.
2. **Le passage d'un établissement à l'autre** est la vraie boucle virale au sens strict, et elle ne passe pas par le lien : elle passe par le **démarrage à froid** (code national), porté par un enseignant qui a entendu parler de Lnclass ailleurs (vacataires, groupes WhatsApp disciplinaires, conseils d'enseignement).
3. **Une invitation WhatsApp n'est pas une invitation** : un partage dans le groupe de la salle des professeurs touche 30 à 80 personnes. On compte donc des **partages** (un clic sur « Partager ») et on mesure *c* par partage, pas par destinataire. Un *c* par partage supérieur à 100 % est possible et n'est pas une erreur.

### Deux k à ne pas confondre

| Mesure | Définition | Nature |
|---|---|---|
| **k enseignant** | filleuls enseignants inscrits ÷ enseignants de la cohorte | viral au sens strict : des enseignants amènent des enseignants |
| **Amplification élèves** | élèves entrés dans une classe ÷ enseignants actifs | **pas** du viral : un enseignant apporte ses classes (≈ 40 élèves par classe, 3 à 6 classes) ; l'élève n'amène pas d'enseignant |

L'amplification élèves est le vrai multiplicateur d'audience de Lnclass (×100 à ×200 par enseignant actif). Elle ne rend pas la croissance virale, mais c'est elle qui justifie chaque enseignant gagné.

### Cibles mesurables par boucle (fenêtre glissante de 30 jours)

| Boucle | Indicateur | Plancher | Cible | Ambition |
|---|---|---|---|---|
| B1 — Lien de parrainage | partages par enseignant de la cohorte (*i*) | 1 | 3 | 8 |
| B1 | conversion par partage (*c*) | 10 % | 25 % | 50 % |
| B1 | **k enseignant** (*i × c*) | 0,1 | **0,75** | **2** (non soutenable au-delà de la saturation) |
| B1 | cycle viral médian | ≤ 14 j | ≤ 7 j | ≤ 3 j |
| B2 — Démarrage à froid | établissements démarrés par le code national | 5 / mois | 20 / mois | 50 / mois |
| B2 | demandes en attente validées par un garant (après la première) | 30 % | 50 % | 80 % |
| B3 — Élèves | élèves entrés dans une classe par enseignant actif | 20 | 40 | 120 |
| B4 — Ambassadeurs | enseignants ayant 3 filleuls ou plus | 2 % | 5 % | 10 % |

La cible réaliste du chantier est donc **k enseignant ≈ 0,75 soutenu, avec des pointes au-dessus de 2 dans les établissements qui démarrent**, et une amplification élèves ≥ 40. Le k de 2 demandé reste l'ambition affichée, mesurée chaque semaine sur la page Croissance ; on saura en un mois si elle est à portée.

## Pour qui

- **L'enseignant actif (Teacher)** : invite ses collègues en un geste (WhatsApp, SMS, copier le lien), voit combien sont venus grâce à lui, se porte garant d'un collègue en attente, partage le lien de sa classe dans le groupe WhatsApp de ses élèves.
- **L'enseignant d'un établissement sans code transmis** : s'inscrit quand même, par le code national ou la recherche de son établissement, et attend une validation.
- **L'équipe (Team)** : valide ou refuse les comptes en attente, lit les indicateurs de croissance, voit le classement des établissements.

## Pourquoi maintenant

La production est ouverte depuis le 2026-09-27 et la rentrée est en cours : c'est la seule période de l'année où les enseignants découvrent un outil et en parlent entre eux. Le code d'établissement (PR #49) ferme la porte aux inscriptions non vérifiées ; sans parrainage ni démarrage à froid, il ferme aussi la porte aux établissements que l'équipe n'a pas encore atteints.

## Hors périmètre

- **Toute récompense monétaire** (crédit, forfait, prime) : décision du porteur, ni conçue ni chiffrée ici.
- **Le classement visible des enseignants** : V1 = équipe seulement. L'ouvrir aux enseignants est un levier à décider.
- **Les parents** : aucun parcours, aucun partage. **La direction (`school_admin`)** : pas de validation des comptes en attente en V1 (V2, avec la direction).
- **Le parrainage entre établissements** : le lien vise l'établissement du parrain ; un filleul d'un autre établissement passe par le démarrage à froid.
- **L'élève qui invite** un camarade ou un enseignant.
- **Un traceur, un pixel, un cookie ou un raccourcisseur de lien tiers** (ADR-0049) : tout se mesure côté serveur.
- **Envoyer** un SMS ou un message WhatsApp depuis nos serveurs : l'enseignant partage depuis son téléphone.
- **Créer un établissement** absent de la base par le démarrage à froid : il faut qu'il existe (import de l'équipe).
- **Compter les partages du lien de classe** : le lien de classe se partage, mais la mesure passe par les élèves entrés.
- Afficher le nom du parrain au filleul sur la page d'inscription.
- Notifier le garant ou l'enseignant en attente (SMS, push) : il voit l'état en se connectant.

## Ce que le grill a révélé

> Grill mené par l'orchestrateur contre le cadrage initial, une question à la fois, le 2026-09-28. Les réponses marquées « défaut » sont à confirmer par le porteur.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le lien de parrainage révèle-t-il le code secret de l'établissement ? | Oui, par construction : le lien est `/e/<code>`. Chaque enseignant actif devient un diffuseur du code. | Le code circule plus ; la régénération (ADR-0057) reste la parade, et **elle casse aussi tous les liens de parrainage** de l'établissement. Consigné en coût consenti. |
| Le jeton du parrain peut-il identifier l'enseignant (numéro, identifiant public) ? | Non : jeton aléatoire, sans lien calculable avec le compte. | Un jeton par enseignant, tiré par la base, jamais le numéro ni l'identifiant public. |
| Un jeton de parrain volé et collé sur le code d'un autre établissement ? | Le parrainage n'est retenu que si le parrain enseigne dans l'établissement du code, et que cet établissement est actif ; sinon l'inscription réussit, sans parrain. | Règle de domaine « parrain valide », testée ; aucune erreur visible, rien n'est révélé. |
| Qu'est-ce qu'une « invitation envoyée » ? Un destinataire ou un geste ? | Un geste : un clic sur un bouton de partage. On ne sait pas combien de personnes lisent un message WhatsApp. | On compte des partages ; la conversion peut dépasser 100 %. Écrit dans le modèle et sur la page Croissance. |
| Comment compter le clic sans traceur ni cookie ? | Une requête vers notre serveur au moment du clic, sur la session existante ; le lien de partage s'ouvre quand même si elle échoue. | Événement serveur, sans donnée de navigation ni adresse IP. |
| Qui peut inviter ? Un enseignant en attente, un établissement désactivé ? | Seul un enseignant rattaché à un établissement **actif**. | Policy dédiée ; bloc absent sinon, 403 à l'enregistrement d'un partage. |
| Un compte « en attente » peut-il lire le catalogue, son profil ? | Non : rien d'autre que l'écran d'attente et la déconnexion. | Garde générale des espaces connectés pour l'enseignant sans établissement. **Change le comportement** pour tout enseignant sans école principale (il voyait le catalogue) : voulu. |
| Le code national suffit-il à rattacher l'enseignant ? | Non : il est public. Il **désigne** l'établissement, il ne prouve rien. | Compte en attente, validé par l'équipe ou par un garant. |
| Qui peut se porter garant ? | Un enseignant actif du **même** établissement, qui n'est pas le demandeur. Le garant devient le parrain. | Policy garant ; parrainage de source « garant ». |
| Un seul garant suffit-il ? Il peut valider un inconnu. | **Défaut** : oui, un seul, et son nom est tracé au journal. L'équipe peut retirer un enseignant comme aujourd'hui. | Audit de chaque validation, avec le garant. |
| Comment l'enseignant en attente trouve-t-il un garant ? | Les enseignants actifs de son établissement voient la liste « Collègues en attente » sur leur accueil (nom et matière, jamais le numéro). | Bloc sur l'accueil enseignant. |
| Et si l'établissement n'a aucun enseignant ? | L'équipe valide depuis la fiche ; après le premier, les suivants passent par un garant. | Liste « Enseignants en attente » sur la fiche, Valider / Refuser. |
| Anti-abus : un robot qui crée des comptes en attente par milliers ? | Limite de débit à l'envoi, et **au plus 5 demandes en attente par établissement** (**défaut**). Une demande par enseignant. | Constante de domaine ; refus nommé « trop de demandes en attente ». |
| Code national inconnu, ou établissement inactif ? | Le même message que pour un code secret refusé : on ne dit pas pourquoi. | Erreur unique sur le champ. |
| Le code national est-il toujours connu ? | Non : l'import actuel ne l'a pas. Colonne facultative, remplie par l'import (clé optionnelle) ou la fiche. | Recherche DRENA → établissement en repli, qui reprend la liste publique existante. |
| Deux établissements avec le même code national ? | Interdit : unique quand il est présent. | Index unique partiel ; l'import signale le doublon, la fiche aussi. |
| Refus par l'équipe : que devient le compte ? | **Défaut** : il reste, bloqué sur un écran « demande refusée » ; ni supprimé ni anonymisé. | État « refusée » de la demande ; la suppression reste le geste existant. |
| Les messages de partage contiennent-ils des données d'élève ? | Jamais : nom de l'établissement, nom de la classe, lien et code. | Test qui vérifie le texte du message. |
| Le badge Ambassadeur crée-t-il une pression malsaine ? | Il reste discret (profil, bloc d'invitation) et sans récompense. | Seuil 3 (**défaut**), sans classement public. |
| Le classement des établissements peut-il humilier ceux qui démarrent ? | Oui s'il est public : **V1 équipe seulement**. | Sur la page Croissance, jamais côté enseignant. |
| La page Croissance a-t-elle sa place dans la navigation équipe ? | Non : 5 destinations, le maximum (UDR-0006). Un raccourci sur l'accueil équipe. | Aucune entrée de navigation ; `/teams/dashboard` n'est pas touché (chantier pilotage-equipe). |

## Cas limites identifiés

- Lien parrainé sans jeton, jeton mal formé, jeton inconnu, jeton d'un enseignant parti dans un autre établissement : inscription normale, sans parrain.
- Un filleul ne peut avoir qu'un parrain ; un garant qui valide un filleul déjà parrainé par lien ne remplace pas le parrain.
- L'enseignant en attente dont l'établissement est désactivé avant validation : la validation reste possible par l'équipe ; un garant ne peut plus (son établissement n'est plus actif).
- Deux validations simultanées (équipe et garant) : la première gagne, la seconde reçoit « déjà traitée ».
- Période sans aucun partage : conversion « — », pas de division par zéro ; cohorte vide : k « — ».
- Enseignant sans matière (profil incomplet) : pas de jeton → pas de bloc d'invitation.
- 390 px : les quatre boutons de partage passent à la ligne, sans défilement horizontal.

## Questions encore ouvertes (à confirmer par le porteur)

1. Seuil du badge Ambassadeur : 3 filleuls.
2. Maximum de demandes en attente par établissement : 5.
3. Un seul garant suffit à valider.
4. Compte refusé conservé, bloqué.
5. Nom du parrain non affiché au filleul.
6. Toute récompense (monétaire ou non) au-delà du badge.
7. Ouvrir le classement des établissements aux enseignants.
