# Memo — Accueil enseignant tourné vers l'action

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-26 |
| **Branche** | `feature/accueil-enseignant-actions` |
| **Programme** | — |

---

## Le problème

L'audit des écrans de l'enseignant (test-ecrans, jeu standard, enseignant de maths à 14 classes) montre un accueil qui ne dit pas quoi faire :

- les classes passent une à une dans un carrousel ; presque toutes disent « Aucun exercice en cours », et la classe qui a 38 élèves en retard n'est pas visible sans faire défiler ;
- les ronds de niveaux ouvrent les fiches de cours, mais rien ne le dit, et ils portent tous la même illustration ;
- une section « Aucun exercice à suivre cette semaine » s'affiche vide ;
- la barre du haut (avatar, « Besoin d'aide ? ») revient sur chaque page intérieure, alors que chaque page a déjà son retour en tête.

Sur la page d'une classe, 40 lignes répètent la même phrase de progression et la même médaille ; sur ordinateur, la colonne de gauche est vide pendant que la liste descend très bas. Sur le suivi d'un devoir, la carte « Prochain geste » demande de relancer les élèves sans donner de moyen de le faire.

## Pour qui

L'enseignant (Teacher), à l'ouverture de l'application, puis quand il entre dans une classe ou dans le suivi d'un devoir.

## Pourquoi maintenant

Pilote en cours : les enseignants ouvrent l'accueil et n'y trouvent pas la classe en retard. Le porteur a tranché toutes les décisions sur maquettes le 2026-11-26.

## Hors périmètre

- Élève, direction, équipe, parent : rien ne change pour eux (barre du haut comprise).
- Le bouton « Retirer de la classe » de la fiche élève, la hauteur des lignes du suivi d'un devoir, le lien « Retour à la classe » de l'affiche, la leçon en double des données de démo : session complémentaire séparée.
- Aucun envoi par Lnclass : la relance ouvre WhatsApp, l'enseignant choisit le groupe et envoie lui-même.
- Pas de nouvelle page « liste des classes » : les autres classes s'ouvrent sur l'accueil même.
- La barre latérale sur ordinateur reste (option prudente, à trancher).
- La coque Android « Lnclass Teacher » garde ses barres (elle n'affiche déjà pas l'en-tête du site).

## Ce que le grill a révélé

> Source : décisions du porteur sur maquettes, 2026-11-26 (transmises par la session d'orchestration), et vérifications dans le code.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que montre l'accueil en premier ? | Une liste « À suivre » : seulement les classes qui ont des élèves en retard ou des exercices en cours, triées par urgence, une ligne par classe (« Tle D » / « 38 élèves en retard sur 1 exercice », chevron, ouvre la classe), puis « Voir mes N autres classes ». (porteur) | Le carrousel des classes disparaît ; il faut lire, par classe, les élèves en retard et le nombre de devoirs en retard. |
| Où l'enseignant trouve-t-il le code de la classe si la carte disparaît ? | Aujourd'hui, **seulement** sur la carte de l'accueil : la page de la classe l'a retiré (CA-I1). (code) | Le code et son bouton « Copier » reviennent dans le bloc « Inscrire vos élèves » de la page de la classe. Sans cela, le code serait perdu. |
| « Voir mes N autres classes » mène où ? | La page « Mes classes » est une déclaration (bascules), sans lien vers chaque classe. (code) | Option prudente : les autres classes se déplient sur l'accueil, même format de ligne ; « Mes classes » reste la page pour ajouter ou retirer. À trancher. |
| Et s'il n'y a rien à suivre, ou aucune classe ? | Jamais de section vide (skill ecrans-wave). (porteur) | Rien à suivre : la liste s'intitule « Mes classes » et montre les classes. Aucune classe : la carte « Ajoutez vos classes » existante. |
| Les ronds de niveaux sont-ils compris ? | Titre visible « Fiches de cours · Mathématiques » ; chaque rond prend une teinte `tint-*` en rotation et le nom court du niveau (« 6e », « 2de A », « Tle D ») à la place de l'icône ; « Inviter » garde son icône. (porteur) | Un nom court de niveau (« 6ème » → « 6e », « 2nde » → « 2de », « 1ère » → « 1re ») ; une variante texte du rond. Thème sombre vérifié. |
| Une section vide reste-t-elle ? | Non : « Cette semaine » vide n'est plus rendue. (porteur) | La section disparaît sans exercice ; l'invitation à choisir ses matières reste. |
| Barre du haut : où ? | Seulement sur l'accueil de l'enseignant ; ailleurs, retour par « ‹ Accueil » (ou fil d'Ariane) en tête de page. Pas de barre basse (inchangé). Barre latérale sur ordinateur : gardée, à trancher. (porteur) | Le shell retire l'en-tête du site pour l'enseignant hors accueil. Pages sans retour à corriger : « Reçues », « Mes annonces », « Rejoindre un établissement ». Nouvelle UDR qui amende UDR-0006, UDR-0082 et UDR-0134 §3.3, §3.14. |
| Que perd l'enseignant sans barre du haut ? | « Mon compte » et « Besoin d'aide ? » ne sont plus qu'à l'accueil (et dans la coque Android). (code) | Écrit dans l'UDR (§4) et dans `## À trancher` ; l'accueil est à un geste. |
| La liste des élèves d'une classe ? | En tête « 38 en retard » et « 2 à jour » ; élèves en retard d'abord ; ligne = nom et état (« En retard » / « À jour »), ≥ 44 px ; « Voir plus (n) » au-delà de quelques lignes ; recherche et filtres par médaille gardés. Sur ordinateur, rééquilibrer. (porteur) | La lecture de la liste trie par retard et compte retard / à jour pour toute la classe ; dix élèves puis « Voir plus (n) » ; sur ordinateur, la liste ainsi bornée équilibre les deux colonnes (UDR §3.4). |
| Relancer, comment ? | Bouton « Relancer sur WhatsApp » dans « Prochain geste », lien de partage avec le devoir, son échéance et le lien de l'exercice ; seulement s'il reste des élèves à relancer ; Lnclass n'envoie rien. (porteur) | Réutilise `whatsapp_share_url` ; aucun nom d'élève dans le message. |
| Contexte borné ? | `classroom` porte tout (accueil, classe, suivi) ; `assessment` ne prête que la carte « Prochain geste ». (code) | Pas de nouveau port, pas de table : pas d'ADR. |

## Cas limites identifiés

- Enseignant sans classe : la carte « Ajoutez vos classes », sans liste « À suivre ».
- Classes, mais aucune à suivre : la liste « Mes classes », jamais un titre seul.
- Toutes les classes à suivre : pas de « Voir mes autres classes ».
- Classe sans élève : ni retard ni « en cours » ne la rendent « à suivre » (aucun élève à relancer).
- Devoir sans échéance : jamais « en retard ».
- Élève parti de la classe : ni compté ni listé.
- Tous les élèves ont fait le devoir : pas de bouton de relance.
- Personne n'a fait le devoir (pas encore de « Prochain geste ») : le bouton paraît dans l'état vide.
- Niveau sans série : « 6e » ; plus de niveaux que de teintes : la rotation reprend.

## Questions encore ouvertes

- Voir `journal.md` § À trancher (barre latérale, autres classes dépliées sur l'accueil, avatar dans la ligne d'élève, perte de « Mon compte » hors accueil).
