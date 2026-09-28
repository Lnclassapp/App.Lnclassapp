# Memo — Pilotage de l'équipe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/pilotage-equipe` |
| **Programme** | [`refonte-application`](../refonte-application/feuille-de-route.md) — vague **V4**, traçabilité TR-09, TR-10, TR-11, TR-12 |

---

## Le problème

L'équipe Lnclass ne sait pas comment la plateforme est utilisée. Elle ne voit ni combien d'élèves travaillent réellement, ni quelles DRENA sont couvertes, ni quels établissements ont des classes sans enseignant ou des enseignants sans élèves. L'entrée « Pilotage » de sa navigation existe mais reste inactive depuis la V1 (UDR-0006, UDR-0018 §4).

L'ancienne application avait un « Control Center » (TR-10) : il n'avait aucun test et plantait après un renommage de méthode. La répartition des élèves par niveau (TR-12) n'a jamais été exécutée. Enfin, retrouver un élève ou un enseignant (TR-11) passe aujourd'hui par le seul numéro exact (« Débloquer un compte », UDR-0020), sans recherche par nom.

Depuis l'ADR-0049 (F-27), l'application ne charge aucun outil de mesure tiers. Les indicateurs doivent donc être lus côté serveur, dans les données métier que l'application possède déjà. Tant que cet écran n'existe pas, l'équipe n'a **aucun** indicateur.

## Pour qui

Le membre de l'**équipe** (`team`, tout sous-rôle), second facteur vérifié, quand il prépare une tournée de terrain, répond à une DRENA, ou vérifie qu'une campagne d'inscription a pris. Aucun autre acteur : ni l'élève, ni l'enseignant, ni la direction d'établissement.

## Pourquoi maintenant

La V1 est livrée : les élèves, les classes, les sessions d'exercice et les assignations produisent des données réelles. La V4 inscrit `pilotage-equipe` au programme, et le porteur a lancé le volet le 2026-09-28. C'est aussi la seule contrepartie promise par l'ADR-0049 au retrait de GTM et de Clarity.

## Hors périmètre

- **Les sous-rôles de l'équipe** (F-16, ADR-0038) : c'est le chantier `sous-roles-equipe`. Ici, tout membre `team` lit le pilotage. La matrice de l'ADR-0038 autorise déjà les trois sous-rôles à « lire les indicateurs agrégés » : rien ne sera à défaire.
- **La fiche détaillée d'un compte** (ID-21, ID-22, V2) : la recherche liste des comptes, elle ne mène à aucune fiche.
- **Les exports** (CSV, PDF) et les **courbes dans le temps** (séries hebdomadaires) : une V2 du pilotage, si l'usage le demande.
- **Tout outil de mesure navigateur**, tout cookie, tout traceur : interdits par l'ADR-0049.
- **Le suivi pédagogique fin** (par exercice, par notion, par classe) : c'est la V3 pour l'enseignant et la V5 pour la remédiation.
- **Une nouvelle table** ou une table d'agrégats précalculés : les volumes de la V1 se lisent en direct.
- Le cache des indicateurs : aucun en V1 du pilotage (même choix que l'accueil équipe, UDR-0018 §2.5).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qu'est-ce qu'un compte « actif » ? Il n'existe pas de statut de compte. | Un compte non anonymisé (`anonymized_at` vide, ADR-0036). | Les comptes anonymisés ne sont comptés nulle part, ni recherchés. |
| Un élève « actif sur 7 jours » : une session terminée, ou commencée ? | Commencée : un élève qui ouvre un exercice sans le finir a quand même travaillé. | Critère sur la date de début de session, tous statuts confondus. Les exercices **terminés** sont un indicateur séparé. |
| Le filtre de période et les « 7 jours » demandés : qui gagne ? | Tous les indicateurs de **flux** (inscrits, élèves actifs, exercices terminés, taux de réussite, assignations) suivent la période choisie, 7 jours par défaut. Les indicateurs de **stock** (comptes, établissements, classes, répartition par niveau) n'en dépendent pas. | Deux blocs de cartes, « Sur la période » et « En ce moment ». Les nouveaux inscrits sur 30 jours se lisent en choisissant « 30 jours ». *Décidé par le porteur le 2026-09-28.* |
| À quelle DRENA appartient un élève ? Il n'y a pas de colonne. | À celle de l'établissement de sa **classe principale active de l'année en cours** (ADR-0040, ADR-0041). Un élève sans classe n'a pas de DRENA. | Le filtre DRENA exclut les élèves sans classe ; la répartition nationale les montre sur une ligne « Sans classe ». |
| Et un enseignant ? | Par son établissement **principal** (ADR-0030). | Même règle pour le compte des enseignants par DRENA. |
| L'équipe a-t-elle une DRENA ? | Non. | Sous un filtre DRENA, la carte « Équipe » affiche un tiret et les comptes récents de l'équipe disparaissent. |
| Un membre de l'équipe voit-il le numéro d'un élève mineur dans la liste des inscrits ? | Non : la liste sert à voir que les inscriptions arrivent, pas à contacter. | Numéro masqué (`01 •• •• •• 45`) dès la query : le numéro complet ne quitte jamais la base pour cet écran. La recherche masque aussi. |
| La recherche par numéro partiel ne recrée-t-elle pas l'annuaire que l'UDR-0020 refusait ? | L'UDR-0020 reportait l'annuaire à la V4 : c'est ici. La recherche est bornée (20 par page, 2 caractères au moins, élèves et enseignants seulement), réservée à l'équipe. | La recherche exige 2 caractères, ou 4 chiffres pour un numéro ; les comptes `team` et `school_admin` n'y sont pas. |
| Une DRENA inconnue passée dans l'URL ? | On n'invente pas d'erreur : la vue nationale s'affiche et la liste déroulante revient à « Toutes les DRENA ». | Pas de 404 sur un filtre. |
| Une période inconnue dans l'URL ? | 7 jours. | Idem. |
| Le taux de réussite d'une période sans exercice terminé ? | Aucun : « — », jamais « 0 % », qui mentirait. | Cas vide explicite dans la query et la vue. |
| Une classe archivée, ou d'une année passée, compte-t-elle ? | Non (ADR-0041, comme l'accueil équipe). | Classes, élèves par niveau et couverture ne lisent que les classes actives de l'année scolaire. |
| Un établissement « actif » ? | Statut `active` (ADR-0030). Brouillons et inactifs ne comptent pas dans la couverture. | Couverture sur les seuls établissements actifs. |
| Les barres de la répartition : une bibliothèque de graphiques ? | Non (ADR-0051, budget 60 Ko). Et l'UDR-0005 interdit l'attribut `style`. | Largeurs par classes Tailwind littérales (`w-1/20` … `w-full`), en pas de 5 %, avec le nombre et le pourcentage écrits. |
| Combien de requêtes pour afficher la page ? | Un nombre fixe, qui ne dépend pas du nombre de DRENA, d'établissements ni d'élèves. | Un test compte les requêtes sur deux volumes et exige le même nombre. |
| Faut-il un index ? | Mesure faite (EXPLAIN au journal) : parcours séquentiels de 18 à 24 ms sur 100 000 lignes ; page entière 0,17 à 0,27 s pour 10 000 élèves, 0,64 s pour 100 000. Les volumes de la V1 sont bien en dessous. | Aucun index en V1 ; seuil de reprise (300 ms en production) écrit dans l'ADR-0062. |

