# Memo — Espace direction

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/espace-direction` |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) |

---

## Le problème

Un établissement existe dans Lnclass, créé ou importé par l'équipe avec ses classes générées. Pourtant, personne dans l'établissement ne peut l'administrer. Seule l'équipe crée les classes, lit les listes et gère le code d'établissement. Le proviseur, le censeur, l'éducateur ou la secrétaire n'ont aucun compte : ils dépendent de l'équipe pour chaque geste, et l'équipe ne suit plus quand les établissements se multiplient.

## Pour qui

- **La direction (SchoolStaff)** : elle est invitée par l'équipe ou par un membre déjà rattaché. Elle administre **son seul** établissement : ses classes, ses enseignants, ses élèves, son personnel, son code d'établissement, son tableau de bord et son profil.
- **L'équipe (Team)** : elle invite la première direction d'un établissement et garde la main partout.
- **L'enseignant et l'élève** : la direction les voit, retire ou réintègre un enseignant, change un élève de classe dans l'établissement ; l'élève saisit son matricule à l'inscription et le corrige depuis son profil ; leurs autres parcours ne changent pas.

## Pourquoi maintenant

La V1 est close et en production. La V2 est la vague suivante du programme ; le porteur l'ouvre le 2026-09-28 (« Lançons le V2 »). Sans direction, chaque nouvel établissement coûte du temps à l'équipe.

## Hors périmètre

- **Valider les enseignants en attente** : la direction ne le fait pas (Q1). Comme en V1, ce sont les collègues déjà approuvés de l'établissement (garants) et l'équipe qui valident (ADR-0063).
- **Modifier une classe** (CL-02 : nom, plafond, statut) : V3, `vie-de-la-classe`.
- **Créer une classe au nom libre** : la direction ajoute seulement la classe suivante d'un niveau, comme l'équipe (Q3, ADR-0059).
- **L'annuaire de l'équipe** (liste, fiche, modification et anonymisation de tous les comptes) : chantier `annuaire-equipe`, second chantier de la V2, **non ouvert ; démarre après fusion du Lot 0a** de ce chantier.
- **Les pages des séries** (CA-23) : V4, `catalogue-complet`.
- **La matrice des sous-rôles de l'équipe** (ADR-0038) : V4.
- **Les parents** : aucun parcours en V2.
- **Le multi-établissement de l'enseignant** (ID-09, SC-23) : laissé de côté par le porteur (grill 6), **placé au backlog** le 2026-09-28 (chantier `multi-etablissements-enseignant`, avec Q7).
- **Le changement d'établissement d'un élève** : reporté par le porteur, **placé au backlog** le 2026-09-28 (chantier `changement-etablissement-eleve`). Depuis la relecture du 2026-09-28, la direction ne rattache non plus aucun élève venu d'ailleurs ou sans classe cette année : elle ne change de classe que les élèves de son établissement.
- **Corriger un matricule par l'équipe** : non ; seul l'élève le corrige (relecture du 2026-09-28).
- **Se connecter avec son matricule** : la connexion reste par téléphone (grill 4).
- **Paiement et abonnement** par matricule : plus tard ; le matricule est conçu pour les permettre (grill 3).
- **Notes par élève pour la direction** : non (grill 9).

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 (feuille de route) : qui valide les enseignants en attente de l'établissement ? | Les collègues déjà approuvés de l'établissement (le garant de l'ADR-0063) et l'équipe. **Pas la direction.** (porteur, 2026-09-28) | L'ajout « la direction valide les enseignants en attente » sort de la V2. L'ADR-0063 ne change pas. |
| Q2 : la direction voit-elle le code de son établissement ? | **Elle le voit et peut le régénérer** ; l'ancien code cesse alors de marcher. (porteur, 2026-09-28) | Amendement de l'ADR-0057 et de la règle d'accès au code : la direction active de l'établissement peut agir, en plus de l'équipe. Test de refus pour la direction d'un autre établissement. |
| Q3 : comment la direction gère-t-elle ses classes ? | **Comme l'équipe** : elle ajoute la classe suivante d'un niveau, et la numérotation de l'ADR-0059 est préservée. (porteur, 2026-09-28) | SC-19 devient « ajouter la classe suivante » sur son seul établissement ; pas de création libre, pas de modification (CL-02 reste en V3). |
| Grill 1 : comment la direction retrouve-t-elle un « élève existant » à rattacher (ID-10, SC-21) sans pouvoir sonder les numéros de téléphone ? | **Par son matricule.** (porteur, 2026-09-28) | Lnclass ne connaît aucun matricule aujourd'hui : il faut une **nouvelle donnée de l'élève**, donc un ADR (format, unicité, qui la saisit, protection contre l'énumération). Le numéro de téléphone n'est jamais une clé de recherche pour la direction. |
| Grill 2 : qui saisit le matricule, et quand ? | **L'élève, obligatoirement**, à l'inscription. (porteur, 2026-09-28) | Le parcours d'inscription élève de la V1 change : champ obligatoire, format validé, unicité (un matricule déjà pris est refusé, sans dire à qui il appartient). Cela amende l'UDR de l'inscription élève. Les élèves déjà inscrits n'ont pas de matricule : voir grill 3. |
| Grill 3 : que faire des élèves déjà inscrits, sans matricule ? | **Aucun élève n'est inscrit en production pour le moment.** Le matricule servira aussi à identifier le compte de l'élève et, plus tard, à son paiement et à son abonnement. (porteur, 2026-09-28) | Pas d'écran de rattrapage : la donnée peut être obligatoire dès sa création (à revérifier juste avant la mise en production). Le matricule devient un **identifiant stable de l'élève** : l'ADR le traite comme tel (unique, jamais réattribué, modifiable seulement par l'équipe). Paiement et abonnement : hors V2, mais l'ADR ne doit pas les empêcher. |
| Grill 3 bis : quel format ? | **Matricule MENA** : 8 chiffres suivis d'une lettre, normalisé en majuscules. Format **confirmé le 2026-09-28** sur l'exemple `12345678A`. (porteur, 2026-09-28) | Validation stricte du format à l'inscription. Le motif exact est **à confirmer sur un vrai matricule** avant le Lot 0 : c'est un point à confirmer dans l'ADR. |
| Format et reports (porteur, 2026-09-28) | Exemple de matricule : `12345678A`. « Le multi-établissement sera pour après, le changement d'établissement pour les élèves aussi pour après. Mettez-les dans le backlog. » | Format fixé (ADR-0065). Deux chantiers au backlog : `multi-etablissements-enseignant` et `changement-etablissement-eleve`. Aucun des deux n'entre dans la V2. |
| Grill 4 : l'élève se connecte-t-il avec son matricule ? | **Non : par téléphone, comme en V1.** (porteur, 2026-09-28) | La connexion et sa limite de débit ne changent pas. Se connecter par matricule passe hors périmètre. |
| Grill 5 : un enseignant rattaché à deux établissements : que voit chaque direction, et qui le retire ? | **Chacune sa part** : chaque direction voit l'enseignant et ses seules classes dans son établissement ; chacune ne retire que le rattachement à son établissement ; l'école principale ne change pas. (porteur, 2026-09-28) | Toutes les listes et fiches de la direction sont filtrées par l'établissement de la direction (test de refus inter-établissements). Retirer un enseignant de son établissement ne touche ni son compte ni son autre établissement. Retirer l'école principale est à trancher (grill suivant). **Remplacée par le grill 6.** |
| Grill 6 : comment la direction retrouve-t-elle un enseignant existant pour le rattacher (ID-09, SC-23) ? | **Le multi-établissement de l'enseignant est laissé de côté** pour le moment. (porteur, 2026-09-28) | ID-09 et SC-23 sortent de la V2 et rejoignent Q7 (V3). En V2, un enseignant n'a qu'un établissement ; il le rejoint avec le code d'établissement, validé par un garant ou par l'équipe (ADR-0057, ADR-0063). La direction ne cherche jamais un enseignant. Le grill 5 reste vrai pour la V3. |
| Grill 7 : la direction peut-elle retirer un enseignant qui quitte l'établissement ? | **Oui, et les classes restent.** L'enseignant perd l'accès à l'établissement et à ses classes. Les classes, les élèves et les résultats restent dans l'établissement. Le compte reste actif et peut rejoindre un autre établissement par son code. (porteur, 2026-09-28) | Nouveau cas d'usage « retirer un enseignant de l'établissement » : il retire le rattachement à l'établissement et à ses classes, **sans rien supprimer d'autre** et sans toucher aux devoirs ni aux résultats (ADR-0036). Une classe peut rester sans enseignant ; un autre enseignant la reprend en la rejoignant, comme en V1. Journalisé. |
| Grill 8 : les quatre fonctions de l'ADR-0044 (Proviseur, Censeur, Éducateur, Secrétaire) ont-elles les mêmes droits ? | **Le Proviseur et le Censeur gèrent** : ils retirent un enseignant, régénèrent le code d'établissement et retirent un membre du personnel. L'Éducateur et la Secrétaire voient tout l'établissement, ajoutent des classes et rattachent des élèves. (porteur, 2026-09-28) | Deux niveaux de droits dans la direction : c'est un amendement de l'ADR-0044 (qui ne laissait détacher que le proviseur). « Créer ou supprimer un rôle » (SC-11, SC-12) devient « voir les fonctions » : la liste reste fermée. Chaque geste sensible a son test de refus pour l'Éducateur et la Secrétaire. |
| Grill 9 : que montre le tableau de bord de l'établissement (SC-15, TR-15) ? | **Délégué** (« prends les décisions », porteur, 2026-09-28). Décision : des **chiffres par classe**, sans note par élève. En tête : nombre de classes, d'enseignants et d'élèves. Puis, pour chaque classe : effectif, devoirs donnés, taux de rendu et moyenne de la classe. | Données de mineurs minimales : la direction ne voit jamais la note d'un élève nommé. Lecture seule, calculée en direct comme le tableau de pilotage de l'équipe (ADR-0062), sur son seul établissement. |
| Décisions prises par délégation du porteur (2026-09-28) | Voir les cas limites ci-dessous : rattachement d'un élève par matricule, première direction, départ du proviseur, invitations du personnel, second facteur. | Chacune est marquée « délégué » dans le PRD et l'ADR, et reste amendable par le porteur. |
| Relecture de la phase Décider (porteur, 2026-09-28) : ADR-0065, 0066, 0067, UDR-0052, 0053 | **Acceptées avec retours** : (1) le Proviseur ou le Censeur **réintègre** un enseignant retiré depuis « Enseignants » (il ne revient toujours pas seul par le code) ; (2) invitations à **30 par heure** ; (3) code d'établissement accepté tel quel ; (4) le code d'adhésion d'une classe existe dès sa création, la direction le lit sans le régénérer ni le fermer ; (5) moyenne « — » sous 5 élèves acceptée ; (6) **seul l'élève corrige son matricule**, depuis son profil sous son PIN ; **la direction ne cherche que les élèves de son établissement** ; (7) droits de base gardés, matrice à revoir avec des directions réelles. | Critères ED-60 à ED-65 ajoutés, douze réécrits ; Lots C, D, E, F et 0a/0b revus ; `Identity::ChangeStudentNumber` (équipe) et le rattachement d'un élève venu d'ailleurs disparaissent ; la réintégration rend l'établissement, pas les classes (délégué). Grill 1 (« rattacher »), grill 3 (« modifiable seulement par l'équipe ») et grill 8 (« rattachent des élèves ») sont **amendés** par cette ligne ; les cas limites ci-dessous sont à jour. |

## Cas limites identifiés

> Tranchés par délégation du porteur (2026-09-28), sauf mention contraire.

- **Chercher un élève par matricule** (relecture du porteur, 2026-09-28) : la direction saisit le matricule **complet et exact** d'un élève **de son établissement** (inscrit dans une de ses classes de l'année en cours) ; aucune recherche partielle, aucune liste. Elle voit alors le nom et la classe de l'élève pour confirmer, puis choisit une autre classe active de son établissement. Un matricule inconnu, d'un élève sans classe cette année ou d'un autre établissement reçoit **le même message neutre**, sous une limite de débit.
- **Élève d'un autre établissement, ou sans classe cette année** : jamais trouvé ni pris par la direction. Il rejoint sa classe par son code d'adhésion, comme en V1. **Le changement d'établissement d'un élève est au backlog** ; en V2, comme en V1, un élève dont la classe est active ne rejoint pas une autre classe.
- **Élève de l'établissement** : la direction le change de classe (erreur de classe), depuis la liste ou par son matricule. Il quitte l'ancienne classe ; ses résultats passés restent attachés à leurs devoirs.
- **Classe pleine** (plafond d'effectif atteint) : rattachement refusé avec un message nommé, comme pour le code de classe.
- **Matricule déjà pris à l'inscription** : refusé sans dire à qui il appartient ; l'élève est invité à vérifier son matricule ou à contacter l'équipe. **Seul l'élève corrige son matricule**, depuis son profil, sous son PIN actuel (relecture du 2026-09-28) ; un matricule usurpé se libère par l'anonymisation (`annuaire-equipe`).
- **Enseignant retiré par erreur** : le Proviseur ou le Censeur le réintègre depuis « Enseignants retirés » ; il retrouve l'établissement, pas ses classes (il s'y redéclare) : décision déléguée, amendable.
- **Première direction d'un établissement** : l'équipe l'invite (ADR-0044), avec le même lien d'invitation à usage unique que pour les comptes de l'équipe, à transmettre hors de Lnclass.
- **Invitations du personnel** : le Proviseur et le Censeur invitent (grill 8). Seul un Proviseur invite un Proviseur, et il n'y a qu'un Proviseur actif par établissement (ADR-0044).
- **Départ du Proviseur** : seule l'équipe le retire ou le remplace ; un Proviseur ne se retire pas lui-même. Un établissement sans Proviseur reste géré par son Censeur, ou par l'équipe.
- **Membre du personnel retiré** : ses sessions sont fermées ; son compte ne voit plus que son profil (ADR-0044).
- **Second facteur** : obligatoire pour toute la direction, comme pour l'équipe (ADR-0044, ADR-0031). Sa perte est réinitialisée par l'équipe.
- **Établissement désactivé** : la direction ne voit plus que son profil, comme un membre retiré.
- **Zéro élément** : un établissement sans classe, sans enseignant ou sans élève affiche un état vide qui dit quoi faire (donner le code d'établissement, ajouter une classe).
- **Mille éléments** : les listes d'élèves et d'enseignants sont paginées et filtrables par classe.
- **Accès inter-établissements** : toute page et tout geste de la direction vérifient son établissement. Chaque cas d'usage a un test de refus pour la direction d'un autre établissement.

## Questions encore ouvertes

- **Aucun élève en production** (dit par le porteur, grill 3) : à revérifier juste avant la migration du Lot F, pour rendre le matricule obligatoire sans rattrapage.
- **Élève dont la classe de l'an dernier reste `active`** (l'archivage de fin d'année est en V3) : il ne peut ni être déplacé par la direction, ni rejoindre une nouvelle classe par code. Sans élève en production, à trancher avant la première rentrée (V3 ou `changement-etablissement-eleve`).
- **Retirer un élève de l'établissement** (départ en cours d'année) : non demandé, hors V2 ; à ranger avec CL-02 en V3 si besoin.
