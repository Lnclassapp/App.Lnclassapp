# Memo — La direction gère son établissement

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-01 |
| **Branche** | `feature/gestion-etablissement-direction` |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) : reprend une partie du backlog `espace-direction` complet |

---

## Le problème

Depuis `espace-direction-simple` (en production), la direction d'un établissement a un compte et **lit** deux pages : ses enseignants, et le travail de ses élèves. Elle ne peut rien y faire. Pour chaque geste, elle passe par l'équipe Lnclass :

- elle ne connaît pas le **code d'établissement** que ses enseignants doivent saisir pour s'inscrire, ni le **lien** à leur transmettre ;
- elle ne peut pas **ajouter une classe** qui manque ;
- elle ne peut pas **retirer un enseignant** qui a quitté l'établissement, ni le réintégrer après une erreur ;

L'équipe fait tout cela à sa place, et ne suit plus quand les établissements se multiplient.

## Pour qui

- **La direction (SchoolStaff)** : un seul type de compte, sans fonction (grill 2), comme en production. Tout compte de direction a les mêmes gestes, sur son **seul** établissement.
- **L'équipe (Team)** : elle invite la direction (inchangé) et garde ses gestes actuels sur la fiche de l'établissement (« + », « − », régénération du code). Elle ne retire ni ne réintègre d'enseignant (grill 9).
- **L'enseignant** : il reçoit le lien d'inscription de la direction ; il peut être retiré (ses devoirs actifs sont archivés), rejoindre un autre établissement par son code, ou être réintégré par la direction.
- **L'élève** : rien ne change pour lui (il est seulement vu par la direction, comme aujourd'hui).

## Pourquoi maintenant

Demande du porteur, 2026-10-01 : développer, dans l'espace direction, l'**ajout de classes**, la **gestion des enseignants** et le **lien d'invitation** (grill 3 ; les fonctions et le personnel sont repoussés, grill 2). La version simple est en production : ces gestes sont ceux que la direction réclame à l'équipe.

## Hors périmètre

