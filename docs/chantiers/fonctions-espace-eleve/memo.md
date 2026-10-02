# Memo — Fonctions de l'espace élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié — décisions acceptées le 2026-10-02 (porteur : « lance les lots ») ; [PRD](prd.md) et [plan](plan.md) ; FAQ livrée (commit `2bd842f2`) |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `ccr-93a43a40-3h3ty4` *(repartie de `Develop` le 2026-10-02, après la fusion d'`interface-epuree` phase 1)* |
| **Programme** | — *(né du grill d'`interface-epuree`, Q8 ; probablement à découper en plusieurs chantiers au grill)* |

---

## Le problème

La maquette V2 de l'accueil élève, validée par le porteur le 2026-10-02, montre six fonctions qui n'existent pas encore dans l'application :

1. **Échéances et retards** : un exercice assigné a une date limite (« À rendre demain »), la liste « À faire ensuite » est triée par échéance, et un point ambre signale une matière où un exercice est en retard.
2. **Durée d'un exercice** : la carte du haut annonce le temps estimé (« 15 min »).
3. **Paiement et abonnement** : une case « Paiement » dans la grille, et une annonce « Ton abonnement se termine dans 7 jours, renouvelle-le par Mobile Money ».
4. **Annonces signées** : un carrousel de messages signés (la direction, un enseignant, l'équipe Lnclass). Un message officiel ne se ferme pas, les autres se masquent avec « Annuler » pendant 5 secondes.
5. **Lecture audio** : chaque annonce peut être écoutée, et le bouton s'atténue une fois le message écouté.
6. **Aide** : un bouton « Besoin d'aide ? » dans l'en-tête de l'accueil, vers un support. Aucune page d'aide n'existe ; ajoutée le 2026-10-02 à la demande du porteur, après l'UDR-0058 d'`interface-epuree`.

Le chantier `interface-epuree` a décidé (grill, Q8) de n'épurer que l'existant : ces six éléments en sont retirés et regroupés ici.

## Pour qui

- **Élève** : il voit ses échéances, la durée d'un exercice, son abonnement, les annonces, et peut les écouter.
- **Enseignant** : il fixe les échéances en assignant, et signe ses annonces.
- **Direction** : elle signe les annonces officielles de son établissement.
- **Équipe** : elle gère les abonnements et signe les annonces « Lnclass ».

*Première version : qui fait quoi exactement se tranche au grill.*

## Pourquoi maintenant

L'accueil élève épuré sera livré sans ces fonctions. Tant qu'elles manquent, la carte du haut ne peut pas dire « à rendre demain », la grille n'a pas de case Paiement et il n'y a pas d'annonces. Ce chantier rend la V2 complète.

**Après le grill (2026-10-02)** : le chantier ne garde que **deux fonctions**, les échéances et l'aide. Le paiement part dans `abonnement-mobile-money` (Q2), les annonces et l'audio dans un chantier `annonces` (Q3), la durée est abandonnée (Q9). Le porteur y ajoute ensuite **quatre pages publiques** : Notre mission, Protection des données (Q15), CGU et CGV (Q16).

## Hors périmètre

- L'épuration des écrans élève : chantier `interface-epuree`.
- Le paiement et l'abonnement : chantier [`abonnement-mobile-money`](../abonnement-mobile-money/memo.md) (Q2).
- Les annonces signées et leur lecture audio : chantier `annonces`, à ouvrir (Q3).
- La durée d'un exercice : abandonnée (Q9).
- Un calendrier scolaire (vacances, jours fériés) : ignoré (Q10).
- Une heure de séance : seuls les jours comptent (Q8).
- Fermer un exercice après son échéance : jamais (Q5).
- La messagerie de classe et le temps réel, retirés du plan le 2026-09-22.

## Points de vigilance avant le grill

- **Paiement** : un paywall « Prépa BAC » a été **écarté et retiré du plan le 2026-09-22** (feuille de route de `refonte-application`). Réintroduire un paiement revient sur une décision du porteur : le grill doit le confirmer explicitement, et le paiement demandera un nouveau contexte métier, donc une décision d'architecture.
- **Annonces** : elles sont déjà prévues comme vague V6 du programme `refonte-application`, avec une décision acceptée sur la publication programmée et l'audience. Ce chantier doit s'y raccrocher plutôt que la doubler.
- **Six fonctions, quatre parties de l'application ou plus** (les classes pour les échéances, le contenu pour la durée, la communication pour les annonces et l'audio, un domaine nouveau pour le paiement). Un seul chantier risque d'être trop gros : le grill dira s'il faut un programme.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Le paiement, retiré du plan le 2026-09-22, revient-il ? | **Oui**, un vrai abonnement payé par Mobile Money | Revient sur la décision du 2026-09-22 (à tracer). Nouveau contexte métier (abonnement, opérateur, reçus) : un ADR est obligatoire, et le chantier dépasse un seul cycle |
| Q2 — Le paiement dans ce chantier ou à part ? | **À part** : un chantier `abonnement-mobile-money`, avec son ADR | Ce chantier traite cinq fonctions (échéances, durée, annonces, audio, aide). La case « Paiement » et l'annonce d'abonnement restent masquées ici et passent au nouveau chantier |
| Q3 — Les annonces (et l'audio) ici, ou à part ? Rien n'est construit ; l'ADR-0045 ne prévoit que l'équipe comme autrice | **À part** : un chantier `annonces`, qui étend l'ADR-0045 à la direction et aux enseignants, avec la lecture audio | Ce chantier se réduit à **trois fonctions** : échéances, durée, aide. Le carrousel d'annonces et le bouton d'écoute restent masqués ici |
| Q4 — Où mène « Besoin d'aide ? » ? | Une **fenêtre** sur ordinateur, une **carte qui monte du bas** (25 % de la hauteur) sur téléphone, avec trois options : **FAQ**, **WhatsApp**, **contact direct**. Le porteur fournira un exemple de la carte | Trois cibles à construire ou à fournir : une page FAQ (contenu à écrire), un numéro WhatsApp du support, un contact direct (à préciser à la réception de l'exemple). Une UDR pour la carte d'aide ; motif « bottom sheet » nouveau sur téléphone |
| Q5 — Après la date limite, l'exercice ? | **Toujours faisable, marqué « En retard »** (point ambre sur la matière) ; l'enseignant voit qu'il a été rendu après la date | Aucune fermeture automatique, aucun job de clôture lié à l'échéance. L'échéance est une donnée d'affichage et de tri ; « rendu en retard » se calcule en comparant la date de la session terminée à l'échéance |
| Q6 — Sur quoi fixer une échéance ? Obligatoire ? | **L'enseignant n'assigne qu'un exercice**, « pour la séance prochaine », pas pour une date choisie. **Cours et fiches ne sont plus assignables** : retirer leurs boutons d'assignation. L'échéance se **déduit de l'emploi du temps** de l'enseignant pour la classe, demandé lors des premières assignations. Échéance facultative | Change le domaine : `Entities::Classroom::Assignable::TYPES` passe à `Exercise` seul (ADR à écrire, UDR des écrans cours et fiche à amender). Nouveau : un emploi du temps enseignant × classe (jours et heures de séance), une échéance calculée = la prochaine séance après l'assignation. À trancher : le sort des assignations de cours et de fiches déjà en base |
| Q7 — Que deviennent les assignations de cours et de fiches déjà faites ? | **Il n'y en a pas pour le moment** (porteur) | Pas de conversion de données. La migration qui restreint `assignable_type` à `Exercise` vérifie quand même la base au déploiement et échoue s'il en trouve, plutôt que de les perdre |
| Q8 — Quel emploi du temps demande-t-on ? | **Les jours de la semaine** où l'enseignant voit la classe (ex. lundi et jeudi), cochés lors des premières assignations, modifiables ensuite | Nouvelle donnée : jours de séance par enseignant × classe (pas d'heures). Échéance = le prochain de ces jours strictement après l'assignation ; sans jours renseignés, pas d'échéance. À trancher : vacances et jours fériés |
| Q9 — D'où vient la durée d'un exercice (« 15 min ») ? | **Pas de durée** : retirée de la maquette | La fonction « durée » sort du chantier. La carte du haut n'affiche pas de temps estimé ; l'UDR-0058 (§3.2) est à amender en phase 2 d'`interface-epuree`. Reste : **échéances** et **aide** |
| Q10 — Vacances et jours fériés ? | **On ignore** : l'échéance tombe le prochain jour de séance, même en vacances | Aucun calendrier scolaire à saisir. Un exercice peut paraître « en retard » pendant les vacances ; sans conséquence, puisque rien ne se ferme (Q5) |
| Q11 — L'enseignant peut-il passer la question des jours ? | **Oui**, « Plus tard » : l'exercice est assigné sans échéance, et la question revient à la prochaine assignation à cette classe | Une assignation n'est jamais bloquée. Le formulaire d'assignation porte une étape facultative « jours de séance » tant que l'enseignant n'a pas renseigné ses jours pour la classe ; les jours restent modifiables ensuite (page de la classe) |
| Q12 — Où l'enseignant voit-il les retards ? | **Sur l'exercice assigné**, dans le suivi de la classe : « 18 faits, dont 3 en retard · 7 pas encore faits », **avec la liste nominative des retardataires** | Le suivi d'une assignation gagne deux comptes et une liste d'élèves en retard, visible du seul enseignant de la classe (et de l'équipe), jamais d'un élève (UDR-0011). Policy et test de refus à prévoir |
| Q13 — À quoi ressemble la carte d'aide ? | **Exemple fourni par le porteur** (capture d'une application de banque mobile, non versionnée : elle montre sa photo). Carte « Contactez-nous » qui monte du bas : poignée, croix de fermeture, fond assombri ; une ligne par option = icône dans un rond teinté, titre, ligne grise (horaires, délai de réponse), chevron. Options Lnclass : **FAQ**, **WhatsApp** (« Chatter avec le support »), **contact direct = appel téléphonique** au service client | UDR de la carte d'aide (bottom sheet sous `lg`, modale au-dessus, comme Q4). Données à fournir par le porteur : numéro d'appel, numéro WhatsApp, horaires du support. Liens `tel:` et `https://wa.me/<numéro>` ; aucun appel sortant ni dépendance côté serveur |
| Q14 — Qui écrit et tient la FAQ ? | **Écrite dans l'application** : une première FAQ de 8 à 10 questions rédigée à partir des écrans existants, relue par le porteur ; toute modification passe par une PR | Page statique, textes dans les locales (`t(".key")`), aucune table ni écran d'administration. La FAQ doit suivre les écrans : elle entre dans la définition de « fini » des chantiers qui changent un parcours élève |
| Q15 — Ajout du porteur (2026-10-02) : pages Mission et Protection des données | **Deux pages publiques** : « Notre mission » et « Politique de protection des données », à découper en lots | Pages statiques du contexte `communication`, sur le motif de `/aide` (UDR-0063). La mission part de la landing ; la politique part d'un inventaire factuel des données traitées ([`pages-publiques.md`](pages-publiques.md)) ; ce qui relève du porteur ou d'un juriste reste « à fournir ». Aucune table |
| Q16 — Ajout du porteur (2026-10-02) : CGU et CGV | **Conditions générales d'utilisation et de vente**, au nom de **« Lnclass Côte d'Ivoire »**, aussi responsable du traitement des données | Deux pages publiques de plus (UDR-0063). CGU : brouillon factuel (comptes, PIN, code de classe, contenu, usage, suspension) ; CGV : squelette sans chiffre, **dont le lot dépend du chantier `abonnement-mobile-money`**. Adresse, RCCM et contact de l'entité : à fournir |
| Q17 — Les 11 choix faits sans réponse du grill (ADR-0072 §9, UDR-0061, UDR-0062, UDR-0063) ? | **Acceptés tels que rédigés** (porteur, 2026-10-02 : « lance les lots ») : session terminée le jour de l'échéance = à l'heure ; ambre aujourd'hui et demain ; dimanche exclu ; l'équipe assigne sans échéance et n'écrit pas les jours d'un enseignant ; tout décocher = non renseigné ; retirer sa déclaration efface ses jours ; « fait » = session standard rattachée à l'assignation ; exercice terminé sans date, en fin de liste ; la direction ne voit pas les retards ; ronds de la carte d'aide tous `brand-soft` ; pages publiques au vouvoiement | Plus de question bloquante sur les échéances ; les lots C, D, E codent ces règles |
| Q18 — Chemin de l'enseignant vers les exercices, sans cours assignés ? | **Bloc « Cours » sur la page de la classe** (UDR-0062 §3.4) : retenu par l'orchestrateur, qui applique la recommandation ; le porteur n'a pas répondu et a demandé de lancer. **Révisable par le porteur** | Lot E le construit ; la carte « Cours assignés » de « Ma classe » est retirée (amendement de l'UDR-0011 accepté) |

