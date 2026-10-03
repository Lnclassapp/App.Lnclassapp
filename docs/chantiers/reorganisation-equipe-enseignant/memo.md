# Memo — Réorganisation des espaces Équipe et Enseignant

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `Develop` (directement, décision du porteur le 2026-10-03) |
| **Programme** | — |

---

## Le problème

Demande du porteur (2026-10-03) : « nous allons réorganiser certains éléments des interfaces ».

**Espace équipe.** La barre latérale mélange le quotidien (accueil, cours, établissements, pilotage) et l'outillage ponctuel (imports). L'accueil équipe porte une section « Référentiel » (DRENA, niveaux, séries, matières, barème des classes) qui relève de la configuration, pas du quotidien. Sur la page Pilotage, la recherche d'un compte est en bas de page, et le tableau « Par DRENA » ne mène nulle part : pour connaître les chiffres des établissements d'une DRENA, il faut filtrer la page entière, et aucun écran ne donne ces chiffres établissement par établissement.

**Espace enseignant.** La carte « Mes classes » porte « Modifier mes classes » dans son pied. La section « Cours » est un simple lien vers le catalogue complet, placée en dernier, alors que c'est par elle que l'enseignant trouve quoi assigner ; l'enseignant doit filtrer lui-même par niveau et par matière. L'invitation de collègues est un bloc en bas de l'accueil, qui ne sert qu'aux collègues **du même établissement**. Enfin, un exercice ne s'assigne que depuis la fiche essentielle dans la classe, et rien ne restreint l'assignation aux classes du niveau du contenu.

## Pour qui

- **Équipe** : au quotidien (accueil, pilotage) et lors des tâches de configuration (référentiel, imports).
- **Enseignant** : à chaque connexion, sur son accueil, quand il cherche quoi assigner à ses classes et quand il invite des collègues.

## Pourquoi maintenant

Retours du porteur sur les interfaces livrées (V1 à V4) : les écrans existent, leur organisation freine les deux rôles qui font vivre la plateforme.

## Hors périmètre

