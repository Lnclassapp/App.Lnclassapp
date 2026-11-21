# Memo — Faire entrer des classes entières

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-16 |
| **Branche** | `feature/acquisition-classes` |
| **Programme** | — |

---

## Le problème

Lnclass compte **sept élèves inscrits**, dont deux ont fait un exercice. Le porteur croyait à un problème de rétention. C'est un problème d'acquisition : personne n'arrive.

Le seul chemin qui mène de 7 à 300, c'est la classe. Un enseignant qui adopte Lnclass amène trente à quatre-vingts élèves d'un coup. Or, dans l'état actuel du produit, **une seule classe dont l'enseignant a vraiment donné le code aurait déjà dépassé sept élèves**. Le chiffre de sept dit donc qu'aucune classe n'a encore franchi le pas, ou presque aucune. Il ne dit pas où la chaîne casse :

1. trop peu d'enseignants inscrits ;
2. des enseignants inscrits qui ne cochent pas de classe, ou qui en cochent une sans jamais en donner le code ;
3. des codes donnés que les élèves n'utilisent pas ;
4. personne ne sait que Lnclass existe.

Beaucoup d'outils d'acquisition existent déjà et ne produisent rien. Aucun ne mesure la chaîne enseignant → classe → élèves. C'est le maillon manquant.

### Ce qui est en place, ce qui est branché, ce qui est compté

| Outil | Branché ? | Qui s'en sert | Ce qui est compté | Ce qui ne l'est pas |
|---|---|---|---|---|
| **Page Croissance de l'équipe** | Oui, en production, réservée à l'équipe | Le porteur | Partages de parrainage entre enseignants, inscriptions d'enseignants (7, 30 ou 90 derniers jours), filleuls, conversion, k enseignant, cycle viral, élèves entrés dans une classe, classement des établissements par nombre d'enseignants, et l'entonnoir des élèves par voie d'arrivée (seul, lien de classe, code, sans classe) | Le nombre d'enseignants qui ont coché une classe, donné un devoir, ou dont la classe a des élèves. **Rien ne relie un enseignant à ses élèves.** |
| **Parrainage entre enseignants** | En partie. La bulle « Inviter » de l'accueil enseignant (WhatsApp, collègue du même établissement) est branchée. La page d'invitation complète (SMS, copier, autre établissement) n'a plus aucun lien qui y mène. | Les enseignants inscrits, s'il y en a | Le clic de partage et le filleul inscrit par lien | Les visites du lien d'invitation, et quel lien a été partagé |
| **Démarrage à froid** (demandes en attente, garant) | **Non.** Il est débranché depuis l'inscription en deux voies : plus rien ne crée de demande. | Personne | La carte « Demandes en attente » de la page Croissance, qui affiche toujours 0 | — |
| **Bannière de l'élève** « Ton enseignant n'est pas encore sur Lnclass ? » | Oui, sur l'accueil de tout élève inscrit dans une classe, **même quand la classe a déjà un enseignant** | Les 7 élèves | **Rien.** Le lien mène à l'inscription enseignant nue : ni établissement prérempli, ni attribution. | Le clic, l'inscription qui en résulte |
| **Partage du lien de classe par l'enseignant** (WhatsApp, copier) | Oui, sur la page de la classe et sur la carte de l'accueil (code et bouton « Copier ») | L'enseignant, la direction | Seulement l'arrivée : la voie d'entrée de l'élève (lien ou code) | Le partage lui-même, et l'enseignant qui a donné le code (le code appartient à la classe) |
| **Inscription enseignant** | Oui. Une page en 3 étapes : établissement, identité, code secret. **Aucune validation par l'équipe.** | — | L'inscription et sa voie (seul, collègue, direction, équipe) | Les abandons en cours de formulaire |
| **Classes** | **L'enseignant ne crée pas de classe** : il coche celles que l'équipe ou la direction a ouvertes pour l'année. Si son établissement n'en a aucune, il lit « Aucune classe ouverte cette année. Revenez un peu plus tard. » et reste bloqué. | — | L'ouverture d'une classe, la déclaration de l'enseignant (effacée s'il se retire) | Le nombre d'enseignants tombés sur l'écran « Aucune classe ouverte » |
| **Inscription élève** | Oui. Elle propose d'abord de choisir sa classe (DRENA → établissement → niveau → classe), **sans code**. Le code est derrière « J'ai le code de ma classe ». | — | La voie d'arrivée | — |
| **CRM des écoles** | Oui, réservé à l'équipe (administration et terrain) | Le porteur et deux personnes de terrain | L'étape saisie à la main, les échanges, les relances, l'usage d'une école (comptes, élèves actifs sur 14 jours, dernière activité) | Le lien entre un contact et un compte inscrit. La date du passage à « Inscrite » ou « Active ». L'envoi réel d'un message. **Le brouillon WhatsApp ne contient aucun lien d'inscription**, alors que la fiche de l'école en porte deux. |
| **Page d'accueil publique** | Oui | Tout visiteur | Rien (pas de traceur, par choix) | — |

