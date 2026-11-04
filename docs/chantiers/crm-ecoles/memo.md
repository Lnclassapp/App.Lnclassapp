# Memo — CRM des écoles

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
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
- Le revenu et l'abonnement : rien n'existe encore dans la base pour les suivre. « Abonnée » est une étape saisie, pas un paiement.
- Le rapport pédagogique est préparé par l'équipe et partagé par elle : la direction n'a pas d'accès nouveau dans l'application.
- Toute action d'un modèle sans validation humaine : les modèles proposent, un membre de l'équipe enregistre ou envoie.
- La modification ou la suppression d'un échange noté.
- La mise en sommeil (« snooze ») d'une école à relancer.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui démarche les écoles et utilisera le suivi ? | Le porteur, Touré, Konan, puis les futures recrues de l'équipe. | Le suivi est multi-utilisateur : chaque école a un **responsable**, chaque relance a un destinataire, « Mes relances » a un sens. Le changement de responsable (départ, réorganisation) est un parcours à part entière. Un responsable dont le compte est retiré ne doit pas laisser ses écoles orphelines en silence. |
| Qu'est-ce qui rend l'outil « intelligent » en V1 ? | Une règle calculée, sans IA générative : chaque jour, l'outil propose les écoles à relancer d'après leur usage réel. Les agents IA (Kimi, DeepSeek ou Gemini) viendront après. | Une liste « à relancer » calculée entre dans le périmètre (environ 1 jour, pris sur la marge). Le journal des échanges doit être **structuré dès la V1** (type d'échange, interlocuteur, résultat, motif en cas de perte, note libre) : c'est la matière première des futurs agents. |
| Les étapes « Inscrite » et « Active » sont-elles saisies ou calculées ? | Mélange validé : **Inscrite** (au moins un compte rattaché à l'école) et **Active** (activité dans les 14 derniers jours) sont calculées d'après l'usage réel ; **Prospect, Démo faite, Abonnée, Perdue** sont saisies à la main. | L'étape affichée n'est pas une simple colonne : elle combine une étape saisie et l'usage lu dans l'app. Il faut fixer laquelle l'emporte (une école « Perdue » qui se remet à servir, une école « Abonnée » devenue inactive). Personne ne peut marquer « Active » une école sans usage. |
| Quelles fonctions IA, et quand ? | Les quatre (compte rendu dicté, fiche de briefing, rapport pédagogique, brouillon de relance WhatsApp), dans ce chantier, par OpenRouter. Le porteur estime le tout à 72 h avec des lots parallèles codés avec Claude. | Les IA forment une vague de lots à part, après un socle IA. **Ordre de coupe** si le délai glisse : compte rendu dicté d'abord, puis rapport pédagogique ; la fiche de briefing ne se coupe pas (c'est elle qui justifie « Lnclass Intelligent »). |
| Quelle étape l'emporte quand la saisie et l'usage se contredisent ? *(proposé par le cadrage, à contester)* | Abonnée (saisie) l'emporte toujours ; sinon Active (usage) ; sinon Perdue (saisie) ; sinon Inscrite (usage) ; sinon Démo faite (saisie) ; sinon Prospect. | Une école perdue qui se remet à servir réapparaît « Active » sans geste de l'équipe. Une école abonnée inactive reste « Abonnée » mais entre dans « À relancer ». L'étape affichée se calcule à la lecture, elle n'est jamais stockée. |
| Que veut dire « à relancer » ? *(proposé par le cadrage, à contester)* | Quatre signaux : relance échue ; perte d'usage (activité dans les 60 derniers jours, aucune dans les 14 derniers) ; démo sans suite (aucun échange depuis 7 jours) ; inscrite sans démarrage (comptes rattachés depuis plus de 14 jours, jamais d'activité). | Chaque école de la liste dit **pourquoi** elle y est. Les écoles perdues sans usage n'y entrent pas. |
| Peut-on corriger un échange noté ? *(proposé par le cadrage, à contester)* | Non en V1 : le journal est en ajout seul. Une erreur se corrige par un nouvel échange. | Pas de parcours de modification ni de suppression, moins de surface. |

## Cas limites identifiés

- Aucune école suivie, aucun échange, aucune relance : chaque bloc a son état vide.
- Une école n'a encore jamais été touchée par le suivi : elle est « Prospect », sans responsable, sans que rien n'ait été écrit pour elle.
- Le responsable quitte l'équipe (compte anonymisé) ou change de sous-rôle pour `content` : l'école apparaît « sans responsable » ; ses relances ouvertes restent visibles des `admin`, marquées « destinataire indisponible ».
- Un contact est retiré alors que des échanges le citent : les échanges gardent son nom.
- Une école est supprimée par l'équipe : tout son suivi disparaît avec elle.
- Une école désactivée : son suivi reste lisible et modifiable, elle n'entre jamais dans « À relancer ».
- Un enseignant rattaché à deux écoles compte dans l'usage des deux.
- Deux membres changent l'étape en même temps : la dernière écriture gagne, les deux sont journalisées.
- Marquer « Perdue » sans motif : refusé.
- Le service de modèles est indisponible, lent ou non configuré : l'outil dit que l'assistant est indisponible, le reste du suivi fonctionne.
- Un enregistrement vocal trop long, trop lourd ou dans un format inconnu : refusé avant tout envoi.
- La réponse d'un modèle est inexploitable : le compte rendu dicté retombe sur la transcription brute dans la note, rien n'est enregistré sans validation humaine.
- Une école sans aucune donnée pédagogique : le rapport pour la direction le dit au lieu d'inventer.

## Questions encore ouvertes

- Konan et Touré ont déjà leurs comptes équipe (réponse du porteur, 4 novembre).
- Touré code tous les lots, en 3 jours (jeudi 5 au samedi 7 novembre), avec 3 lots en parallèle au plus et 2 sessions Claude ouvertes au plus. Le test final est fait par Konan, puis par le porteur.
- **Intelligence retenue** : compte rendu dicté, fiche de briefing avant appel, rapport pédagogique pour la direction, brouillon de relance WhatsApp. Accès aux modèles par OpenRouter. Les quatre entrent dans ce chantier (voir le grill).
- Le support de l'audio par OpenRouter pour le modèle choisi est à vérifier au premier lot IA ; s'il manque, le compte rendu dicté passe par un appel de transcription séparé.
- Le nouveau contexte borné `crm` tient dans un seul graphe de lots : on n'ouvre pas de programme (voir l'ADR du contexte).
