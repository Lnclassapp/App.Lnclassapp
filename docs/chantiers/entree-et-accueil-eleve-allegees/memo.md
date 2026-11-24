# Memo — Entrée et accueil de l'élève allégés

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-21 |
| **Branche** | `feature/entree-et-accueil-eleve-allegees` |
| **Programme** | `retours-terrain-tiassale` (session lancée par l'orchestrateur) |

---

## Le problème

L'entrée de l'élève porte deux phrases d'explication que personne ne lit, et sa seconde étape (« Nouveau sur Lnclass ») demande de retaper son code secret dans un champ texte ordinaire : l'élève ne sait pas s'il a bien tapé, l'erreur n'arrive qu'après l'envoi. L'inscription redemande ou rappelle un numéro déjà donné à l'entrée, et garde un chemin « J'ai le code de ma classe » que le lien de classe et la recherche d'établissement ont remplacé. Sur l'accueil, la carte de la classe montre un sigle qui ne sert à rien, « Ton premier exercice » occupe la place de la classe, et inviter un camarade passe par une bannière en bas d'écran.

## Pour qui

- L'élève qui arrive pour la première fois (entrée, inscription, première visite de l'accueil, écrans suivants tant qu'il n'a fait aucun exercice).
- L'élève inscrit, sur son accueil (QR de son établissement, invitation).
- Le camarade ou l'enseignant qui scanne le QR montré par un élève.

## Pourquoi maintenant

Retours terrain de Tiassalé (programme `retours-terrain-tiassale`) : les élèves d'une classe entrent ensemble, sur téléphone, et l'adoption se joue au premier quart d'heure. Le porteur a tranché les sept points avant le lancement.

## Hors périmètre

- La première étape de l'entrée (numéro et code secret) : ses champs ne changent pas, seules les deux phrases partent.
- La vérification serveur du code secret et les débits de l'entrée (ADR-0141) : inchangés.
- La page d'un établissement « vitrine » : l'adresse du QR mène à l'inscription, rien d'autre ne s'y affiche.
- Le QR de la classe (lien `/c/<jeton>`, affiche, kit) : inchangé ; le QR de l'accueil est celui de l'établissement.
- L'enseignant, la direction (SchoolStaff), l'équipe (Team) et le parent : aucun de leurs écrans ne change. Un enseignant connecté qui scanne le QR est renvoyé à son accueil, comme aujourd'hui sur toute page d'inscription.
- Le code de six caractères dans « Choisis ta classe » (élève connecté sans classe) : il reste ; seul celui de l'inscription part.
- Les requêtes et le cache de l'accueil : une autre session les optimise ; ce chantier ajoute au plus une lecture bornée par écran pour la fenêtre du premier exercice.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le premier code secret n'est plus dans la page à l'étape « Nouveau sur Lnclass » : comment dire « différents » dès le 4e chiffre ? | Mettre le code (ou son empreinte) dans la page le rendrait lisible : 4 chiffres se retrouvent en 10 000 essais. | Au 4e chiffre, le formulaire part tout seul ; la réponse du serveur dit « identiques » (coche puis compte) ou « différents » (message, cases vidées). Rien du code dans la page. |
| L'inscription sans passer par l'entrée existe-t-elle encore ? | Oui : `/student-signup` en direct (accueil public, page d'un cours, `/join`) garde ses trois étapes, numéro et code compris. | Le numéro n'y est pas connu : il reste demandé. Décision réversible écrite dans `## À trancher` (option prudente : on n'y touche pas). |
| Le QR mène à l'inscription : par quelle porte ? | Passer par `/student-signup` en direct redemanderait numéro et code. | L'adresse du QR ouvre l'entrée élève, l'établissement gardé avec l'entrée ; après la confirmation, l'inscription s'ouvre établissement choisi. |
| L'adresse d'un établissement est-elle devinable, ou énumérable ? | Son identifiant public est aléatoire (14 caractères) ; la recherche d'établissement publique liste déjà tous les établissements actifs avec ce même identifiant. | Pas de nouvel identifiant : l'identifiant public existant suffit ; l'adresse ne dit rien de plus que la recherche. Menace écrite dans l'ADR ; débit propre. |
| Qui scanne le QR : un élève connecté, un enseignant, un élève d'un autre établissement ? | Connecté : renvoyé à son accueil (règle de toutes les inscriptions). Déconnecté avec un compte : l'entrée le connecte, l'établissement est oublié. | Aucun rattachement automatique : l'adresse ne fait que préremplir un choix que l'inscription rejuge. |
| Établissement désactivé ou identifiant faux ? | Même réponse que l'entrée standard, sans message. | Pas d'oracle supplémentaire ; test dédié. |
| La fenêtre « Ton premier exercice » sur tous les écrans : quel coût ? | Calculer le premier exercice sur chaque page coûterait la requête de l'accueil à chaque écran. | Chargement différé de la fenêtre, et un drapeau de session posé dès le premier exercice fait : ensuite, zéro requête. |
| « Fait un exercice » : commencé, terminé, réussi ? | Le porteur : « elle disparaît à son premier exercice ». | Terminé (une copie rendue, quelle que soit la note). Écrit dans `## À trancher` ; l'ancienne règle « réussi » ne sert plus à cette fenêtre. |
| La fenêtre et l'invitation à installer l'application, sur l'accueil, en même temps ? | Deux fenêtres l'une sur l'autre. | Tant que la fenêtre du premier exercice peut s'ouvrir, l'invitation à installer attend. |
| « Inviter » en tuile ET la bannière « Invite tes camarades » ? | Deux portes pour une action (règle 3 de l'UDR Wave). | La tuile remplace la bannière. |
| Multi-appartenance : un élève dans deux classes, ou deux établissements ? | L'accueil montre sa classe principale. | Le QR est celui de l'établissement de sa classe principale. |

## Cas limites identifiés

- Entrée expirée (30 min) pendant le pavé : l'envoi renvoie à l'entrée avec « Ton entrée a expiré », comme aujourd'hui.
- 10 codes faux par minute depuis l'adresse : la confirmation n'est pas comptée comme code faux (inchangé).
- Sans JavaScript : champ et bouton actuels, la vérification serveur décide.
- Un numéro pris entre l'entrée et l'inscription : l'erreur du numéro s'affiche à l'étape 2, avec « Ce n'est pas mon numéro ».
- QR d'un établissement désactivé entre-temps : entrée standard, rien n'est dit.
- Élève sans classe principale active : pas de carte de classe, donc ni QR ni tuile « Inviter ».
- Élève sans aucun exercice proposé : pas de fenêtre.
- Écran d'exercice (mode concentré) : jamais de fenêtre.
- Coque Android : la fenêtre s'ouvre de même ; le QR aussi.
- Hors ligne : la fenêtre ne se charge pas, rien ne s'affiche.

## Questions encore ouvertes

Aucune bloquante : les réversibles sont dans `journal.md` § À trancher.