## Cas limites identifiés

- **Assignation sans jours renseignés** (l'enseignant a passé la question) : pas d'échéance ; l'exercice se range après ceux qui en ont une, et n'est jamais « en retard ».
- **Assignation le jour même d'une séance** : l'échéance est la séance **suivante**, jamais le jour même.
- **Jours modifiés après coup** : les échéances déjà calculées ne bougent pas ; seules les nouvelles assignations suivent les nouveaux jours.
- **Plusieurs enseignants dans une classe** : chacun a ses propres jours ; l'échéance d'un exercice suit les jours de l'enseignant qui l'a assigné.
- **Exercice terminé en retard, puis refait** : il reste « rendu en retard » (date de la première session terminée) ; une session refaite n'efface pas le retard.
- **Élève arrivé dans la classe après l'échéance** : à trancher au PRD (en retard dès son arrivée, ou échéance comptée à partir de son arrivée).
- **Exercice archivé ou désassigné** : il sort du suivi et de « À faire », retard compris.
- **Retrait de l'assignation de cours et de fiches** : la migration refuse de passer s'il en reste en base (Q7).

## Questions encore ouvertes

*Mises à jour le 2026-10-02 (« lance les lots »). Détail et lots bloqués : [PRD §8](prd.md#8-points-ouverts).*

- **Carte d'aide** : numéro d'appel, numéro WhatsApp, horaires et délai de réponse du support, à fournir par le porteur. Les numéros de contact de l'entité servent-ils aussi au support ?
- **Élève arrivé après l'échéance** : voir les cas limites. Tant qu'il n'est pas tranché, la règle générale s'applique (aucun cas particulier codé).
- **Liste nominative** : nommer aussi les élèves « pas encore faits » après l'échéance ? (par défaut, non)
- **Conservation (lot R)** : que veut dire **« départ »** (compte fermé à la demande, élève sorti de toute classe, fin d'année scolaire sans réinscription, enseignant retiré) ? Quelles données sont **« sensibles »** (nom, numéro, photo, genre, adresses IP) ? Les sessions et badges restent-ils rattachés au compte anonymisé (proposition, qui garde les statistiques de la classe) ?
- **Constat** : l'anonymisation (`Identity::AnonymizeUser`, ADR-0036) n'est pas construite et aucune purge n'est programmée. La politique ne peut promettre « 30 jours » qu'après le lot R, livré **avant le déploiement**.
- **Relecture juridique** (avant la sortie de l'application) : RCCM, déclaration ou autorisation ARTCI, droit applicable et tribunaux, responsabilité, âge minimum et accord des parents, bases légales, région d'hébergement. Le porteur ne les fournira pas : **les juristes les complètent** ([`pages-publiques.md`](pages-publiques.md), encadré « Relecture juridique »).
- **CGV** : offre, prix, durée, remboursement et réclamation, à fixer par `abonnement-mobile-money`.
- **Acceptation des CGU à l'inscription** (case à cocher) : hors de ce chantier.

**Données légales fournies par le porteur (2026-10-02)** : entité **Lnclass Côte d'Ivoire SARL**, responsable du traitement ; adresse « Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph » ; contact **+225 05 44 32 00 20** et **+225 05 84 25 80 85** ; conservation **30 jours après le départ**, données personnelles sensibles **anonymisées par défaut**, informations d'usage **conservées** pour la progression et le suivi par les enseignants et l'établissement.
