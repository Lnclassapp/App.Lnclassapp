# Memo — Cartes d'activation vendues au point relais

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill en cours (2026-11-07) |
| **Ouvert le** | 2026-11-07 |
| **Branche** | `ccr-5a226b75-gfu543` *(branche de session imposée ; une branche `feature/cartes-activation` au premier code si le porteur le veut)* |
| **Programme** | — *(né du plan de lancement dans la DRENA de Tiassalé, 2026-11-07)* |

---

## Le problème

Lnclass ne sait pas encaisser. Le chantier `abonnement-mobile-money` (paiement Wave dans l'application) est resté au cadrage depuis le 2026-10-02 : pas de compte Wave Business, pas de clés, pas de code. Or Lnclass doit encaisser **avant le 20 novembre 2026** pour survivre : 100 élèves payants au minimum, 1 000 au mieux.

Les élèves de la DRENA de Tiassalé paient en espèces. Le porteur a des partenaires, les **points relais** (boutiques, points Wave) près des établissements, qui encaissent l'argent et le reversent sur son Wave. Il manque à l'application : un moyen de savoir qui a payé, un moyen de réserver l'usage à ceux qui ont payé, et un moyen de savoir ce que chaque point relais doit et ce que Lnclass doit à chaque point relais et à chaque école.

## Pour qui

- **Élève** : utilise l'application gratuitement 7 jours, puis achète une carte au point relais et saisit son code pour continuer jusqu'en juillet 2027.
- **Point relais** (partenaire, pas un utilisateur de l'application) : remet les cartes contre 10 000 F, verse l'argent au porteur à 12 h et 18 h, touche 200 F par abonnement chaque vendredi.
- **École** (l'établissement de l'élève) : a droit à 1 000 F par abonnement, versés à une date lointaine fixée plus tard.
- **Équipe** (le porteur) : crée les cartes, les remet aux points relais, saisit les versements reçus, voit ce que chacun doit et ce qu'il faut payer le vendredi.

## Pourquoi maintenant

Le terrain commence le **lundi 9 novembre 2026** dans 4 établissements privés de Tiassalé (environ 2 400 élèves). Sans revenus au 20 novembre, l'entreprise s'arrête. Échéances :

- **mercredi 11 novembre** : un élève peut saisir son code et son compte est actif ;
- **lundi 16 novembre** : les premiers comptes ouverts le 9 arrivent au 8e jour ; le blocage doit être en place.

## Hors périmètre

- **Tout paiement dans l'application** (Wave Checkout, Orange Money, MTN MoMo, carte bancaire) : le chantier `abonnement-mobile-money` est mis en pause, pas abandonné.
- **Le paiement en espèces à un enseignant ou à un directeur des études** : seul le point relais encaisse.
- **Un compte pour le point relais** : il ne se connecte pas ; l'équipe tient ses comptes.
- **Le versement automatique des commissions** : l'application calcule, le porteur paie lui-même par Wave.
- **Le rapprochement automatique avec le relevé Wave** : l'équipe saisit les versements à la main.
- **Le prix normal à 16 500 F et le paiement par trimestre à 5 500 F** : une seule offre, 10 000 F, jusqu'au 1er décembre 2026.
- **Les enseignants et le personnel de l'établissement** : ils ne paient pas, ne sont jamais bloqués, et **ne voient pas** qui a payé (Q10).
- **Le calendrier de versement des 1 000 F aux écoles** : l'application cumule ce qui est dû, la date se décide plus tard.
- **Le remboursement dans l'application** : géré hors application par le porteur (CGV : 7 jours).
- **L'import et la publication des leçons de 3e, 1re et Tle** : confiés à un autre agent.

## Ce que le grill a révélé

> Rempli au fil des questions. Les sept premières lignes viennent de l'échange de cadrage du lancement (2026-11-07).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Qui paie, et par quel moyen ? | L'élève ou son parent, **en espèces, uniquement au point relais**. Le point relais verse au porteur deux fois par jour (12 h et 18 h) sur l'un de ses 3 comptes Wave (plafond 15 000 000 F par mois chacun). | Aucune intégration de paiement. La preuve d'achat est la **carte** : un code unique remis par le point relais. Le versement est une écriture saisie par l'équipe. |
| Q2 — Combien, pour combien de temps ? | **10 000 F**, offre de lancement en paiement unique jusqu'au **1er décembre 2026** ; valable jusqu'en **juillet 2027**. | Un abonnement a une date de fin fixe (fin de l'année scolaire 2026-2027), pas une durée glissante. Le prix est porté par la carte, pas par l'élève. |
| Q3 — Que voit un élève qui n'a pas payé ? | Tout est ouvert **7 jours** depuis la création du compte, puis on l'invite à payer (le porteur préfère l'accès ouvert à l'accès fermé d'emblée). | La période gratuite passe de 30 jours (grill de `abonnement-mobile-money`, Q7) à **7 jours**. Au 8e jour, l'élève voit tout mais ne peut plus démarrer d'exercice ; l'historique reste. |
| Q4 — Comment savoir qui a payé sur un Wave personnel ? | Par le **code d'activation** remis au point relais et saisi par l'élève. | Un code n'active qu'un seul compte, une seule fois. |
| Q5 — Combien gagnent les intermédiaires ? | **200 F au point relais** et **1 000 F à l'école** par abonnement, chaque vendredi. Plus de commission aux enseignants ni à la DRENA. | Deux commissions calculées : celle du point relais par semaine, celle de l'école en cumul (voir Q7). Il reste 8 800 F au porteur par abonnement, 9 800 F en trésorerie tant que l'école n'est pas payée. |
| Q6 — Comment savoir ce qu'un point relais doit ? | Proposé par Claude, accepté : compter les **cartes remises** au point relais, pas les codes saisis. | Une carte a un **lot**, un **point relais** et un **état** (au stock, remise, activée). Ce que doit un point relais = cartes remises × 10 000 F − versements saisis. |
| Q7 — Quand payer les commissions ? | **Chaque vendredi** pour le point relais. Les **1 000 F de l'école** sont versés **à une date lointaine**, pour que Lnclass se renforce d'abord (porteur, 2026-11-07). | Une vue « à payer ce vendredi » : commissions des points relais sur la semaine écoulée. Pour les écoles, un **cumul dû** par établissement, sans échéance ; la date de versement se décidera plus tard (hors périmètre). |

| Q8 — Au 8e jour sans carte, un exercice donné par l'enseignant à toute la classe est-il bloqué ? | **Oui, tout est bloqué**, exercices donnés par l'enseignant compris (porteur, 2026-11-07). | Un seul blocage, au démarrage de toute séance d'exercice, quelle que soit son origine. L'enseignant verra des élèves « non faits » : l'école a intérêt à ce que toute la classe s'abonne. |
| Q9 — Quelle école touche les 1 000 F quand la carte est vendue près d'une autre école ? | **L'école de l'élève**, celle de son compte au moment où il saisit le code (porteur, 2026-11-07). | L'école est relevée à l'activation et figée : un changement d'école ensuite ne déplace pas la commission. Un élève sans école à l'activation ne rapporte de commission à personne. La carte n'a pas d'école, seulement un point relais. |
| Q10 — Qui, à l'école, voit les élèves qui ont payé ? | **Personne** : ni la direction ni les enseignants (porteur, 2026-11-07). | L'abonnement reste entre l'élève, l'équipe et le point relais. Aucune vue d'établissement ne change ; les relances passent par l'équipe et les points relais. La direction et les enseignants rejoignent le hors périmètre. |

## Cas limites identifiés

- L'élève paie mais n'active jamais sa carte : l'argent est dû par le point relais quand même (la carte est remise).
- Deux élèves essaient le même code : le second est refusé.
- Un élève tape un code faux plusieurs fois : il faut freiner les essais (un code devinable = un abonnement volé).
- Le point relais perd une carte ou se la fait voler : elle doit pouvoir être annulée tant qu'elle n'est pas activée.
- Un élève déjà abonné saisit une seconde carte : refus, la carte reste utilisable par un autre élève.

## Questions encore ouvertes

- Les élèves déjà inscrits depuis plus de 7 jours avant le lancement : bloqués dès la mise en ligne ?
- Le parent : voit-il quelque chose ?