- Toute nouvelle donnée de configuration : le référentiel change de place, pas de contenu.
- **Les espaces élève, parent et direction** : rien ne change pour eux. L'élève continue de voir toutes les assignations actives de sa classe, y compris celles marquées « Hors niveau » côté enseignant. La direction ne voit ni la carte Parrainage ni le pilotage.
- La refonte du catalogue lui-même : on ajoute seulement un filtre par série à ses filtres existants.
- **Le contrôle de la matière** à l'assignation : un enseignant peut toujours assigner un contenu d'une autre matière à sa classe ; seule la règle de niveau (et de série) arrive.
- **Une fiche par établissement** dans le pilotage : le tableau « Par établissement » ne mène nulle part.
- **L'activité des classes** : la section, renommée « Activités », reste annoncée « Bientôt ».
- **« Versement »** : retiré par le porteur (G1). Aucune icône, aucun montant ; il reviendra avec un chantier paiement qui aura d'abord une source de vérité.
- **Le lien de parrainage vers les autres établissements** (à la référence de l'enseignant, sans code) : retiré par le porteur (G2). L'attribution d'un parrainage reste celle d'aujourd'hui : lien à code d'établissement, même établissement.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| G1 — « Versement » : rien n'existe (aucun montant, aucun paiement) et l'accueil enseignant interdit un montant sans source de vérité. Où mène l'icône ? | « Retire simplement pour le moment. » | L'icône « Versement » sort du chantier, passe en `Hors périmètre`. La section Cours n'ajoute que « Inviter ». La règle « aucun montant » de l'accueil enseignant reste intacte. |
| G2 — Parrainage, 2e lien « autres établissements » : qui est crédité quand l'inscrit d'un autre établissement passe par la référence d'un enseignant ? | « Plus de validation pour un enseignant » (pause de la validation, déjà décidée le 2026-10-02). « Retire pour le moment le lien de parrainage pour les autres établissements. » | La prémisse de la question était périmée : l'inscription sans code est validée à l'inscription. Le 2e lien sort du chantier (`Hors périmètre`) : la carte Parrainage ne porte que le lien à code d'établissement, déjà existant. Aucune règle de parrainage ne change, aucune décision technique nouvelle sur l'attribution. |
| G3 — La barre latérale n'existe pas sur téléphone : que deviennent la carte Parrainage et le bloc « Inviter un collègue » de l'accueil ? | « Icône et le bloc sur téléphone. » | Grand écran : carte Parrainage dans la barre latérale, plus de bloc en bas de l'accueil. Téléphone : le bloc reste en bas de l'accueil **et** l'icône « Inviter » est dans la section Cours. La même information (compteur, badge, lien, partage) a donc deux rendus selon la largeur : un seul contenu, deux emplacements, jamais les deux visibles à la fois. |
| G4 — Section Cours : une icône par niveau, par niveau + série, ou par classe ? Un cours vise un niveau entier ou une série, et le catalogue ne filtre que par niveau. | Niveau + série. | Une icône par couple (niveau, série) distinct des classes déclarées : deux classes de 3ème donnent une seule icône « 3ème ». « Tle D » liste les cours de la matière de l'enseignant en Tle **communs à toutes les séries** plus ceux **de la série D**. Le catalogue gagne un filtre par série (contexte `catalog`) : critère d'acceptation dédié. |
| G5 — Que montre chaque bulle de niveau ? Le modèle du porteur illustre 7 matières ; l'équipe en crée d'autres en production. | Illustration de la matière de l'enseignant dans la bulle, niveau en libellé dessous. | Les illustrations du modèle (Maths, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC, Philosophie) entrent dans l'application, choisies par l'identifiant figé de la matière ; toute autre matière prend une illustration générique. Le style de bulle est celui du modèle (rond, teinte douce, libellé dessous). Cas limite : une matière renommée garde son identifiant, donc son illustration. |
| G6 — « Classe du niveau adapté » : sur quel geste, et le serveur refuse-t-il une assignation hors niveau ? Aujourd'hui l'assignation d'un cours propose toutes les classes, et un exercice ne s'assigne que depuis la fiche dans la classe. | Partout, et refus côté serveur. | Nouveau bouton « Assigner à mes classes » sur la page d'un exercice. Cours, fiche essentielle et exercice ne proposent que les classes **du niveau du cours**, et **de sa série** quand le cours en vise une. La règle vit dans le métier (contexte `classroom`) : une assignation hors niveau est refusée même envoyée à la main. C'est un **changement de règle** de l'assignation (la décision d'interface de l'assignation d'un cours disait « toutes les classes, quel que soit leur niveau ») : décision technique à écrire. |
| G7 — Équipe : la barre du bas sert la même liste que la barre latérale. Comment atteindre Imports et la configuration sur téléphone si elles passent dans une 2e carte ? | Un menu « Plus » dans la barre du bas. | Barre du bas équipe : Accueil, Cours, Établissements, Pilotage, **Plus** (5 entrées, le maximum tenu). « Plus » ouvre un menu avec les entrées de la 2e carte (Référentiel, Imports). La décision d'interface du shell interdisait toute entrée cachée (« pas de tiroir ») : elle est **amendée** pour l'équipe seule. La 2e carte et le menu « Plus » lisent la même liste : une entrée ajoutée apparaît aux deux endroits. Le Référentiel quitte l'accueil équipe pour sa propre page. |
| G8 — Pilotage : la seule recherche de la page cherche un élève ou un enseignant, en bas. Que faut-il en haut de la liste des DRENA ? | Une recherche de DRENA. | Nouveau champ en tête du tableau « Par DRENA » qui filtre ses lignes par nom. La recherche de comptes ne bouge pas. Une DRENA n'est pas un compte : ce filtre n'appelle pas le serveur, et sans JavaScript toutes les lignes restent visibles. Cas limite : aucun nom ne correspond → message « Aucune DRENA ne correspond ». |
| G9 — Pilotage : où s'affichent les chiffres des établissements d'une DRENA cliquée ? | Sur la même page, filtrée. | Le nom d'une DRENA devient un lien vers le pilotage filtré sur elle (le filtre existe déjà, la période est gardée). Sous filtre, le tableau « Par DRENA » laisse place à « Par établissement » : classes, enseignants, élèves, élèves actifs de chaque établissement de la DRENA. Cette lecture par établissement n'existe nulle part aujourd'hui : nouvelle lecture côté `school`, soumise au budget de temps des écrans lourds. Le champ de recherche du tableau filtre alors les établissements. |
| G10 — Une grosse DRENA compte des centaines d'établissements, souvent sans classe sur Lnclass. Que montre « Par établissement » ? | Tous, paginés. | Tous les établissements **actifs** de la DRENA, triés par nombre d'élèves puis par nom, 25 par page ; un établissement sans activité s'affiche à 0 (la couverture qui reste à gagner). La pagination garde la période et la DRENA dans l'URL. Limite assumée : le champ de recherche du tableau ne filtre que la page affichée (voir `Questions encore ouvertes`). |
| G11 — Section Cours sans classe déclarée, ou pour un niveau sans cours publié dans la matière : que voit l'enseignant ? | Bulle + message. | Sans classe : aucune bulle de niveau, le message « Déclarez vos classes pour retrouver ici les cours de vos niveaux », la bulle « Inviter » et un lien « Voir tout le catalogue ». Niveau sans cours : la bulle reste (aucune lecture de plus sur l'accueil) ; le catalogue filtré affiche son état vide en nommant la matière, le niveau et la série. |
| G12 — Que deviennent les assignations hors niveau déjà actives quand la règle arrive (elle vaut aussi pour l'équipe) ? | Signalées. | Aucune n'est archivée d'office : les élèves les voient toujours. La page de la classe marque chacune « Hors niveau » pour que l'enseignant décide de l'archiver. Une fois archivée, elle ne peut plus être réactivée (la règle s'applique). La lecture de la page de la classe doit donc savoir comparer le niveau du contenu à celui de la classe. |

