# Memo — « Je m’entraîne » dans la fiche de révision

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/je-m-entraine-dans-la-fiche` |
| **Programme** | — |

---

## Le problème

La fiche de révision d'une leçon donne, pour chaque notion, ce qu'il faut retenir, la méthode, un exemple corrigé et le piège à éviter. L'élève lit, mais ne s'essaie pas : l'exercice de la notion est ailleurs, plus bas dans la page (« Prépare interros »), loin de la méthode qu'il vient de lire. Entre l'exemple corrigé et le moment où il applique lui-même la méthode, il doit quitter sa lecture, retrouver la notion et ouvrir une autre page.

Le porteur veut que l'élève s'exerce là où il vient de comprendre : juste après l'exemple corrigé, dans la fiche, avec la correction sur place (choix du 2026-10-30, qui revient sur le retrait des exercices de la fiche décidé à la refonte des contenus).

## Pour qui

- **L'élève** qui révise une leçon, avant une interrogation ou après un cours : il s'exerce dans la fiche, autant qu'il veut, sans que rien ne soit gardé.
- **L'enseignant et l'équipe** connectés : ils voient et font l'exercice comme l'élève (grill 4), sans pouvoir l'assigner (grill 16).
- **L'élève et l'enseignant d'une interrogation ou d'un devoir** : ils profitent des questions à plusieurs cases (grills 7 à 9) et de l'indice, dont l'ouverture est visible sur la copie (grills 10 et 11).
- **Le visiteur non connecté** ne voit jamais « Je m'entraîne » (grill 4).

## Pourquoi maintenant

Les 60 premières leçons de 3e sont au nouveau format, chacune avec un exercice par notion : le contenu existe, il ne manque que l'endroit où le faire. Plus on publie de leçons sans cet entraînement, plus les élèves prennent l'habitude de lire sans s'exercer.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Aucune trace de l'entraînement de la fiche : ni copie, ni note, ni maîtrise, ni pause, ni historique (grill 1).
- L'« Entraînement illimité » des maquettes (valeurs tirées au hasard, « Nouvel exercice », score de séance) : supprimé, sans chantier de suivi (grill 12).
- Les exercices d'entraînement des 58 leçons autres que les deux leçons pilotes, Thalès et Texte argumentatif (grills 3 et 14).
- Le visiteur non connecté : il ne voit jamais « Je m'entraîne » (grill 4).
- La coupe « Voir plus » au-delà de la place de l'exercice : le #393 reste un /bugfix à part (grill 5).
- Une question qui mélange plusieurs types (grill 9).
- L'assignation, la liste ou le suivi d'un exercice d'entraînement : il n'existe que dans la fiche (grill 16).
- Un indice qui coûte des points, ou un réglage des indices par l'enseignant (grill 11).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| L'exercice fait dans la fiche est le même que celui de « Prépare interros », qui compte pour la note, la maîtrise, le badge et la pause après 3 copies. La copie faite dans la fiche compte-t-elle ? | Non : entraînement seul (porteur, 2026-10-30) | Rien n'est enregistré depuis la fiche : ni copie, ni note, ni maîtrise, ni pause ; l'élève refait autant qu'il veut. À trancher ensuite : l'élève voit dans la fiche les questions et la correction de l'exercice noté, ce qui rend la note de « Prépare interros » facile à obtenir |
| L'élève voit dans la fiche les mêmes questions et la même correction que l'exercice noté : sa première copie notée peut être un 20/20 fait les réponses en tête, sans passer par la pause. Que fait-on ? | Un exercice à part (porteur, 2026-10-30). Écartés : accepter le risque, juste/faux sans la bonne réponse, ouverture après une 1re copie | La fiche n'affiche jamais l'exercice noté de « Prépare interros » ni sa correction. Chaque notion reçoit son propre exercice d'entraînement, distinct, que l'équipe écrit et importe. Ce contenu n'existe pas encore pour les 60 leçons : il faut décider ce que montre une notion qui n'en a pas, et qui l'écrit |
| L'exercice d'entraînement à part n'existe pour aucune des 60 leçons : le jour de la livraison, aucune notion n'en a. Comment livre-t-on ? | Avec une leçon pilote (porteur, 2026-10-30). Écartés : livrer sans contenu, attendre les 60 leçons, section toujours visible avec un message | « Je m'entraîne » ne s'affiche que sur une notion qui a son exercice d'entraînement ; ailleurs, la fiche reste en 4 blocs. Le chantier comprend l'écriture et l'import des exercices d'entraînement d'une leçon pilote, toutes ses notions, et c'est sur elle que le challenger teste. Les 59 autres leçons sont hors périmètre |
| Qui peut faire l'exercice d'entraînement et voir sa correction : enseignant, équipe, élève d'une autre classe, visiteur ? | Les comptes connectés seulement (porteur, 2026-10-30). Écartés : tous ceux qui voient la fiche, les élèves seuls | Tout compte connecté qui voit la fiche (élève, enseignant, équipe) peut répondre et voir la correction, et voit la même chose que l'élève. Le visiteur ne voit jamais « Je m'entraîne » ni sa correction. Aujourd'hui, les pages publiques du catalogue s'arrêtent à la matière et ne montrent pas la fiche : la règle doit tenir si une fiche devient publique un jour |
| La coupe « Voir plus » des 150 mots tombera presque toujours avant « Je m'entraîne » de la première notion, et le #393 a vu une partie visible finir sur l'annonce d'un élément caché. Où se place l'exercice par rapport à la coupe ? | Toujours après la coupe (porteur, 2026-10-30). Écartés : compté dans les 150 mots, corriger #393 dans ce chantier | L'exercice ne compte aucun mot, et la coupe ne tombe jamais sur lui : il est soit visible en entier, soit caché en entier jusqu'à « Voir plus ». La partie visible ne finit jamais sur l'annonce de l'exercice. #393 reste un /bugfix à part |
| *(revu au grill 6 bis)* Qui corrige une réponse donnée dans la fiche : le serveur (sans rien garder) ou le navigateur ? Plafond du JavaScript commun : 61 Ko gzip (ADR-0114), marge de quelques octets | Le navigateur (porteur, 2026-10-30). Écartés : le serveur sans rien garder, le corrigé déplié sans vérification | Les bonnes réponses de l'exercice d'entraînement sont dans la page, lisibles dans le code source par tout compte connecté qui voit la fiche : on l'accepte, car cet exercice n'est pas noté et diffère de l'exercice noté (grill 2). Elles ne sont jamais écrites dans la page d'un visiteur. La logique de correction se charge à la demande, hors du JavaScript commun, et le plafond de 61 Ko ne bouge pas (pas de nouvel ADR de budget). Les règles des types de questions existent déjà côté serveur : les écrire aussi en JavaScript fait deux sources à garder d'accord, et les tests doivent le prouver. Sans JavaScript, l'exercice se lit mais ne se vérifie pas |
| Les types de réponse de l'exercice d'entraînement (capture du porteur : réponse chiffrée avec unité « AN (cm) = … », choix « parallèles / pas parallèles », boutons Vérifier · Indice · Correction) sont-ils propres à la fiche ? | Non : ils doivent servir aussi aux exercices des interrogations et des devoirs (porteur, 2026-10-30) | Un seul catalogue de types de questions, partagé entre l'entraînement de la fiche et les exercices notés : pas de type réservé à la fiche. Tout type ajouté ou étendu ici (par exemple plusieurs cases dans une même question) passe par les règles de notation de l'ADR-0115 et demande un ADR. Avec la correction dans le navigateur (grill 6), chaque type a deux règles, une côté serveur pour la note et une en JavaScript pour la fiche, qui doivent rendre le même verdict : à reprendre au grill 7 |
| *(grill 6 bis)* Puisque les types sont partagés, corriger la fiche dans le navigateur donne deux règles par type, et « 4,2 cm » pourrait être juste dans la fiche et faux au devoir. Garde-t-on le navigateur ? | Non, on passe au serveur (porteur, 2026-10-30). Écarté : le navigateur, comme la maquette Thalès | Le serveur corrige la fiche avec les règles qui donnent la note, sans rien enregistrer : un verdict identique partout. Aucune bonne réponse dans la page, ni pour un compte connecté ni pour un visiteur. Il faut une route nouvelle qui corrige sans enregistrer, protégée comme la fiche (comptes connectés qui voient la leçon) et freinée contre les envois en rafale. Le JavaScript ajouté se limite à Turbo, déjà chargé ; sans JavaScript, « Vérifier » recharge la page sur la notion. Compter environ une demi-seconde par « Vérifier » sur réseau mobile |
| Quels types de questions l'exercice d'entraînement accepte-t-il ? | Les 8 types existants, plus une nouveauté : plusieurs cases dans une même question (« AN (cm) = …  MN (cm) = … »), pour la fiche comme pour les interrogations et les devoirs (porteur, 2026-10-30). Écartés : les types existants seuls, ceux des maquettes seuls | La réponse rédigée et le cahier n'ont pas de verdict : « Correction » montre le corrigé type. Une question à plusieurs cases change le modèle des questions et le calcul de la note de l'ADR-0115 : ADR obligatoire, migration, import, écran de la copie, page du résultat et vue de l'enseignant touchés. À trancher : comment une question à plusieurs cases se note (tout ou rien, ou points répartis par case) et quels types la portent |
| Une question à plusieurs cases vaut 2 points ; l'élève trouve AN mais pas MN. Comment la note la compte-t-elle ? | Points répartis par case : 1/2 ici (porteur, 2026-10-30). Écartés : tout ou rien, renoncer aux cases multiples | Chaque case a ses points, par défaut les points de la question répartis à égalité au demi-point près (à vérifier : 1 point sur 3 cases ne tombe pas juste). Le score de l'ADR-0115 devient une somme de points par case, et non plus par question : une question à une case garde exactement sa note d'aujourd'hui, aucun exercice en production ne change de note. Lacunes, maîtrise et badge se lisent sur ce score, sans autre changement |
| Quels types peuvent avoir plusieurs cases dans une même question ? | Réponse chiffrée, choix dans une liste et texte à trous (porteur, 2026-10-30). Écartés : chiffré seul, mélange de types dans une question | Une question garde un seul type. Chaque `___` de l'énoncé est une case, avec ses propres réponses acceptées (trous), sa propre liste (liste) ou sa valeur, son unité et sa tolérance (chiffré). Le texte à trous perd sa règle « un seul `___` ». Les questions à une case restent valides telles quelles. Une question mélangée (deux rapports puis une conclusion, Ex. 6 de la maquette Thalès) s'écrit en deux questions qui se suivent |
| La maquette a un bouton « Indice ». Où s'affiche-t-il : fiche seulement, aussi pendant une copie notée, ou nulle part ? | Dans la fiche et pendant une copie notée (porteur, 2026-10-30). Écartés : fiche seulement, pas d'indice | Un indice facultatif par question, écrit à l'import. Pendant une interrogation ou un devoir, l'ouvrir est un fait de la copie : il faut l'enregistrer et décider s'il coûte des points et ce que l'enseignant en voit (grill 11). Dans la fiche, rien n'est enregistré (grill 1) |
| Pendant une copie notée, l'élève ouvre l'indice puis répond juste. Combien vaut sa réponse, et que voit l'enseignant ? | Gratuit, mais visible (porteur, 2026-10-30). Écartés : l'indice coûte des points, réglage par l'enseignant | La note ne change pas. On enregistre sur la copie le seul fait « indice ouvert » pour la question, qu'il soit ouvert une fois ou dix. L'enseignant le voit sur la copie et dans le suivi, l'élève sur sa page de résultat. L'ouverture doit être enregistrée par le serveur au moment du clic : un indice déjà présent dans la page de la copie pourrait se lire sans être compté. Une question sans indice n'a pas de bouton |
| La maquette a un « Entraînement illimité » (valeurs tirées au hasard, « Nouvel exercice », score de séance). Le met-on dans ce chantier ? | Non, on le supprime (porteur, 2026-10-30). Écartés : un générateur pour la leçon pilote, une banque de variantes | Ni générateur, ni « Nouvel exercice », ni score de séance. L'élève refait le même exercice d'entraînement, aux mêmes valeurs. Rien ne reste de ce bloc dans la fiche, pas même en suivi |
| Quand l'élève peut-il voir la correction d'un exercice d'entraînement : tout de suite, après un « Vérifier », après 2 essais ? | Après un premier « Vérifier », même avec une réponse fausse ou vide (porteur, 2026-10-30). Écartés : tout de suite comme la maquette, après 2 essais | Le corrigé n'est jamais dans la page avant « Vérifier ». La réponse du serveur à « Vérifier » porte le verdict de chaque case et le corrigé, que le bouton « Correction » déplie. Pour la réponse rédigée et le cahier, « J'ai fini » tient lieu de « Vérifier » et montre le corrigé type. Envoyer des cases vides suffit à voir le corrigé : c'est voulu, puisque rien n'est noté |
| Quelle leçon pilote ? | Deux : « Propriétés de Thalès dans un triangle » (3e, maths) et « Texte argumentatif » (3e, français) (porteur, 2026-10-30). Écartées : l'une ou l'autre seule | Le chantier écrit, importe et fait relire les exercices d'entraînement de chaque notion des deux leçons. À elles deux, elles couvrent le chiffré avec unité, la liste et les trous à plusieurs cases, la réponse rédigée, les indices et une figure. Le challenger teste sur les deux. Deux fois plus de contenu que prévu au grill 3 |
| *(revu au grill 16)* L'enseignant peut-il voir l'exercice d'entraînement ailleurs que dans la fiche, ou l'assigner comme un exercice noté ? | Oui, il peut l'assigner (porteur, 2026-10-30). Écarté : visible dans la fiche seulement | Assigné, l'exercice d'entraînement devient noté pour la classe : copie, note, maîtrise et pause comme tout exercice. Le risque du grill 2 revient pour lui seul : l'élève peut avoir vu sa correction dans la fiche avant de faire la copie notée. Restent à trancher : d'où l'enseignant l'assigne, et ce que la fiche montre à un élève qui a cet exercice à rendre (grill 16) |
| *(grill 16)* Un élève a l'exercice d'entraînement de sa notion à rendre jeudi. Que lui montre la fiche lundi ? | Rien de tel : pas d'assignation sur les exercices d'entraînement (porteur, 2026-10-30). Le grill 15 est annulé | L'exercice d'entraînement n'existe que dans la fiche : absent de « Prépare interros », des listes d'exercices, de la recherche, des assignations et du suivi. Il n'a jamais de copie. Le risque du grill 2 reste fermé. L'enseignant qui veut une note assigne l'exercice noté de la notion |

## Cas limites identifiés

- Une notion sans exercice d'entraînement (toutes celles des 58 autres leçons) : la fiche reste en 4 blocs, sans titre ni message vide.
- Un exercice d'entraînement supprimé ou réimporté pendant que l'élève a la fiche ouverte : « Vérifier » répond sur la version en place, sinon par un message « Cet exercice a changé, recharge la fiche », jamais par une erreur 500 ni un verdict sur des questions qui n'existent plus.
- La leçon ou la notion dépubliée, ou un compte qui perd l'accès à la leçon, entre l'affichage et « Vérifier » : refus, comme la fiche elle-même.
- « Vérifier » avec toutes les cases vides : verdict « à compléter » par case, et le corrigé devient visible (grill 13).
- Une réponse chiffrée écrite « 4,2 », « 4.2 », « 4,2 cm », « 4,2cm » ou « 4 200 » : même lecture que la copie notée, puisque c'est la même règle (grill 6 bis).
- Une question à plusieurs cases dont les points ne se répartissent pas juste (1 point sur 3 cases) : règle d'arrondi à fixer dans l'ADR, la note ne dépasse jamais 20.
- Un exercice noté déjà en production : une case, aucune note changée (grill 8).
- Un indice ouvert dix fois sur la même question : un seul « indice ouvert » (grill 11).
- Des envois en rafale sur « Vérifier » (robot, double-clic) : freinés, sans rien enregistrer.
- Sans JavaScript : la fiche se lit, et « Vérifier » recharge la page sur la notion avec le verdict.
- La coupe « Voir plus » : l'exercice n'est jamais coupé en deux (grill 5).
- Un élève de plusieurs classes ou un enseignant de deux écoles : sans objet, puisque rien n'est enregistré depuis la fiche et que l'accès est celui de la fiche.

## Questions encore ouvertes

- Où vit l'exercice d'entraînement : un exercice `assessment` marqué « entraînement » et exclu partout, ou un contenu de la fiche (`catalog`) qui réutilise les règles des types ? À trancher dans l'ADR. La règle de correction reste dans `assessment`, qui porte les types de questions et la note.
- La règle d'arrondi des points répartis par case (ADR).
- Qui écrit les exercices d'entraînement des deux leçons pilotes, et qui les relit : l'équipe, comme les leçons v3 (validation enseignante) ?
- Le texte exact des retours par case (« juste », « à revoir », « à compléter » dans la maquette) et du message global : UDR.
