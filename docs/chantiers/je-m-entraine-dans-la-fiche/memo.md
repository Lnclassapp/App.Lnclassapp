# Memo — « Je m’entraîne » dans la fiche de révision

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/je-m-entraine-dans-la-fiche` |
| **Programme** | — |

---

## Le problème

La fiche de révision d'une leçon donne, pour chaque notion, ce qu'il faut retenir, la méthode, un exemple corrigé et le piège à éviter. L'élève lit, mais ne s'essaie pas : l'exercice de la notion est ailleurs, plus bas dans la page (« Prépare interros »), loin de la méthode qu'il vient de lire. Entre l'exemple corrigé et le moment où il applique lui-même la méthode, il doit quitter sa lecture, retrouver la notion et ouvrir une autre page.

Le porteur veut que l'élève s'exerce là où il vient de comprendre : juste après l'exemple corrigé, dans la fiche, avec la correction sur place (choix du 2026-10-30, qui revient sur le retrait des exercices de la fiche décidé à la refonte des contenus).

## Pour qui

L'élève qui révise une leçon, avant une interrogation ou après un cours. À préciser au grill : l'enseignant et l'équipe qui lisent la même fiche.

## Pourquoi maintenant

Les 60 premières leçons de 3e sont au nouveau format, chacune avec un exercice par notion : le contenu existe, il ne manque que l'endroit où le faire. Plus on publie de leçons sans cet entraînement, plus les élèves prennent l'habitude de lire sans s'exercer.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- …

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| L'exercice fait dans la fiche est le même que celui de « Prépare interros », qui compte pour la note, la maîtrise, le badge et la pause après 3 copies. La copie faite dans la fiche compte-t-elle ? | Non : entraînement seul (porteur, 2026-10-30) | Rien n'est enregistré depuis la fiche : ni copie, ni note, ni maîtrise, ni pause ; l'élève refait autant qu'il veut. À trancher ensuite : l'élève voit dans la fiche les questions et la correction de l'exercice noté, ce qui rend la note de « Prépare interros » facile à obtenir |
| L'élève voit dans la fiche les mêmes questions et la même correction que l'exercice noté : sa première copie notée peut être un 20/20 fait les réponses en tête, sans passer par la pause. Que fait-on ? | Un exercice à part (porteur, 2026-10-30). Écartés : accepter le risque, juste/faux sans la bonne réponse, ouverture après une 1re copie | La fiche n'affiche jamais l'exercice noté de « Prépare interros » ni sa correction. Chaque notion reçoit son propre exercice d'entraînement, distinct, que l'équipe écrit et importe. Ce contenu n'existe pas encore pour les 60 leçons : il faut décider ce que montre une notion qui n'en a pas, et qui l'écrit |
| L'exercice d'entraînement à part n'existe pour aucune des 60 leçons : le jour de la livraison, aucune notion n'en a. Comment livre-t-on ? | Avec une leçon pilote (porteur, 2026-10-30). Écartés : livrer sans contenu, attendre les 60 leçons, section toujours visible avec un message | « Je m'entraîne » ne s'affiche que sur une notion qui a son exercice d'entraînement ; ailleurs, la fiche reste en 4 blocs. Le chantier comprend l'écriture et l'import des exercices d'entraînement d'une leçon pilote, toutes ses notions, et c'est sur elle que le challenger teste. Les 59 autres leçons sont hors périmètre |
| Qui peut faire l'exercice d'entraînement et voir sa correction : enseignant, équipe, élève d'une autre classe, visiteur ? | Les comptes connectés seulement (porteur, 2026-10-30). Écartés : tous ceux qui voient la fiche, les élèves seuls | Tout compte connecté qui voit la fiche (élève, enseignant, équipe) peut répondre et voir la correction, et voit la même chose que l'élève. Le visiteur ne voit jamais « Je m'entraîne » ni sa correction. Aujourd'hui, les pages publiques du catalogue s'arrêtent à la matière et ne montrent pas la fiche : la règle doit tenir si une fiche devient publique un jour |
| La coupe « Voir plus » des 150 mots tombera presque toujours avant « Je m'entraîne » de la première notion, et le #393 a vu une partie visible finir sur l'annonce d'un élément caché. Où se place l'exercice par rapport à la coupe ? | Toujours après la coupe (porteur, 2026-10-30). Écartés : compté dans les 150 mots, corriger #393 dans ce chantier | L'exercice ne compte aucun mot, et la coupe ne tombe jamais sur lui : il est soit visible en entier, soit caché en entier jusqu'à « Voir plus ». La partie visible ne finit jamais sur l'annonce de l'exercice. #393 reste un /bugfix à part |
| Qui corrige une réponse donnée dans la fiche : le serveur (sans rien garder) ou le navigateur ? Plafond du JavaScript commun : 61 Ko gzip (ADR-0114), marge de quelques octets | Le navigateur (porteur, 2026-10-30). Écartés : le serveur sans rien garder, le corrigé déplié sans vérification | Les bonnes réponses de l'exercice d'entraînement sont dans la page, lisibles dans le code source par tout compte connecté qui voit la fiche : on l'accepte, car cet exercice n'est pas noté et diffère de l'exercice noté (grill 2). Elles ne sont jamais écrites dans la page d'un visiteur. La logique de correction se charge à la demande, hors du JavaScript commun, et le plafond de 61 Ko ne bouge pas (pas de nouvel ADR de budget). Les règles des types de questions existent déjà côté serveur : les écrire aussi en JavaScript fait deux sources à garder d'accord, et les tests doivent le prouver. Sans JavaScript, l'exercice se lit mais ne se vérifie pas |
| Les types de réponse de l'exercice d'entraînement (capture du porteur : réponse chiffrée avec unité « AN (cm) = … », choix « parallèles / pas parallèles », boutons Vérifier · Indice · Correction) sont-ils propres à la fiche ? | Non : ils doivent servir aussi aux exercices des interrogations et des devoirs (porteur, 2026-10-30) | Un seul catalogue de types de questions, partagé entre l'entraînement de la fiche et les exercices notés : pas de type réservé à la fiche. Tout type ajouté ou étendu ici (par exemple plusieurs cases dans une même question) passe par les règles de notation de l'ADR-0115 et demande un ADR. Avec la correction dans le navigateur (grill 6), chaque type a deux règles, une côté serveur pour la note et une en JavaScript pour la fiche, qui doivent rendre le même verdict : à reprendre au grill 7 |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
