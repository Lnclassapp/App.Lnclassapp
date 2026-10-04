# Memo — Inscription de la direction sans invitation

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/inscription-direction` |
| **Programme** | — |

---

## Le problème

La direction d'un établissement n'entre sur Lnclass que si l'équipe l'invite : l'équipe doit connaître le numéro de chaque chef d'établissement, créer l'invitation et transmettre un lien valable 72 h. Une direction qui découvre Lnclass par ses enseignants ne peut rien faire seule : rien sur la page d'accueil ne lui parle, et aucune page d'inscription n'existe pour elle. Personne ne peut non plus retirer un compte direction devenu indésirable.

## Pour qui

- **La direction** (Proviseur, Censeur, Adjoint au chef d'établissement, Directeur des études…), au moment où elle découvre Lnclass : elle crée son compte seule, avec le code d'établissement que ses enseignants utilisent.
- **La direction déjà en place**, qui voit arriver les nouvelles directions et peut retirer un imposteur.
- **L'équipe Lnclass**, prévenue de chaque retrait, qui peut retirer et restaurer.

## Pourquoi maintenant

L'espace direction est en production avec ses gestes (lien, classes, enseignants) : il attend des directions. L'invitation par l'équipe ne passe pas à l'échelle du déploiement par les enseignants (parrainage) : chaque établissement actif doit pouvoir faire entrer sa direction sans attendre l'équipe.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Le renommage des adresses `/school-admin/…` en `/school-space/…` (Q5 : ne rien changer).
- Les fonctions de direction (Proviseur, Censeur…) : un compte direction reste « direction », sans fonction.
- Un code réservé à la direction, distinct du code d'établissement (Q2).
- Une validation de l'inscription par l'équipe ou par une autre direction (Q1).
- Un compte à double rôle enseignant et direction (Q8).
- Un e-mail ou un SMS à l'équipe à chaque retrait (Q6) : le signal est un bloc à l'écran.
- Le plafond des directions invitées par l'équipe (Q12) : l'invitation reste sans plafond.
- Le second facteur pour la direction.
- L'élève et le parent : rien ne change pour eux.

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
| Q11. Combien de temps est-on « nouvel arrivant » ? | 7 jours après la création du compte direction. | Même durée que le bandeau d'arrivée : pendant 7 jours, la nouvelle direction voit le bloc « Direction » sans « Retirer ». |
| Q12. Les directions invitées par l'équipe comptent-elles dans le plafond ? | Non : seules les directions inscrites par le code comptent (au plus 3 actives). | Il faut savoir, pour chaque compte direction, s'il est arrivé par invitation ou par le code. L'affichage « 2 / 3 » ne compte que les arrivées par le code. |

## Cas limites identifiés

- Établissement en brouillon ou désactivé : son code refuse l'inscription d'une direction, avec le même message qu'un code inconnu.
- Code de classe saisi à la place du code d'établissement : message dédié, comme à l'inscription enseignant.
- Deux inscriptions simultanées sur la 3ᵉ place : une seule passe, l'autre reçoit le refus du plafond.
- Plafond atteint : refus « Votre établissement a déjà 3 comptes direction créés avec son code. Contactez l'équipe Lnclass. » ; l'équipe peut inviter.
- Numéro déjà lié à un compte Lnclass (enseignant, élève, direction, équipe, ou compte archivé) : refus, sans dire quel rôle.
- Une direction tente de se retirer elle-même : impossible, le geste n'apparaît pas sur sa ligne.
- Une direction de moins de 7 jours : pas de « Retirer » ; requête forgée refusée.
- Retirer la dernière direction active de l'établissement : permis (pour l'équipe) ; l'établissement reste sans direction jusqu'à la prochaine inscription ou invitation.
- Deux directions qui se retirent l'une l'autre en même temps : la première passe ; la seconde est refusée, car son auteur est archivé.
- Compte archivé : la connexion est refusée et toutes ses sessions sont fermées au moment de l'archivage.
- Restauration quand les 3 places « par le code » sont prises : refusée, avec un message. Une direction invitée se restaure toujours.
- Restauration après J+30 : impossible, le compte a été supprimé.
- Suppression à J+30 : le compte est anonymisé comme une suppression de compte élève (nom « Compte supprimé », numéro effacé). Le journal d'audit garde le retrait et la suppression.
- Bandeau d'arrivée : il n'est pas montré à la personne arrivée ; une direction archivée n'en génère pas.
- Une direction d'un autre établissement ne voit ni ne retire jamais les directions de A.

## Questions encore ouvertes

- Aucune.
