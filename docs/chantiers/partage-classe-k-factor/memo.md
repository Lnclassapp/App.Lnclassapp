# Memo — Partage de la classe et mesure du k-factor élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-20 |
| **Branche** | `feature/partage-classe-k-factor` |
| **Programme** | `retours-terrain-tiassale` (décision D4) |

---

## Le problème

Visite de terrain au collège Notre-Dame de la Paix de Tiassalé, 2026-11-20 (programme [`retours-terrain-tiassale`](../retours-terrain-tiassale/memo.md), point 4) : une classe s'inscrit en salle, mais **rien ne fait venir le voisin de table** ni les absents, et **rien ne dit qui a fait venir qui**.

Ce qui existe :

- Le **lien de classe** `/c/<jeton>` : l'enseignant le partage sur WhatsApp ou le copie (carte « Inscrire vos élèves »). Il mène l'élève à l'inscription, la classe déjà choisie. Il n'existe ni en QR ni sur papier : en salle, sans projecteur, l'enseignant dicte un lien de 12 caractères.
- La **voie d'arrivée** d'un élève dans une classe (`standard`, `link`, `code`) : elle est réécrite à chaque retour dans une classe, et ne distingue ni un QR d'un lien partagé, ni l'élève qui a invité.
- La **page Croissance** de l'équipe : k enseignant (parrainage entre enseignants), entonnoir AARRR des élèves par voie. **Aucun k élève**, ni par classe ni par établissement.
- Sur l'accueil élève, une seule bannière d'invitation : « Ton enseignant n'est pas sur Lnclass ? ». Rien pour inviter ses camarades.

Le [playbook de lancement d'une ville](../../guide/playbook-lancement-ville.md) pose le jour J sur ces quatre outils (QR au tableau, « Invite tes camarades absents » en fin d'heure, affiche laissée en classe) et un seuil : **k ≥ 0,5 à J+14 par classe**. Sans ces outils, le playbook ne se joue pas ; sans la mesure, on ne sait pas s'il marche.

## Pour qui

- **L'enseignant** (et la direction, l'équipe sur la même page de classe) : affiche le QR de sa classe au tableau, ou l'imprime sur une affiche A4.
- **L'élève inscrit** : envoie le lien de sa classe à ses camarades sur WhatsApp, en un geste, depuis son accueil.
- **L'élève invité** : scanne ou ouvre le lien, arrive sur l'inscription, sa classe déjà choisie.
- **La direction et l'équipe** : impriment le kit d'affiches d'un établissement (une A4 par classe).
- **L'équipe** : lit le k-factor par classe et par établissement sur la page Croissance.

## Pourquoi maintenant

Le programme de Tiassalé lance la première ville dans trois semaines ; la semaine −1 du playbook demande que chaque enseignant reparte avec le QR imprimé de ses classes. Et le seuil de J+14 ne se lit que si l'attribution est enregistrée **dès la première inscription** : ce qui n'est pas enregistré le jour J ne se reconstitue pas.

## Hors périmètre

