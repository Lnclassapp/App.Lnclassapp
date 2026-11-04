# Memo — CRM des écoles

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/crm-ecoles` |
| **Programme** | — |

---

## Le problème

L'équipe démarche les établissements (appels, messages WhatsApp, visites, démonstrations), mais rien de ce suivi ne vit dans l'application. Où en est-on avec telle école, qui l'a contactée, que s'est-il dit, quand faut-il la relancer : ces réponses sont dans les téléphones et les mémoires de chacun.

L'espace équipe connaît déjà chaque établissement (la liste nationale est importée) et son usage réel (enseignants, élèves, activité), mais il ne sait pas où en est la **relation** avec lui. Une école inscrite qui cesse de servir n'est repérée par personne.

## Pour qui

- **Team, sous-rôles `admin` et `field`** : ceux qui gèrent déjà les établissements. Au quotidien, quand ils préparent leurs appels et visites, puis juste après un échange, pour le noter.
- **Team `content`** : n'a pas la gestion des établissements aujourd'hui ; ne voit pas le suivi.
- Enseignant, élève, direction : ne voient jamais le suivi.

## Pourquoi maintenant

- La prospection des écoles est la priorité de croissance, et elle repose aujourd'hui sur la mémoire d'une seule personne à plein temps.
- Le chantier est le projet de stage de Touré, nommé **« Lnclass Intelligent »** : application et rapport livrés avant le 15 novembre 2026, soit 8 jours ouvrés.

## Hors périmètre

- Les élèves et les parents comme cibles commerciales : on suit des établissements, pas des familles.
- La création d'un établissement depuis le suivi : les établissements n'entrent que par l'import existant.
- Le tableau en colonnes à glisser (kanban) : V2.
- Les relances créées automatiquement (école devenue inactive) : V2.
- L'import des échanges passés depuis un tableur ou WhatsApp : V2.
- L'envoi de messages (WhatsApp, SMS, e-mail) depuis l'application : on note les échanges, on ne les envoie pas.
- Le revenu et l'abonnement : rien n'existe encore dans la base pour les suivre.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui démarche les écoles et utilisera le suivi ? | Le porteur, Touré, Konan, puis les futures recrues de l'équipe. | Le suivi est multi-utilisateur : chaque école a un **responsable**, chaque relance a un destinataire, « Mes relances » a un sens. Le changement de responsable (départ, réorganisation) est un parcours à part entière. Un responsable dont le compte est retiré ne doit pas laisser ses écoles orphelines en silence. |
| Qu'est-ce qui rend l'outil « intelligent » en V1 ? | Une règle calculée, sans IA générative : chaque jour, l'outil propose les écoles à relancer d'après leur usage réel. Les agents IA (Kimi, DeepSeek ou Gemini) viendront après. | Une liste « à relancer » calculée entre dans le périmètre (environ 1 jour, pris sur la marge). Le journal des échanges doit être **structuré dès la V1** (type d'échange, interlocuteur, résultat, motif en cas de perte, note libre) : c'est la matière première des futurs agents. |
| Les étapes « Inscrite » et « Active » sont-elles saisies ou calculées ? | Mélange validé : **Inscrite** (au moins un compte rattaché à l'école) et **Active** (activité dans les 14 derniers jours) sont calculées d'après l'usage réel ; **Prospect, Démo faite, Abonnée, Perdue** sont saisies à la main. | L'étape affichée n'est pas une simple colonne : elle combine une étape saisie et l'usage lu dans l'app. Il faut fixer laquelle l'emporte (une école « Perdue » qui se remet à servir, une école « Abonnée » devenue inactive). Personne ne peut marquer « Active » une école sans usage. |
| Quand l'étape saisie et l'usage se contredisent, laquelle l'emporte ? | **L'usage ne fait que monter l'étape.** Prospect ou Démo faite passent d'office à Inscrite puis Active dès que l'usage le montre. Une école Abonnée reste Abonnée même inactive. Une école Perdue qui sert de nouveau redevient Active. | Ordre des étapes fixé : Prospect → Démo faite → Inscrite → Active → Abonnée, avec Perdue à part. Une école Abonnée inactive depuis 14 jours entre dans la liste « à relancer » sans changer d'étape. Le retour d'une école Perdue doit **prévenir son responsable** et garder une trace (date, ancienne étape) dans le journal de l'école. L'étape affichée est donc recalculée à chaque lecture : elle n'est jamais stockée seule. |
| Qu'est-ce qui compte comme activité pour « Active » ? | **Un geste pédagogique** : un enseignant donne un devoir ou publie un contenu, ou un élève rend un travail. Les connexions seules ne comptent pas. | Le signal se lit dans le travail des classes, pas dans les connexions. Un geste compte pour **l'école de la classe concernée** : un enseignant présent dans deux écoles fait vivre chacune séparément. La fiche école montre la date du dernier geste et son auteur, pour que le responsable comprenne l'étape affichée. Une école avec des comptes mais aucun geste reste Inscrite. |
| Que deviennent les écoles et relances d'un responsable dont le compte est retiré ? | Elles passent **« sans responsable »** et restent ouvertes. Une liste en tête de l'espace les montre à tous les `admin` jusqu'à leur réattribution. | Le retrait d'un compte équipe n'est jamais bloqué par le suivi. « Sans responsable » est un état normal, pas une erreur : une école jamais attribuée y figure aussi. Les relances gardent leur auteur d'origine dans l'historique. Réattribuer est un geste `admin` (en masse ou école par école), tracé dans le journal de l'école. Un `field` ne peut pas prendre une école d'un autre. |
| Entre deux `field`, que voit et que fait chacun sur les écoles de l'autre ? | **Chacun voit tout et peut noter un échange partout.** Seul un `admin` change le responsable ou l'étape d'une école qui n'est pas la sienne. | Trois droits distincts à porter par la règle d'accès : voir et noter (tout `admin` et `field`), changer l'étape (le responsable ou un `admin`), changer le responsable (`admin` seul). Un échange noté par un autre que le responsable **prévient le responsable**, sinon il découvre l'appel d'un collègue au moment de rappeler. Chaque échange affiche son auteur. |
| Quels usages d'IA entrent dans la livraison du 15 novembre ? | **Les quatre** : compte rendu dicté, fiche de briefing avant appel, rapport pédagogique pour la direction, brouillon de relance WhatsApp. | Plus aucune marge sur 8 jours ouvrés : le suivi et la règle « à relancer » passent d'abord, les quatre usages d'IA se branchent ensuite sur un **seul accès aux modèles**, partagé. Le compte rendu dicté reçoit un fichier son envoyé par l'utilisateur : sa **menace est écrite avant tout code**. Chaque sortie d'IA est un **brouillon que l'humain relit** : rien n'entre dans le journal ni ne part vers une école sans validation. Quand le modèle ne répond pas, l'écran le dit et le suivi marche sans lui. |
| Quelles données de l'école peut-on envoyer aux modèles externes ? | **Tout, y compris les élèves** : le rapport pour la direction peut citer des élèves et des classes nommées. | Des données de **mineurs** partent chez un tiers : c'est le risque principal du chantier. N'utiliser chez OpenRouter que des fournisseurs qui **ne gardent pas et n'entraînent pas** sur les données, et faire de ce réglage une condition d'appel, pas une option. N'envoyer que ce dont l'usage a besoin : le briefing commercial n'a pas besoin de noms d'élèves, seul le rapport pour la direction en cite. Chaque appel est tracé : qui, quelle école, quel usage, quel fournisseur. La revue sécurité est obligatoire sur ce lot. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- **Konan est enseignant sur Lnclass.** Un compte n'a qu'un rôle et un numéro ne sert qu'à un compte : pour utiliser le suivi, il lui faut un compte équipe distinct, avec un autre numéro. Le porteur doit trancher (second numéro, ou Konan reste hors de l'outil).
- Touré doit recevoir une invitation équipe `field` avant le premier lot démontrable.
- **Intelligence retenue** : les quatre usages sont dans la livraison du 15 novembre (réponse 8), avec l'accès aux modèles par OpenRouter. La clé d'accès et son budget mensuel restent à fournir.
- **Données d'élèves envoyées aux modèles (réponse 9)** : le porteur doit confirmer le cadre légal (protection des données personnelles applicable, information des écoles et des familles) avant la mise en production du rapport pour la direction. Ce n'est pas un blocage pour la démonstration de stage sur des comptes fictifs.
