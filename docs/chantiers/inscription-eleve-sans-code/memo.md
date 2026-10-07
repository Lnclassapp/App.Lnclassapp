# Memo — Inscription des élèves sans code de classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-07 |
| **Branche** | `feature/inscription-eleve-sans-code` |
| **Programme** | — |

---

## Le problème

Un élève ne peut aujourd'hui créer son compte que s'il détient le **code de sa classe** :

1. il le saisit sur l'écran « Rejoindre une classe » ;
2. ou il ouvre le **lien de la classe**, qui porte ce même code.

Sans code, il n'a aucune entrée. Un élève qui découvre Lnclass seul, ou dont l'enseignant n'a pas transmis le code, reste à la porte.

Le porteur a décidé le 2026-10-07 (chantier `inscription-enseignant`, Q20) de **retirer le code de classe** et de donner à l'élève **deux flux d'inscription, comme pour l'enseignant**. Le grill les a précisés :

- **l'inscription standard, « à froid »** : l'élève choisit « Je suis élève », sélectionne sa **DRENA**, son établissement, son niveau, puis sa classe, et saisit son nom complet, son genre, son numéro et son code secret. Il entre dans la classe tout de suite ;
- **l'inscription par le lien de la classe**, où la classe est déjà désignée. Le lien ne porte plus le code ; il peut être changé.

En contrepartie de l'entrée immédiate, les enseignants de la classe, la direction et l'équipe voient les nouveaux arrivés et peuvent **retirer un élève**.

## Pour qui

- **L'élève (Student)** qui découvre Lnclass seul : l'inscription standard.
- **L'élève invité par son enseignant** : l'inscription par le lien.
- **L'enseignant (Teacher)** : il partage le lien de sa classe, peut le changer, est prévenu d'une arrivée et peut retirer un élève (Q6, Q8).
- **La direction (SchoolStaff)** et **l'équipe (Team)** : elles partagent et changent le lien d'une classe, et retirent un élève (Q11).

## Pourquoi maintenant

Des élèves veulent s'inscrire **seuls**, alors qu'aucun enseignant de leur classe n'est sur Lnclass : personne ne peut leur donner de code (Q1, 2026-10-07).

## Hors périmètre