## Cas limites identifiés

- **Enseignant sans classe déclarée** : aucune bulle de niveau, message et lien vers le catalogue complet (G11).
- **Deux classes du même niveau et de la même série** (3ème 1, 3ème 2) : une seule bulle « 3ème ».
- **Classe sans série d'un niveau qui en a** (une 1ère sans série) : bulle « 1ère », catalogue des cours de 1ère communs à toutes les séries.
- **Matière sans illustration** (Anglais, EPS, toute matière créée par l'équipe) : illustration générique ; une matière renommée garde son identifiant figé, donc son illustration.
- **Niveau sans cours publié dans la matière** : la bulle reste, le catalogue filtré affiche un état vide qui nomme matière, niveau et série.
- **Cours visant une série** (Tle D) : assignable aux seules classes Tle D ; un cours sans série est assignable à toutes les classes de son niveau, quelle que soit leur série.
- **Assignation hors niveau envoyée à la main** : refusée par le serveur, avec un message ; rien n'est écrit.
- **Assignation hors niveau existante** : gardée, marquée « Hors niveau » sur la page de la classe ; réactivation refusée une fois archivée (G12).
- **Équipe qui assigne** : soumise à la même règle de niveau que l'enseignant.
- **Exercice dont le cours est archivé ou non publié** : pas de bouton d'assignation (seul un contenu publié s'assigne, règle existante).
- **Enseignant d'un établissement inactif ou en brouillon** : pas de carte Parrainage, pas de bulle « Inviter », pas de bloc d'invitation (règle d'invitation existante).
- **DRENA sans établissement actif** : « Par établissement » affiche un état vide ; les chiffres clés sont à 0.
- **DRENA inconnue dans l'URL** : vue nationale (comportement existant du filtre).
- **Recherche de DRENA sans correspondance** : « Aucune DRENA ne correspond » ; sans JavaScript, toutes les lignes restent visibles.
- **Téléphone, équipe** : Référentiel et Imports passent par le menu « Plus » de la barre du bas ; **téléphone, enseignant** : pas de barre latérale, donc bloc d'invitation sur l'accueil et bulle « Inviter ».
- **Liens existants vers l'accueil équipe** qui visaient le Référentiel : le Référentiel a sa propre page ; l'accueil n'en garde pas de trace.

## Questions encore ouvertes

- **Recherche dans « Par établissement »** : avec la pagination (G10), un filtre dans le navigateur ne trouve que les établissements de la page affichée. Proposition par défaut pour la phase 2 : sous filtre DRENA, le champ envoie la recherche au serveur (nom d'établissement, toutes pages) ; en vue nationale il filtre les DRENA dans le navigateur. À confirmer par le porteur.
- **Titre de la 2e carte de la barre latérale équipe** : « Configuration » proposé (entrées « Référentiel » et « Imports »), à confirmer à la relecture de l'UDR.