## Cas limites identifiés

- Base vide : toutes les cartes à 0, taux de réussite « — », répartition et tableau DRENA avec leur état vide, liste d'inscrits vide.
- Un élève inscrit dans deux classes : seule sa classe principale active compte (ADR-0040) ; il n'est jamais compté deux fois.
- Un élève qui a quitté sa classe (`left_at`) : il n'est plus placé, il passe « Sans classe ».
- Un enseignant rattaché à deux établissements : seul le principal le place dans une DRENA ; la couverture « avec au moins un enseignant » lit tous ses rattachements.
- Une session commencée le dernier jour de la période, à 23 h 59 : dans la période (bornes en jours entiers, fuseau de l'application).
- Une recherche d'un seul caractère : aucun résultat, message « Tapez au moins 2 caractères ».
- Une recherche qui contient `%` ou `_` : échappée, jamais interprétée comme joker.

## Décisions par défaut — décidé par le porteur le 2026-09-28

> Prises par défaut pour avancer, puis **validées telles que proposées par le porteur le 2026-09-28** (« je valide les choix du pilotage »). Chacune est reprise dans l'[ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) ou l'[UDR-0049](../../decisions/udr/0049-page-pilotage-de-l-equipe.md), au statut « Accepté ».

1. **La période gouverne tous les indicateurs de flux**, 7 jours par défaut (7 j, 30 j, année scolaire) ; les stocks n'en dépendent pas. — *décidé par le porteur le 2026-09-28*
2. **Élève actif** = au moins une session d'exercice **commencée** dans la période, quel qu'en soit le statut. — *décidé par le porteur le 2026-09-28*
3. **Rattachement territorial** : un élève par sa classe principale active de l'année, un enseignant par son établissement principal ; l'équipe n'a pas de DRENA. — *décidé par le porteur le 2026-09-28*
4. **Le filtre DRENA s'applique à toute la page**, tableau « Par DRENA » compris (une seule ligne) ; la recherche reste nationale. — *décidé par le porteur le 2026-09-28*
5. **Numéros masqués** dans la liste des inscrits **et** dans la recherche (deux premiers et deux derniers chiffres). — *décidé par le porteur le 2026-09-28*
6. **Recherche** : élèves et enseignants seulement, 2 caractères minimum (4 chiffres pour un numéro), 20 résultats par page ; pour un enseignant, la colonne « Classe » donne le nombre de classes qu'il enseigne cette année. — *décidé par le porteur le 2026-09-28*
7. **Aucun cache, aucun index** en V1 du pilotage ; seuil de reprise au journal. — *décidé par le porteur le 2026-09-28*
8. **Taux de réussite** = moyenne des scores des sessions terminées dans la période (remédiations comprises), arrondie à l'unité. — *décidé par le porteur le 2026-09-28*
9. **Placement de la page** : « Pilotage » est la 5ᵉ entrée de la navigation équipe, déjà réservée ; aucune entrée ajoutée. — *décidé par le porteur le 2026-09-28*

## Questions encore ouvertes

- Le porteur voudra-t-il une tendance (comparaison à la période précédente) ? Reporté à une V2 du pilotage, à la demande.
- Faut-il exporter le tableau « Par DRENA » pour les rapports aux directions régionales ? Hors périmètre, à rouvrir si demandé.
