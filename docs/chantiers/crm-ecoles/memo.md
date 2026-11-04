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

## Cas limites identifiés

- …

## Questions encore ouvertes

- **Konan est enseignant sur Lnclass.** Un compte n'a qu'un rôle et un numéro ne sert qu'à un compte : pour utiliser le suivi, il lui faut un compte équipe distinct, avec un autre numéro. Le porteur doit trancher (second numéro, ou Konan reste hors de l'outil).
- Touré doit recevoir une invitation équipe `field` avant le premier lot démontrable.