Il n'existe **aucune page pour l'enseignant** : un bouton secondaire « Enseignant(e) » ouvre une fenêtre de deux lignes. La page d'accueil parle à l'élève. Le blog et les leçons publiques existent, avec un plan du site, mais le dépôt ne dit pas combien d'articles sont publiés.

### Ce que la page Croissance montrerait au porteur aujourd'hui

Sur 90 jours, elle répond déjà à une partie de la question :

- **Inscriptions enseignants** : le nombre d'enseignants inscrits sur la période. S'il est proche de zéro, le goulot est en amont (1 ou 4).
- **Établissements les plus actifs** : combien d'établissements ont au moins un enseignant, et combien d'enseignants chacun.
- **Entonnoir des élèves par voie** : parmi les 7, combien sont arrivés par le lien ou le code d'une classe (un enseignant a donc distribué), et combien sont venus seuls.
- **Élèves arrivés par enseignant actif** : ce chiffre est trompeur. « Actif » y désigne en fait tout enseignant rattaché à un établissement, depuis toujours.

En revanche, elle ne dit pas **où les enseignants inscrits s'arrêtent**. Elle ne montre ni les classes cochées, ni les codes suivis d'élèves, ni les devoirs donnés, ni l'état des écoles du CRM. C'est exactement la question du chantier.

## Pour qui

- **L'équipe** (porteur, terrain) : savoir où la chaîne casse, puis agir au bon endroit.
- **L'enseignant**, de son inscription à une classe qui travaille.
- **L'établissement prospecté**, dans le pipeline du CRM.

## Pourquoi maintenant

Trois chantiers d'aval (activation de l'élève, entonnoir, parrainage) ont été livrés sur une population de sept élèves. Tant que les classes n'entrent pas, aucun travail d'activation ou de rétention ne peut se mesurer. Chaque chantier d'aval de plus est un pari sans données.

## Hors périmètre

