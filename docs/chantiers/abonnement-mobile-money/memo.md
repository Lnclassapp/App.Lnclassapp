# Memo — Abonnement payé par Mobile Money (Wave)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill en cours (Q1 à Q8, 2026-10-02) |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `ccr-93a43a40-3h3ty4` *(branche de session, partagée avec `fonctions-espace-eleve` ; une branche `feature/abonnement-mobile-money` au premier code)* |
| **Programme** | — *(né du grill de `fonctions-espace-eleve`, Q1 et Q2)* |

---

## Le problème

La maquette V2 de l'accueil élève montre une case « Paiement » et une annonce « Ton abonnement se termine dans 7 jours, renouvelle-le par Mobile Money ». Lnclass n'a aujourd'hui ni abonnement, ni paiement, ni moyen de savoir qui a payé.

Le paiement avait été **retiré du plan le 2026-09-22** (F-24, paywall « Prépa BAC », [feuille de route](../refonte-application/feuille-de-route.md)). Le porteur l'y remet le 2026-10-02 (grill de `fonctions-espace-eleve`, Q1), dans un chantier à part (Q2).

## Pour qui

- **Élève** : voir quand son abonnement se termine, le renouveler en payant avec Wave depuis son téléphone.
- **Équipe** : voir qui a payé, suivre les paiements et rembourser si besoin.
- *Parent, établissement : à trancher au grill (qui paie ?).*

## Pourquoi maintenant

*À confirmer au grill* : le modèle économique de Lnclass dépend de l'abonnement ; la V2 de l'accueil élève le montre déjà.

## Ce que l'API Wave permet (doc lue le 2026-10-02)

