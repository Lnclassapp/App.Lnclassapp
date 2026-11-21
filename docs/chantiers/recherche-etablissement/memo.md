# Memo — Chercher son établissement en tapant son nom

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers `Develop`) |
| **Ouvert le** | 2026-11-20 |
| **Branche** | `feature/recherche-etablissement` |
| **Programme** | `retours-terrain-tiassale` (décision D3 du porteur, 2026-11-20) |

---

## Le problème

Pour s'inscrire, un élève ou un enseignant choisit d'abord sa DRENA dans une liste de 41, puis son établissement dans une liste qui en compte souvent plusieurs centaines, sans pouvoir chercher. À Tiassalé, le 2026-11-20, des élèves se sont trompés de DRENA ou d'établissement sur téléphone : la liste native est longue, les noms se ressemblent, et l'élève ne sait pas toujours de quelle DRENA dépend son école.

## Pour qui

- **L'élève** qui s'inscrit sans lien de classe, ou qui choisit ou change sa classe (« Choisis ta classe », « Changer de classe ») : le premier des trois choix.
- **L'enseignant** qui s'inscrit par la voie standard ou par le lien de parrainage d'un collègue, et l'enseignant déjà inscrit qui rejoint un établissement (écran d'attente, « Mes établissements »).

## Pourquoi maintenant

Les inscriptions en classe à Tiassalé ont montré l'erreur en direct ; le programme `retours-terrain-tiassale` prépare l'ouverture d'autres villes (playbook) où le même écran sera le premier contact.

## Hors périmètre

- **L'inscription de la direction** : elle ne choisit pas dans les listes, elle tape le **code d'établissement**, qui prouve son droit à gérer l'école. Le remplacer par une recherche ouvrirait la direction de n'importe quelle école : décision de droits, non réversible, laissée au porteur (`journal.md`, `## À trancher`).
- Le niveau et la classe de la cascade élève : inchangés.
- L'entrée de l'inscription élève (numéro et code d'abord) : chantier `entree-eleve-unifiee`.
- Les écrans de l'équipe (liste nationale des établissements, filtre DRENA du pilotage) : leurs filtres restent.
- Chercher par ville ou par quartier : les écoles n'ont pas de colonne ville ; le nom et la DRENA (souvent la ville) suffisent.
- Les établissements inactifs ou en brouillon : jamais proposés.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La direction choisit-elle aussi dans les deux listes ? | Non : elle tape le code d'établissement (preuve de droit). | Direction hors périmètre, écrite à trancher ; le composant sert l'élève (3 écrans) et l'enseignant (3 écrans). |
| La DRENA est-elle encore utile une fois l'établissement trouvé ? | Le use case de l'enseignant vérifie que l'établissement est dans la DRENA envoyée. | La DRENA est déduite de l'établissement choisi côté serveur ; les règles du domaine restent intactes, sans changement de contrat. |
| 40 élèves cherchent en même temps sur le même wifi : le débit tient-il ? | 30 requêtes par minute et par adresse pour la liste actuelle : une classe le dépasse en quelques secondes de frappe. | Débit propre à la recherche, 300 par minute et par adresse ; frappe attendue 300 ms et 2 lettres au moins avant d'envoyer. |
| « ND paix tiassale » : un sigle et la DRENA dans la même saisie ? | « ND » n'est ni dans le nom ni dans la DRENA ; ce sont les initiales de « Notre-Dame ». | Chaque mot doit se trouver dans le nom, le sigle, la DRENA ou, pour un mot court, les initiales du nom ; tous les mots doivent se trouver. |
| Deux écoles du même nom dans deux DRENA ? | Possible (l'unicité est par DRENA). | La DRENA s'affiche à côté de chaque résultat : c'est elle qui les distingue. |
| 300 réponses pour « lycée » ? | Bornées à 20. | Au-delà, une ligne dit d'ajouter un mot ; on ne pagine pas. |
| Sans JavaScript (vieux téléphone, mode économie) ? | Les listes avaient un repli GET. | Un bouton « Chercher » sous `noscript` renvoie la page avec les résultats en boutons radio ; jamais le code secret dans l'adresse côté enseignant. |
| Un établissement désactivé entre la recherche et l'envoi ? | L'envoi est rejugé par le use case. | Même erreur « établissement introuvable » qu'aujourd'hui, sous le champ. |
| Parent, Team ? | Le parent n'a pas d'inscription ; l'équipe crée les comptes depuis ses écrans. | Rien pour eux (hors périmètre). |
| Multi-appartenance, enseignant de deux écoles ? | Le deuxième rattachement passe par « Mes établissements ». | Le même composant y sert ; aucune règle de plafond ne change. |

## Cas limites identifiés

- Saisie d'une lettre, ou rien que des espaces : aucune recherche, la liste reste vide.
- Saisie avec accents, apostrophes, tirets, majuscules : « lycee sainte-marie » trouve « Lycée Sainte Marie ».
- Saisie démesurée ou de plus de 6 mots : coupée, jamais d'erreur.
- Aucun résultat : un état « introuvable » qui propose d'essayer un autre mot ou le nom de la ville.
- Établissement choisi puis nouvelle recherche : le choix est retiré, le niveau et la classe se vident.
- Identifiant d'établissement forgé ou inactif à l'envoi : refusé par le use case, rien n'est révélé.
- Au-delà du débit : un état d'erreur avec « Réessayer », dans la liste.

## Questions encore ouvertes

- La direction : garder le code d'établissement (appliqué) ou chercher puis prouver par code ? (`journal.md`)
