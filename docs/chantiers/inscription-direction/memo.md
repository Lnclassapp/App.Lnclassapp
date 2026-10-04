# Memo — Inscription de la direction sans invitation

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/inscription-direction` |
| **Programme** | — |

---

## Le problème

Qu'est-ce qui ne va pas aujourd'hui ? Décrire la situation, pas la solution.

## Pour qui

Quel acteur (Student, Teacher, Team, Parent, SchoolStaff) et à quel moment de son parcours.

## Pourquoi maintenant

Qu'est-ce qui rend ce chantier urgent ou prioritaire ? Si la réponse est « ce serait bien », le chantier attend.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- …

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Une direction inscrite par la nouvelle page : quand accède-t-elle aux données de son établissement ? | Immédiatement, avec le code d'établissement (choix du porteur, contre la recommandation d'une validation par l'équipe). | Pas d'état « en attente » pour la direction. Le code d'établissement, déjà partagé avec les enseignants, devient une clé d'accès au travail de tous les élèves : risque accepté, à encadrer (Q2). Amende ADR-0044 et ADR-0065 (rattachement par invitation seulement). |
| Q2. Quel code la direction saisit-elle pour s'inscrire ? | Le code d'établissement, celui des enseignants, avec un plafond (contre la recommandation d'un code de direction distinct). | Aucun nouveau code. Le plafond est la seule barrière : il doit être compté côté serveur, sous verrou, pour qu'il ne cède pas à deux inscriptions simultanées. |
| Q3. Quel plafond, et au-delà ? | 3 comptes direction par établissement par cette page ; au-delà, la page refuse et renvoie vers l'équipe Lnclass, qui peut toujours inviter. | Message de refus dédié. L'invitation par l'équipe reste le recours et n'est pas plafonnée par ce chantier. |
| Q4. Qui retire un compte direction inscrit par erreur ou par un imposteur ? | L'équipe, et aussi la direction, qui peut retirer une autre direction de son établissement (contre la recommandation « équipe seule »). | Nouveau geste dans deux espaces. Une direction ne se retire jamais elle-même. Risque accepté : un imposteur peut retirer la vraie direction ; l'équipe reste le recours (réinvitation). La place libérée compte de nouveau dans le plafond. |
| Q4 bis. Que devient le compte retiré ? | Il est **archivé** (plus de connexion, plus d'accès à l'établissement), puis **supprimé automatiquement après 30 jours**. L'équipe est **signalée** de chaque retrait. | Un état « archivé » du compte direction avec sa date, une tâche planifiée de suppression à J+30, un signal côté équipe. La place se libère dès l'archivage. Suppression d'un compte = données personnelles effacées ; l'historique d'audit garde la trace du retrait. |
| Q5. Le renommage « school-admin » → « school-space » porte sur quoi ? | Ne rien changer. | Le renommage sort du chantier : les adresses de l'espace direction restent `/school-admin/…`. Écrit dans `Hors périmètre`. |
| Q6. Comment l'équipe est-elle prévenue, et peut-elle annuler ? | Un bloc « Directions retirées » sur l'accueil de l'équipe et sur la fiche de l'établissement (qui a retiré qui, quand, date de suppression) ; l'équipe peut « Restaurer » avant J+30. | La direction restaurée reprend une place du plafond : si les 3 places sont prises, la restauration est refusée. Pas d'e-mail. |
| Q7. Où mettre l'accès à l'inscription de la direction sur la page d'accueil ? | Un lien discret (« Vous êtes la direction d'un établissement ? ») sous les boutons « Je suis élève » / « Je suis enseignant » et dans le pied de page, **plus une section dédiée « Établissements »** sur la page d'accueil, sur le modèle de la section « Enseignants », avec son bouton vers l'inscription. | La page d'accueil change : trois points d'entrée vers la même page. La section a son ancre, liée depuis le pied de page. |
| Q8. Un enseignant déjà inscrit, aussi Censeur ou Directeur des études : que fait la page avec son numéro ? | Refus : « Ce numéro a déjà un compte Lnclass. » ; il s'inscrit comme direction avec un autre numéro. | Un compte = un rôle : le modèle des comptes ne change pas. Le message de refus le dit, sans révéler le rôle du compte existant. |
| Q9. Comment la direction voit-elle les autres comptes direction ? | Un bloc « Direction » sur la page Établissement (nom, date d'arrivée, « par invitation » ou « par le code », places restantes « 2 / 3 », ⋮ → « Retirer » sur les autres) **et** un bandeau « X a rejoint la direction le … » pendant 7 jours sur l'accueil des autres directions. | Deux affichages côté direction. Le bandeau ne s'affiche pas à la personne arrivée elle-même. Il faut garder le mode d'arrivée (invitation ou code) de chaque compte direction. |
| Q10. Un nouvel arrivant peut-il retirer une autre direction ? | Non (décision du porteur). | Le geste « Retirer » est refusé, et masqué, pour une direction nouvellement arrivée. Un imposteur qui vient de s'inscrire ne peut donc pas évincer la vraie direction. La durée qui définit « nouvel arrivant » reste à fixer (proposition : 7 jours, comme le bandeau d'arrivée). |

## Cas limites identifiés

- …

## Questions encore ouvertes

- Durée qui fait d'une direction un « nouvel arrivant » sans droit de retrait (proposition : 7 jours).
- Les directions invitées par l'équipe comptent-elles dans le plafond de 3 ?