- **Aucune récompense, aucun classement, aucun compteur visible par l'élève** (« tu as fait venir 3 camarades ») : l'invitant ne voit rien de ses invités (point de vigilance D4).
- **Aucune vue de l'attribution pour l'enseignant ou la direction** : V1 = équipe seulement, en agrégats (aucun nom d'élève).
- **Le comptage des partages** (clics sur « Invite tes camarades ») : le k se mesure par l'issue (inscriptions), pas par l'envoi. La décomposition k = i × c reste celle des enseignants (`croissance-parrainage`).
- **L'attribution d'un élève déjà inscrit qui change de classe par un lien** : seule l'inscription (création du compte) porte une source. Un changement de classe garde sa voie d'arrivée actuelle.
- **Le parrainage entre enseignants** et la bannière « Ton enseignant n'est pas sur Lnclass ? » : inchangés, sauf leur place sur l'accueil (règle Wave « une porte par écran », UDR de ce chantier).
- **Le parent** : il n'a pas de compte ; rien ici.
- **Un QR qui porte autre chose que le lien de classe** (code de classe, jeton d'inscription, identifiant) : refusé (point de vigilance D4).
- **L'entrée élève unifiée et la recherche d'établissement** (D1 à D3) : chantiers voisins ; ce chantier ne touche que les champs cachés du formulaire d'inscription qui portent la source.
- **Les inscriptions antérieures au déploiement** : aucune reprise ; la mesure commence à la mise en production et le dit.

## Ce que le grill a révélé

> Grill adverse mené en session autonome : les décisions D4 du porteur ne se rediscutent pas ; chaque question a sa réponse dans le dépôt, ou l'option prudente est appliquée et écrite dans `journal.md` § À trancher.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La voie d'arrivée de la classe (`joined_via`) ne suffit-elle pas à porter la source ? | Non. Elle est réécrite à chaque retour dans une classe (ADR-0085), sa contrainte n'accepte que trois valeurs que l'entonnoir AARRR lit déjà (« amené par sa classe »), et elle n'a pas de place pour l'invitant. | **Nouvelle table**, une ligne par élève, écrite une fois à la création du compte, jamais réécrite. `joined_via` ne change pas. ADR. |
| Comment le lien d'invitation désigne-t-il l'invitant sans exposer l'élève ? L'identifiant public dans l'URL ? | L'identifiant public de l'élève sert dans des adresses d'enseignant ; le mettre dans un lien WhatsApp le fait circuler hors de la classe. | Un **code d'invitation opaque** par élève (8 caractères aléatoires), sans lien calculable avec le compte ; il ne donne accès à rien. Table dédiée, créée au premier clic sur « Invite tes camarades ». |
| Le QR doit-il porter un secret de plus ? | Non (D4). Le lien de classe est déjà le secret qui ouvre l'inscription dans la classe. | Le QR = `/c/<jeton>?s=qr`. `s=qr` est une étiquette de mesure, pas un secret : quiconque peut l'ajouter. Écrit dans l'ADR (la mesure est déclarative). |
| Qu'arrive-t-il aux affiches imprimées quand l'enseignant « change le lien » ? | Le jeton change ; l'ancien lien retombe sur la voie standard avec l'alerte (IL-09). | La confirmation « Changer le lien » prévient que **les QR et affiches imprimés ne marcheront plus**. Pas de jeton séparé pour le QR (il faudrait le changer aussi en cas de fuite). |
| Acteurs oubliés : la direction, l'équipe, le parent ? | La direction et l'équipe voient déjà la carte du lien de classe. Le playbook laisse « le kit d'affiche à la direction pour les classes non visitées ». | La direction et l'équipe ont le QR de chaque classe et le **kit d'un établissement** (une A4 par classe ouverte). L'enseignant a l'affiche de ses classes. Le parent : hors périmètre. |
| Un élève invite, puis quitte la classe ou est anonymisé : l'inscription de son invité ? | L'invitation reste un fait. Mais un compte anonymisé ne doit plus attribuer. | Un code d'un élève anonymisé ne résout plus d'invitant : l'invité est compté « lien de l'enseignant ». Une attribution passée garde l'invitant (supprimé à la suppression du compte). |
| L'invitant peut-il gonfler son compteur en créant des comptes ? | Il n'a ni compteur, ni récompense, ni vue. | Pas d'anti-fraude dans ce chantier ; l'équipe lit des agrégats. Écrit dans les coûts de l'ADR. |
| Multi-appartenance : un élève change de classe ou d'établissement après son inscription. Où compte-t-il ? | Le k mesure la classe qui l'a fait venir. | L'attribution garde **la classe de l'inscription** (et donc son établissement), jamais mise à jour. |
| Cas limites : classe sans inscrit, établissement de mille élèves, code inconnu ou mal formé, lien d'une classe archivée ? | Zéro inscrit : k « — ». Code inconnu : oublié sans erreur. Lien mort : voie standard (l'existant). | Le code d'invitation ne fait **jamais** échouer une inscription. Le tableau de l'équipe est borné (20 lignes par table, triées par inscrits) avec une ligne de total. |
| Quel k ? Les invitations seules, ou invitations + QR comme le playbook ? | Le playbook (D5) définit le k « par l'invitation d'un autre élève ou par le QR, par inscrit », seuil 0,5. | Le k affiché suit le playbook ; chaque source a sa colonne pour lire le k strict. Option écrite dans `## À trancher`. |
| Où est le bouton « Invite tes camarades » ? La règle Wave interdit deux portes. | L'accueil a déjà une bannière d'invitation (l'enseignant). | La bannière du bas devient « Invite tes camarades » ; l'invitation de l'enseignant ne s'affiche plus que si la classe n'a **aucun** enseignant. UDR. |
| Contexte borné ? | L'inscription élève, le lien et le code de classe vivent dans `classroom`. La page Croissance est en `identity`. | La règle (source, invitant) est portée par `classroom` ; la page Croissance lit une query `classroom`. |
| Le formulaire d'inscription est refait en parallèle (`entree-eleve-unifiee`). | Les deux chantiers touchent le même formulaire. | Ce chantier n'ajoute que **deux champs cachés** et leur lecture ; le second fusionné se rebase. Écrit dans le plan. |

## Cas limites identifiés

- Lien `/c/<jeton>?s=qr&i=<code>` (les deux) : l'invitation l'emporte (seul le bouton de l'élève pose `i`).
- `s` autre que `qr`, `i` mal formé : ignorés, sans erreur.
- Inscription par la voie standard (cascade) après un lien invalide : « à froid », même si `i` était présent.
- Inscription par le code de classe tapé : source « code ».
- Élève sans classe active : pas de bouton d'invitation.
- Classe archivée ou établissement inactif : l'affiche et le QR ne sont plus proposés (lien inutilisable) ; le kit d'établissement ne liste que les classes ouvertes de l'année.
- Kit d'un établissement sans classe ouverte : page qui le dit, sans A4 vide.
- Période sans aucune inscription attribuée : section k vide qui le dit (« mesuré depuis le … »).

## Questions encore ouvertes

- Voir `journal.md` § À trancher : définition du k affiché, place de l'invitation de l'enseignant sur l'accueil.