- **L'inscription de l'élève** : elle vient d'être retravaillée par le chantier activation-eleve.
- **Le service worker, les notifications et le profil de l'élève** : ils appartiennent au chantier notifications-push.
- **Toute nouvelle table, tout traceur, tout événement de clic** : la mesure se lit sur les tables actuelles, comme le prévoient la mesure d'audience côté serveur et les indicateurs lus en direct.
- **La notoriété** (campagnes, presse, réseaux) : hors du code. Le chantier dit seulement si c'est le goulot.
- **Les parents et la direction comme cibles d'acquisition.** La direction n'apparaît que comme interlocuteur du CRM.
- **Toute action d'acquisition avant la mesure.** Les lots d'action sont écrits ici, mais conditionnels : un seul sera lancé, celui que la mesure désigne.
- **La remise en état du parrainage débranché** (page d'invitation orpheline, carte des demandes toujours à zéro) : c'est de la dette, notée au journal.

## Ce que le grill a révélé

> Grill mené en session autonome, sans le porteur. Chaque question a reçu sa réponse dans le dépôt. Celles qui restent sans réponse sont dans « Questions encore ouvertes » et dans le `## À trancher` du journal.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un enseignant « crée-t-il une classe » ? | Non. Il coche une classe ouverte par l'équipe ou la direction. Le code existe avant lui. | Le goulot 2 se coupe en deux : (a) l'établissement n'a aucune classe ouverte, et l'enseignant est bloqué sans rien pouvoir faire ; (b) il coche une classe mais rien ne suit. La mesure doit compter (a) à part. |
| Un élève a-t-il besoin du code pour entrer ? | Non. L'inscription propose d'abord la classe en cascade, sans code. | « Codes distribués non utilisés » (3) ne peut pas se lire sur la voie « code » seule. Il faut regarder les élèves de toute voie dans une classe qui a un enseignant. |
| La page Croissance ne suffit-elle pas ? | Elle compte les enseignants et le parrainage, pas la chaîne enseignant → classe → élèves. Sa carte « Demandes en attente » vaut toujours 0, et son « enseignant actif » n'est pas actif. | Le memo dit ce qu'elle montre déjà. La mesure ajoutée ne double aucun de ses compteurs. |
| Le partage d'un code est-il enregistré quelque part ? | Non. Seule l'arrivée de l'élève l'est, et le code appartient à la classe, pas à l'enseignant. | On ne peut pas distinguer « code jamais donné » de « code donné et ignoré » (2b contre 3). Indice retenu : l'enseignant a donné un devoir à une classe vide, donc il s'est investi et les élèves ne sont pas venus. Cette limite est écrite dans le PRD. |
| Le CRM fait-il entrer des enseignants ? | Non. Il note et relance. Son brouillon WhatsApp ne contient pas le lien d'inscription de l'établissement, et ses contacts ne sont reliés à aucun compte. | La mesure croise l'étape CRM d'une école avec ses enseignants et ses classes réels. C'est la seule façon de voir où le pipeline fuit. |
| Acteurs oubliés : parent, direction ? | Le parent n'a aucun rôle dans l'acquisition. La direction peut ouvrir des classes et inviter des enseignants. | La direction entre dans la mesure : classes ouvertes par établissement. Le parent est écrit hors périmètre. |
| Multi-appartenance : un élève dans deux classes, un enseignant dans deux écoles ? | Un élève a une classe principale ; un enseignant a un établissement principal. Une ré-adhésion écrase la date et la voie. | La mesure compte des élèves et des enseignants distincts, sur la classe principale et l'établissement principal. La voie écrasée est une limite écrite. |
| Cas limites : établissement sans classe, classe sans enseignant, enseignant retiré, compte anonymisé ? | Une classe sans enseignant est le cas courant. La déclaration d'un enseignant retiré est effacée. | Les anonymisés sont exclus. Les classes sans enseignant sont comptées à part (élèves venus seuls). Une déclaration effacée est invisible : limite écrite. |
| Faut-il agir tout de suite, puisque sept est déjà un verdict ? | Sept exclut seulement « une classe a adopté ». Il ne départage ni 1, 2, 3 ou 4, ni 2a et 2b. Les quatre remèdes n'ont rien en commun. | Le chantier livre d'abord la mesure. Les quatre lots d'action sont écrits, mais **un seul part**, après lecture en production. |

## Cas limites identifiés

- L'établissement d'un enseignant n'a aucune classe ouverte cette année : l'enseignant est bloqué. Il est compté à part.
- Une classe est déclarée par plusieurs enseignants : elle compte une fois pour la classe, et une fois pour chaque enseignant.
- Une classe a des élèves venus par la cascade, sans code, avant toute déclaration d'enseignant : ces élèves sont comptés, mais ne sont pas attribués à l'enseignant.
- Les classes d'une année scolaire passée sont exclues.
- Les comptes anonymisés sont exclus partout.
- Les enseignants de l'équipe ou les comptes de recette en production faussent de petits nombres : la mesure les liste par voie d'inscription, ce qui aide à les repérer.
- Avec zéro enseignant, la sortie le dit en une ligne, sans tableau vide.

## Questions encore ouvertes

- Les seuils qui désignent le goulot (PRD §3) sont des valeurs par défaut prudentes. Le porteur peut les changer après la première lecture.
- Combien d'établissements du pipeline ont été réellement contactés ? Le CRM le sait, le dépôt non. La mesure l'imprime.
- La notoriété (4) ne se prouve pas par le code. Elle est retenue par élimination : peu d'enseignants **et** peu d'échanges dans le CRM.
