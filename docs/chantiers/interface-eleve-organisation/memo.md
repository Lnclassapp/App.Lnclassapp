# Memo — Organisation des écrans élève : accueil, « Ma classe » et rythme d'une session

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers `Develop`) |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `feature/interface-eleve-organisation` |
| **Programme** | — |

---

## Le problème

Trois écrans de l'élève ne suivent pas l'organisation que le porteur veut pour Lnclass.

- **L'accueil** commence par « À faire », puis les annonces, la classe et une carte « Cours » qui ne dit rien. L'élève ne voit ni sa classe en premier, ni ses matières.
- **« Ma classe »** ne montre plus que la classe et son code. Depuis qu'un cours ne s'assigne plus, l'élève n'y retrouve ni les cours sur lesquels porte son travail, ni ses exercices, ni ses scores.
- **Une session d'exercice** coûte deux allers-retours jusqu'au serveur par question : l'envoi de la réponse (le verdict), puis « Question suivante » (la question). Le porteur trouve le rendu des réponses et des corrections lent, et demande que la politique de cache soit respectée.

## Pour qui

L'élève (`Student`), sur téléphone d'entrée de gamme et en 3G le plus souvent :
- en ouvrant l'application (accueil) ;
- en ouvrant « Ma classe » depuis la barre de navigation ;
- pendant une session, entre deux questions.

## Pourquoi maintenant

Le porteur a fixé l'ordre des sections et le contenu de « Ma classe » le 2026-10-05. La politique de cache (ADR-0076) vient d'être décidée : elle dit que ce qui coûte, c'est chaque aller-retour, et une session en enchaîne deux par question.

## Hors périmètre

- **Aucun cache serveur, fragment ou ETag** sur la session ni sur son résultat (ADR-0076 §4.1, ADR-0054 : aucun fragment ne contient de proposition correcte).
- La famille téléphone de l'UDR-0058 §3.2 (bandeau bleu, carte « Prochain exercice ») : elle reste à faire par `interface-epuree`, phase 2.
- Les cases « Paiement » et « Inviter » de la grille des matières : le paiement n'existe pas, et le code de la classe est déjà dans la carte « Ma classe » (dire une chose une fois).
- Le contenu et le fonctionnement des annonces (`feature/annonces`, `feature/annonces-v2`) : seule leur place change.
- Les écrans de l'enseignant, de la direction et de l'équipe.
- Le résultat de session (`/sessions/:id/result`) : il reste une page, atteinte en un aller-retour (plafond de l'ADR-0076 §4.2 respecté).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les annonces n'existent pas encore : que met-on dans la section ? | Le porteur : « annonce existe et est affichée juste après la section à faire ». La copie locale de `Develop` était en retard. | `Develop` remis à jour avant tout travail. La section reprend le carrousel existant (UDR-0071 §3.5), seule sa place change. |
| Que montre « Matières » ? | Les matières avec leurs icônes, comme « Niveaux » pour la direction et « Cours » pour l'enseignant. | Bulles `ui_subject_bubble` existantes ; elles remplacent la carte « Cours ». Point ambre de retard (UDR-0062 §3.3), donnée déjà lue par la query. |
| Quel score pour « Exercices traités » ? | Le meilleur score. | Une ligne par exercice, meilleur score sur 20, triée par dernière session terminée ; elle ouvre le résultat de la dernière session. |
| Comment procède-t-on (branche, grill) ? | Branche `feature/…`, chantier condensé à partir des consignes, PR brouillon vers `Develop`. | Pas de grill question par question : les réponses ci-dessus en tiennent lieu, les choix restants sont écrits en « Questions encore ouvertes ». |
| « Cours assignés » : un cours ne s'assigne plus (ADR-0072). Lesquels montrer ? | Décision de l'auteur, révisable : les cours qui contiennent au moins un exercice assigné à la classe. | Une lecture de plus, sans table ni contrat nouveaux. |
| Un exercice assigné et déjà fait apparaîtrait dans « assignés » et « traités ». | Décision de l'auteur, révisable : « assignés » ne garde que ceux qui ne sont pas encore faits. | Chaque exercice n'est dit qu'une fois sur la page (R6 de l'UDR-0057). |
| La politique de cache autorise-t-elle un cache sur la session ? | Non : ADR-0076 §4.1, le HTML ne se met jamais en cache, et un 304 paie le même aller-retour. Le levier est le nombre de requêtes en série. | La question suivante arrive avec le verdict, dans le même Turbo Stream. « Question suivante » l'affiche sans requête : 1 aller-retour par question au lieu de 2. |

## Cas limites identifiés

- Élève sans classe principale active : les deux écrans gardent leur saut unique vers l'écran de sortie.
- Aucun cours publié au niveau de l'élève : la section « Matières » montre son état vide et le lien vers le catalogue.
- Zéro, un ou plus de trois exercices assignés ou traités : état vide, une ligne, « Voir plus ».
- Un exercice traité puis retiré de son cours, ou d'un autre niveau : il n'apparaît pas (règle du niveau, UDR-0013).
- Session ouverte dans deux onglets : la question affichée sans requête peut avoir déjà été répondue ailleurs. L'envoi est alors refusé comme aujourd'hui (toast et retour à l'état réel, ADR-0054).
- Sans JavaScript : « Question suivante » reste un lien vers la session, qui rend la question.
- Dernière question : le verdict propose « Voir mon résultat », aucune question n'est jointe.

## Questions encore ouvertes

- « Cours assignés » = cours qui contiennent un exercice assigné : à confirmer par le porteur.
- « Exercices assignés » sans ceux déjà faits : à confirmer par le porteur.
- La mesure en millisecondes depuis Abidjan (ADR-0076 §4.3) n'est pas reprise ici : le compte de requêtes vaut partout.