Source : [docs.wave.com/business](https://docs.wave.com/business#api-reference), pages [Checkout](https://docs.wave.com/checkout) et [Webhooks](https://docs.wave.com/webhook), fournies par le porteur après son échange avec Wave.

| Sujet | Ce que dit la doc | Conséquence pour Lnclass |
|---|---|---|
| Encaisser | **Checkout API** : `POST /v1/checkout/sessions` avec `amount` (chaîne), `currency` `XOF`, `success_url`, `error_url` (HTTPS) ; optionnels `client_reference` (≤ 255 car.) et `restrict_payer_mobile` (E.164) | Un paiement = une session ; `client_reference` porte notre identifiant de paiement ; `restrict_payer_mobile` peut imposer le numéro de l'élève (ou du parent) |
| Parcours | La réponse donne `wave_launch_url` : l'ouvrir dans le navigateur (pas de webview) ; la session expire **30 min** après sa création (`when_expires`) | Un bouton « Payer avec Wave » redirige ; au-delà de 30 min, on recrée une session |
| États | `checkout_status` : `open`, `complete`, `expired` ; `payment_status` : `processing`, `cancelled`, `succeeded` ; `transaction_id` visible dans l'app Wave de l'élève | Le `transaction_id` sert de reçu et de preuve en cas de litige |
| Confirmer | **Webhooks** recommandés plutôt que l'interrogation : `checkout.session.completed`, `checkout.session.payment_failed` | Le retour sur `success_url` **ne prouve rien** : seul le webhook (ou une lecture de la session) active l'abonnement |
| Sécurité des webhooks | En-tête `Wave-Signature: t=<horodatage>,v1=<signature>` ; HMAC-SHA256 de `horodatage + corps brut` avec un secret `wave_sn_WHS_…` ; plusieurs `v1` pendant une rotation ; rejeu à refuser par l'horodatage | Vérifier la signature sur le corps brut, avant tout traitement ; secret dans les credentials, jamais dans le dépôt |
| Livraison | « Au moins une fois », jusqu'à **3 jours** de reprises, **désordre et doublons possibles** ; répondre `2xx` en moins de **5 s** | Traitement idempotent par l'`id` de l'événement ; réponse immédiate, travail dans un job |
| Authentification | `Authorization: Bearer wave_sn_prod_…` ; signature des requêtes sortantes possible (`Wave-Signature`, secret `wave_sn_AKS_…`) | Clé API à droits minimaux (portail Wave Business) |
| Rembourser, annuler | `POST /v1/checkout/sessions/:id/refund` ; `POST /v1/checkout/sessions/:id/expire` | L'équipe peut rembourser depuis Lnclass, ou depuis le portail Wave |
| Retrouver | `GET /v1/checkout/sessions/:id`, par `transaction_id`, ou `search` par `client_reference` | Rattrapage possible si un webhook se perd |
| Erreurs | JSON `code`, `message`, `details` ; `429` en cas de limite de débit | Reprise avec attente sur 429 et erreurs réseau |
| Configuration | Portail Wave Business → Developers → Webhooks : URL HTTPS, stratégie « Signing Secret », événements choisis ; liste d'IP d'envoi de Wave | Le pare-feu ou le proxy de Railway ne doit pas filtrer ces IP |

**Ce que la doc ne propose pas** :

- **aucun prélèvement récurrent** : chaque renouvellement est un nouveau paiement, déclenché par l'élève ;
- **aucun bac à sable** mentionné : à demander à Wave (Fatoumata Makadi, agent Wave du porteur) ;
- **aucun en-tête d'idempotence** à la création d'une session : c'est à nous d'éviter deux sessions pour le même renouvellement.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Tout autre moyen de paiement que Wave (Orange Money, MTN MoMo, carte), tant que le grill n'en décide pas autrement.
- Le prélèvement automatique : Wave ne le propose pas.
- Les gains des enseignants et l'offre « Prépa BAC » de F-24 : ils restent retirés du plan.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Qui paie ? | **L'élève ou son parent**, par Wave (porteur, 2026-10-02) | Un abonnement par compte élève ; `restrict_payer_mobile` ne peut pas imposer le numéro de l'élève (le parent paie parfois) |
| Q2 — Quelle durée ? | **L'année scolaire** (porteur, 2026-10-02) | Un paiement par année scolaire (septembre à juillet, ADR-0041) ; pas de renouvellement mensuel. Reste à trancher : prix, ce qui est gratuit, paiement en cours d'année (plein tarif ou prorata), remboursement |
| Q3 — Quel prix ? | **16 000 F CFA** pour l'année scolaire (porteur, 2026-10-02) | `amount: "16000"`, `currency: "XOF"` à la création de la session Wave |
| Q4 — Qu'est-ce qui est gratuit ? | **Une période d'essai** : tout est ouvert pendant la découverte, puis il faut s'abonner | Durée de l'essai à fixer ; l'essai démarre à la création du compte (à confirmer) ; un compte ne bénéficie de l'essai qu'une fois |
| Q5 — Abonnement en cours d'année ? | **Plein tarif**, valable jusqu'à la fin de l'année scolaire | Pas de prorata ; l'échéance de l'abonnement est la fin de l'année scolaire en cours (ADR-0041) |
| Q6 — Remboursement ? | **Sous 7 jours** après le paiement, par Wave, sur demande | `POST /v1/checkout/sessions/:id/refund` ; au-delà de 7 jours, pas de remboursement ; geste de l'équipe, journalisé |
| Q7 — Durée de l'essai ? | Révisé par le porteur (2026-10-02) : **jours 1 à 14 : essai complet** ; **jours 15 à 30 : accès complet avec des avertissements pour payer** ; **à partir du jour 30 : blocage** (Q8), à compter de la création du compte | Trois phases calculées depuis la création du compte, sans job : `trial` (≤ 14 j), `grace` (15 à 30 j, bandeau « Ton essai se termine dans N jours, abonne-toi pour 16 000 F CFA »), `blocked` (> 30 j sans abonnement payé). Un compte n'a l'essai qu'une fois |
| Q8 — Après l'essai, sans abonnement ? | L'élève garde **son compte et son historique** (archive). Il **voit tous les exercices, assignés compris**, mais **ne peut pas démarrer de session** : il est **invité à s'abonner** (précision du porteur, 2026-10-02) | Garde d'accès au démarrage d'une session (`StartExerciseSession`) : un nouveau refus « abonnement requis » ; les exercices assignés sont concernés aussi. Les listes, fiches et pages d'exercice restent visibles ; le bouton « Commencer » mène à l'invitation à s'abonner. ADR à écrire (contexte `billing`, port de paiement, garde d'accès) |

## Cas limites identifiés

- L'élève paie, ferme l'application avant le retour : le webhook active quand même l'abonnement.
- Le webhook arrive deux fois, ou après un `payment_failed` : traitement idempotent, l'état final suit le dernier état connu de la session.
- L'élève ouvre deux sessions et paie les deux : un remboursement, ou une prolongation double ?
- Le webhook n'arrive jamais : un job de rattrapage relit les sessions encore `open` ou `processing`.

## Questions encore ouvertes

- **Qui paie** : l'élève, son parent, ou l'établissement pour toute une classe ?
- **Quoi** : prix, durée (mois, trimestre, année scolaire), et ce que l'abonnement débloque. Qu'est-ce qui reste gratuit ?
- **À l'expiration** : que perd l'élève, et a-t-il un délai de grâce ?
- **Numéro du payeur** : imposer celui du compte (`restrict_payer_mobile`), ou laisser payer depuis n'importe quel Wave ?
- **Bac à sable Wave** et clés de test : à obtenir avant le premier lot de code.
- **Reçu** : `transaction_id` seul, ou un reçu Lnclass ?
- **ADR** : nouveau contexte borné `billing`, port de paiement, table des paiements et des événements reçus.
- **CGV à finaliser avec l'offre** : le squelette des conditions générales de vente est prêt dans `fonctions-espace-eleve` ([UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md), [brouillon §4](../fonctions-espace-eleve/pages-publiques.md#4-conditions-générales-de-vente--conditions-vente)) ; offre, prix, durée, renouvellement sans prélèvement, rétractation, remboursement et réclamation se remplissent avec ce grill. Le lot CGV attend ce chantier.