- **L'inscription de l'enseignant** : chantier `inscription-enseignant`, en cours, dont celui-ci dépend.
- **L'inscription de la direction** et le retrait du code d'établissement : chantier `inscription-direction-sans-code`.
- **L'élève dont l'établissement ou la classe manque** : ni compte sans établissement, ni signalement à l'équipe (Q9). À rouvrir en chantier de suivi si le besoin se confirme.
- **Le parent** : il n'a pas de compte aujourd'hui, rien ne change pour lui (proposé par l'agent, Q11).
- La vérification du numéro par WhatsApp (chantier `verification-whatsapp`, au backlog).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Pourquoi maintenant : quel problème est constaté sur le terrain avec le code de classe ? | **Des élèves veulent s'inscrire seuls**, sans qu'un enseignant de leur classe soit sur Lnclass (2026-10-07). | L'inscription standard est le flux principal, pas un secours. Elle doit marcher pour une classe **sans enseignant** : aucune étape ne peut dépendre de lui. Reste à dire ce que l'élève trouve une fois inscrit dans une telle classe. |
| Q2. Sans code, que se passe-t-il quand l'élève valide la classe qu'il a choisie ? | **Entrée immédiate si la classe n'a pas d'enseignant ; sinon l'enseignant l'accepte ou le refuse** (2026-10-07). | Un nouvel état apparaît : la **demande d'adhésion en attente**, seulement pour une classe qui a un enseignant. Il faut un écran d'attente pour l'élève et un geste « accepter / refuser » pour l'enseignant. Une classe sans enseignant reste ouverte à tous : le plafond d'effectif y est le seul refus. |
| Q3. Une classe a plusieurs enseignants : qui accepte la demande ? | **N'importe lequel** : le premier qui répond décide pour tous (2026-10-07). | Chaque enseignant de la classe voit la demande ; une fois décidée, elle disparaît chez les autres. Deux réponses simultanées ne doivent en produire qu'une : la première gagne. |
| Q4. L'enseignant ne répond pas : que devient l'élève en attente ? | **Acceptation automatique** après un délai sans réponse (2026-10-07). | L'attente n'est plus un blocage, mais elle n'est plus une protection non plus : un intrus entre si l'enseignant se tait. Une tâche planifiée accepte les demandes échues ; le plafond d'effectif se rejuge à ce moment. Le délai est à fixer (Q5). |
| Q5. Quel délai avant l'acceptation automatique ? | **2 minutes** (2026-10-07). | À ce délai, l'enseignant n'a presque jamais le temps de répondre : dans les faits, l'élève entre toujours. L'attente et le geste « accepter / refuser » coûtent alors plus qu'ils ne protègent ; à confirmer ou à simplifier (Q6). |
| Q6. Que veut-on vraiment avec ces 2 minutes ? | **Simplifier** : l'élève entre toujours tout de suite ; l'enseignant est prévenu et peut le retirer après coup (2026-10-07). | **Remplace Q2 à Q5** : plus de demande en attente, plus d'écran d'attente, plus d'acceptation ni de tâche planifiée. À construire à la place : prévenir les enseignants de la classe d'une arrivée, et un geste « retirer un élève de la classe », qui n'existe pas aujourd'hui. Reste à dire ce que devient l'élève retiré (Q7). |
| Q7. Que devient l'élève retiré d'une classe ? | **Il garde son compte, sans classe, et ne revient dans cette classe-là que par le lien de l'enseignant** ; il peut choisir une autre classe (2026-10-07). | Le retrait se retient, par élève et par classe : la voie standard refuse cette classe à cet élève. Le lien de l'enseignant donne donc un droit que la voie standard n'a pas : il lève le retrait. Un lien qui fuit rouvre la porte, d'où Q8. Un élève sans classe a besoin d'un accueil qui lui propose d'en choisir une. |
| Q8. Que fait-on du lien de classe ? | **Un lien que l'enseignant peut changer** : l'ancien cesse de marcher (2026-10-07). | Le lien de classe porte un jeton remplaçable, et non plus le code. **Correction de l'exploration (2026-10-07)** : la question disait que l'enseignant remplace déjà le code de sa classe ; c'est décidé (ADR-0041) mais jamais construit. « Changer le lien » est donc un geste **nouveau**, à construire ici. Différence assumée avec le lien d'invitation des enseignants, qui est stable. Avec plusieurs enseignants par classe, il faut dire s'ils partagent un même lien et qui peut le changer. Les anciens liens à code déjà partagés cessent de marcher : à annoncer. |
| Q9. Que fait un élève dont l'établissement ou la classe n'est pas dans la liste ? | **Il ne peut pas s'inscrire** : un message lui dit de prévenir son enseignant ou sa direction (2026-10-07). | Pas de compte sans établissement, pas de circuit de signalement vers l'équipe : écrits dans `Hors périmètre`. Le formulaire a un état « introuvable » avec ce message. |
| Q10. Comment un élève déjà inscrit, mais sans classe, en rejoint-il une nouvelle ? | **Par le même choix que l'inscription** : établissement puis classe, son établissement déjà proposé ; le lien d'un enseignant marche aussi (2026-10-07). | Le code disparaît partout, y compris pour l'élève connecté. Le choix de la classe sert à deux moments : à l'inscription et depuis l'accueil d'un élève sans classe (classe archivée, ou retrait). La règle « une seule classe principale active » ne change pas. |
| Q11. Le code retiré, que voient et que peuvent faire la direction et l'équipe ? | **Les mêmes gestes que l'enseignant** : copier le lien de classe, le changer, retirer un élève (2026-10-07). | Trois acteurs partagent ces gestes : les enseignants de la classe, la direction pour les classes de son seul établissement, l'équipe pour toutes. Une classe sans enseignant garde ainsi quelqu'un pour inviter et pour retirer un intrus. Le retrait d'un élève est un pouvoir nouveau pour la direction. Les écrans de la direction et de l'équipe qui montrent le code changent aussi. |
| Q12. Après la DRENA et l'établissement, comment l'élève trouve-t-il sa classe ? | **En deux étapes** : son niveau, puis sa classe dans ce niveau (2026-10-07). | Le parcours standard a quatre choix enchaînés : DRENA → établissement → niveau → classe. Un niveau sans classe, ou dont toutes les classes sont pleines ou archivées, donne l'état « introuvable » de Q9. |
| Q13. Quelles informations personnelles, et sous quelle forme ? | **Les trois améliorations de l'enseignant sont reprises** : un seul champ « nom complet » avec aperçu du découpage, numéro nettoyé en direct, concordance du code secret en direct (2026-10-07). | Les deux inscriptions se ressemblent. Le chantier dépend des éléments d'interface de `inscription-enseignant`, pas encore livrés. La règle « premier mot = nom » s'applique à l'élève, avec la même correction à la main ; un nom complet d'un seul mot est refusé. Le nom et les prénoms restent enregistrés séparément. |
| Q14. Comment l'enseignant est-il prévenu d'une arrivée ? | **Dans l'application seulement** : sur la page de la classe, les nouveaux arrivés sont marqués « Nouveau », avec « Retirer » à côté (2026-10-07). | Aucun message hors de l'application, aucun service extérieur. Il faut dire quand la marque « Nouveau » s'efface. La même marque sert à la direction et à l'équipe. Un enseignant qui n'ouvre pas Lnclass ne voit rien : risque accepté. |
| Q15. Que voit un élève qui ouvre un ancien lien de classe, portant le code ? | **L'inscription standard, avec une alerte** : « Ce lien n'est plus valable. Choisissez votre classe. » (2026-10-07). | Les anciens liens ne sont pas repris : les codes peuvent être retirés pour de bon. Même comportement que le lien d'invitation invalide de l'enseignant. Un lien de classe changé (Q8) ou inconnu donne la même alerte. |

## Cas limites identifiés

- **Classe pleine** : le plafond d'effectif reste le seul refus de la voie standard. La classe pleine se dit à l'élève avant qu'il ait rempli tout le formulaire.
- **Classe archivée** : elle n'est pas proposée. L'élève dont la classe principale est archivée en choisit une nouvelle depuis son accueil (Q10).
- **Élève retiré** : il garde son compte, sans classe. La voie standard lui refuse cette classe-là ; le lien de la classe l'y ramène (Q7).
- **Élève retiré deux fois** de la même classe, revenu entre-temps par le lien : le retrait se retient de nouveau.
- **Élève déjà dans une classe active qui ouvre un lien de classe** : il n'a qu'une classe principale active ; il est renvoyé vers son accueil.
- **Numéro déjà inscrit** : refus « Ce numéro a déjà un compte Lnclass. », avec « Se connecter », sans révéler le rôle — comme pour l'enseignant.
- **Lien de classe changé, inconnu, ou ancien lien à code** : inscription standard avec l'alerte de Q15.
- **Deux retraits simultanés** du même élève (un enseignant et la direction) : un seul compte, sans erreur pour le second.
- **Classe sans enseignant** : l'élève y entre et y travaille ; seules la direction et l'équipe peuvent partager le lien ou retirer.
- **Établissement, niveau ou classe introuvable** : pas d'inscription, message d'orientation (Q9).
- **Nom complet d'un seul mot** : refusé (Q13).

## Questions encore ouvertes

> Les réponses Q1 à Q15, données par le développeur du chantier, ont été validées avec le porteur le 2026-10-07.

- **Dépendance.** La branche part de celle de `inscription-enseignant`, non fusionnée. Faut-il attendre sa fusion dans `Develop` avant le Lot 0 ?
- Qu'est-ce qui limite la création de comptes en masse dans une classe sans enseignant ?
- L'élève retiré est-il informé, et avec quels mots ?