- **Les fonctions de direction** (Chef d'établissement, ACE ou Directeur des études, Éducateur, Secrétaire), le **personnel** (une direction qui invite ou retire une autre direction) et le **second facteur** : prochaine version (grills 2 et 3).
- **Un écran « code d'établissement »** séparé : la direction voit le code seulement dans son lien d'invitation, et le change par « Changer le lien » (grill 4).
- **Retirer ou réintégrer un enseignant par l'équipe** : non (grill 9).
- **Régénérer en masse les liens de plusieurs établissements** (équipe) : chantier à part, au backlog (précision du porteur, 2026-10-01).
- **Le matricule de l'élève** et tout ce qui en dépend (recherche d'un élève, changement de classe par matricule) : reste au backlog.
- **Changer un élève de classe** : reste au backlog.
- **Valider les enseignants en attente** : la direction ne le fait pas (Q1, ADR-0063 inchangé) ; les garants et l'équipe valident.
- **Modifier, renommer ou supprimer une classe**, créer une classe au nom libre : non.
- **Régénérer ou fermer le code d'adhésion d'une classe** : non.
- **Un tableau de bord élaboré** (compteurs, périodes, historique) : la page « Travail des élèves » reste l'accueil.
- **L'annuaire des comptes par l'équipe** (`annuaire-equipe`), le **multi-établissement** de l'enseignant, le **changement d'établissement** d'un élève, les **parents** : non.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Périmètre (porteur, 2026-10-01) | Ajout de classes, gestion des enseignants, fonctions et personnel, code d'établissement, lien d'invitation | Cinq gestes ; matricule et changement de classe restent au backlog |
| Grill 1 : que deviennent les comptes de direction déjà en production, sans fonction ? | Réponse sur le vocabulaire (porteur, 2026-10-01) : **dans les lycées publics, les censeurs sont devenus des « Adjoints au chef d'établissement » (ACE) ; dans les collèges privés, c'est le « Directeur des études » (DE).** La question des comptes existants reste ouverte. | Le libellé « Censeur » de l'ADR-0044 est **périmé**. La fonction de second rang se nomme selon le type d'établissement : ACE (public), Directeur des études (privé). La liste fermée des fonctions de l'ADR-0044 est à réécrire (grill 2). Comptes existants : reposé après le grill 2. |
| Grill 2 : quelle liste de fonctions proposer ? | **« Laissons les fonctions pour cette première version. »** (porteur, 2026-10-01) | **Pas de fonction** : un seul type de compte direction, comme en production. Les droits ne se différencient pas. Le grill 1 (comptes existants) devient sans objet : rien à migrer. Le vocabulaire ACE / Directeur des études est gardé pour le chantier qui introduira les fonctions. |
| Grill 3 : sans fonctions, quels points la direction gère-t-elle ? | **Lien d'invitation, ajout de classes, gestion des enseignants.** (porteur, 2026-10-01) | Trois gestes. **Sortent** : le code d'établissement (lecture, régénération) et le personnel (inviter, retirer des collègues de la direction, second facteur). Tout compte de direction a les trois gestes. Le lien d'invitation contient le code (`/e/<code>`) : voir grill 4. |
| Grill 4 : si le lien d'invitation fuit hors de l'établissement ? | **La direction le régénère** (« Changer le lien ») ; l'ancien lien cesse de marcher, les enseignants déjà inscrits restent. (porteur, 2026-10-01) | La régénération du code revient dans le périmètre, **présentée comme « changer le lien »** : c'est le même geste que celui de l'équipe (ADR-0057), autorisé aussi à la direction de l'établissement. La direction voit le lien (donc le code qu'il contient), sans écran « code d'établissement » à part. Couplé au retrait d'un enseignant inscrit à tort, la direction répare seule une fuite. |
| Grill 5 : un enseignant retiré peut-il revenir seul par le lien ? | **Non : seule la direction le réintègre.** (porteur, 2026-10-01) | Il faut **garder la trace du retrait** (qui, quel établissement, quand) : le lien et le code refusent l'enseignant retiré de cet établissement, avec le message neutre d'un code invalide. Nouvelle liste « Enseignants retirés » avec « Réintégrer ». Une donnée nouvelle, donc un ADR. |
| Grill 6 : au retrait, que deviennent ses classes, ses devoirs, les résultats ? | **Ses devoirs sont archivés.** (porteur, 2026-10-01) | Au retrait : l'enseignant perd l'établissement et ses déclarations de classes ; **les devoirs qu'il a donnés et encore actifs passent en archivé** (les élèves ne les voient plus à faire) ; les sessions et résultats déjà obtenus restent ; classes et élèves restent. Archiver est un geste existant de l'enseignant (ADR-0036) : il s'applique ici en masse, au nom de la direction, et se journalise. Réintégration : il retrouve l'établissement et recoche ses classes ; **ses devoirs restent archivés** (délégué, amendable). Cas limite : un devoir donné par lui dans une classe qu'un collègue enseigne aussi est archivé quand même. |
| Grill 7 : la direction a-t-elle aussi le « − » des classes ? | **Le « + » et le « − ».** (porteur, 2026-10-01) | La direction a les deux gestes de l'équipe (ADR-0059), sur son seul établissement : « + » ajoute la classe suivante d'un niveau ; « − » retire la dernière, seulement si elle n'a jamais servi (aucun élève, enseignant ni devoir). Aucune création au nom libre, aucune modification. |
| Grill 8 : que voit un enseignant retiré, et peut-il rejoindre un autre établissement ? | **Écran d'attente, avec un champ pour le code d'un autre établissement.** (porteur, 2026-10-01) | Nouveau parcours « rejoindre un établissement par son code » pour un enseignant **déjà inscrit**, sans école : il n'existait pas. Le code de l'établissement qui l'a retiré est refusé (grill 5) avec le message d'un code invalide. Il reste en session : il est renvoyé vers l'écran d'attente à sa requête suivante. |
| Précision du porteur (2026-10-01) : d'où vient le lien, qui le partage ? | « Le lien d'invitation est généré par l'équipe, soit lors de l'import, soit par un bouton qui génère le lien des établissements qui n'en ont pas encore. Les enseignants aussi peuvent partager le lien à leurs collègues. » | **Vérifié dans le code** : l'import tire le code de chaque établissement ; le code est obligatoire en base, et les établissements antérieurs en ont reçu un par migration : **aucun établissement n'est sans lien**, et le bouton « générer » n'existe pas (seul « Régénérer le code » existe sur la fiche). Le chantier n'a donc **pas de cas « établissement sans lien »** à traiter. Les enseignants partagent déjà leur lien personnel (« Inviter un collègue », parrainage) : quand la direction **change** le lien, ces liens personnels changent aussi (ils se réaffichent avec le nouveau code ; les anciens messages ne marchent plus) — coût déjà écrit dans l'ADR-0071. **Suite (porteur)** : il veut un bouton de l'équipe qui **régénère en masse** les liens de plusieurs établissements : **chantier à part**, au backlog (`regeneration-codes-en-masse`). |
| Grill 9 : l'équipe retire-t-elle et réintègre-t-elle aussi un enseignant ? | **Non, la direction seulement.** (porteur, 2026-10-01) | L'équipe garde ses gestes actuels (« + », « − », régénération du code depuis la fiche). Un établissement **sans direction** ne peut pas retirer d'enseignant : coût accepté, à écrire dans l'ADR. L'équipe n'a aucun écran « Enseignants retirés ». |

## Cas limites identifiés

- **Plusieurs comptes de direction dans un établissement** : sans fonction, chacun a les mêmes gestes ; l'un peut retirer un enseignant que l'autre a réintégré. Chaque geste est journalisé avec son auteur.
- **Accès inter-établissements** : chaque geste (« + », « − », changer le lien, retirer, réintégrer) se fait sur l'établissement du compte, jamais sur un établissement désigné dans l'adresse. Une classe ou un enseignant d'un autre établissement est introuvable. Chaque geste a son test de refus.
- **Établissement inactif ou en brouillon** : la direction garde la lecture, mais ne fait aucun geste (comme l'équipe : pas de classe ajoutée à un établissement inactif, pas d'inscription).
- **Enseignant en attente de validation** (inscrit sans code) : il n'est pas un enseignant de l'établissement ; la direction ne le voit pas et ne le retire pas (Q1).
- **Retirer un enseignant qui est aussi le parrain ou le garant d'autres comptes** : ses parrainages restent (historique) ; il ne peut plus confirmer de collègue en attente.
- **Retrait d'un enseignant sans devoir actif** : seules ses déclarations de classes et son rattachement disparaissent.
- **Réintégration après qu'il a rejoint un autre établissement** : impossible ; il n'est plus dans « Enseignants retirés » de A (un établissement à la fois).
- **Changer le lien deux fois de suite** : chaque fois, l'ancien cesse de marcher ; les liens de parrainage personnels des enseignants (`/e/<code>?ref=…`) cessent aussi : ils se réaffichent avec le nouveau code.
- **« − » sur une classe qui a servi** : refusé avec le motif, comme pour l'équipe.
- **Zéro enseignant retiré** : état vide.
- **Établissement sans direction** : personne ne peut retirer un enseignant (grill 9).

## Questions encore ouvertes

- **Réintégration et devoirs archivés** : les devoirs archivés au retrait restent archivés à la réintégration (délégué). À confirmer.
- **Prévenir l'enseignant retiré** : aucune notification en V2 ; il découvre l'écran d'attente à sa connexion suivante.
- **Fonctions de direction** (Chef d'établissement, ACE ou Directeur des études, Éducateur, Secrétaire), **personnel** et **second facteur** : prochaine version ; le vocabulaire est noté au grill 1.
