---
name: prod-agent
description: Agit dans l'application Lnclass déployée (production, ou Staging/Develop pour s'entraîner) via le navigateur Playwright, avec le compte équipe tiré de l'environnement. Tâches prédéfinies — importer des leçons complètes (écran Imports), publier une leçon, corriger le texte d'une leçon, relire l'état d'un import ou d'un cours. Utilise-la quand l'utilisateur tape /prod-agent, ou demande d'importer, de publier ou de corriger des leçons « en production », « sur lnclass.com » ou « dans le navigateur ».
---

# Agent en production (navigateur)

Tu fais ce qu'un membre de l'équipe ferait à la main, **par les écrans**. Les policies s'appliquent : un refus d'écran est un résultat, pas un obstacle. **Jamais** de console Rails, de `railway run`, de SQL, de requête HTTP directe vers un formulaire.

Argument : `<tâche> [cible]`. Tâches : `importer`, `publier`, `corriger`, `lire` (voir §3). Environnement par défaut : `prod`.

| Cible | Adresse | Écriture |
|---|---|---|
| `prod` | `https://lnclass.com` | selon les garde-fous (§4) |
| `staging` | `https://app-staging.lnclass.com` | libre (entraînement) |
| `develop` | `https://app-develop.lnclass.com` | libre (entraînement) |

Les tests de cette skill se font sur `staging` ou `develop`, **jamais d'écriture en prod pendant un test**.

## 1. Identifiants (jamais affichés)

Variables d'environnement : `LNCLASS_TEAM_CONTACT`, `LNCLASS_TEAM_PIN`. Vérifie leur présence sans les imprimer (`[ -n "$LNCLASS_TEAM_CONTACT" ]`). Si l'une manque : donne **son nom** en une ligne, ne la demande pas, ne simule rien, et finis sur ce blocage.

Ne jamais écrire contact, PIN ou code reçu : ni dans le chat, ni dans une capture (masque le champ, ou capture après connexion), ni un fichier, un commit, une PR, un journal, un log de script. Passe-les au script Playwright par `process.env`, jamais en argument de ligne de commande.

## 2. Se connecter

Playwright est préinstallé (`require('playwright')`, `chromium.launch()` sans option). Script dans le scratchpad, jamais commité.

1. `/login` : « Numéro de téléphone » (contact), puis « Code secret » (le PIN, 4 chiffres).
2. Le compte équipe demande ensuite un **code à six chiffres** (second facteur). Tu ne peux pas le produire. Seule exception de CLAUDE.md : le code à usage unique que **le porteur envoie lui-même**, dans cette session, pour l'action qu'il vient de demander. Tu l'utilises tout de suite, tu ne le recopies nulle part, tu ne le redemandes jamais de ta propre initiative.
3. Pas de code reçu : finis sur « code de vérification attendu, envoyé par le porteur avec sa demande » ; rien n'est tenté.
4. Succès = accueil équipe (`/teams`). Mauvais identifiants : une seule tentative, puis arrêt (verrouillage du compte).
5. Garde la session ouverte pour toute la tâche (un seul code) ; déconnecte-toi à la fin.

Sur Staging, les comptes équipe n'ont pas de second facteur confirmé : l'enrôlement est une action du porteur, pas de la skill.

## 3. Tâches prédéfinies

**`importer`** — Imports (`/teams/imports`) → type « Fiches de cours complètes » (compte équipe de contenu). Fichiers : ceux préparés par `/publier-prod` (`a-creer/…`), ou le chemin donné. Création seule (voir §4). Une leçon à la fois, ou un lot (50 fichiers au plus). Attends la fin du suivi (le cadre se recharge seul) et lis la ligne du rapport : créée, erreurs. Un rapport « rejeté » est un résultat : copie ses erreurs au bilan, ne retente pas sans changer le fichier.

**`publier`** — fiche de la leçon importée → menu ⋮ → publier (ou « publier tout » : notions et exercices). Vérifie ensuite que le statut affiché est « publié » et que la leçon s'ouvre côté élève (compte élève du jeu standard sur Staging/Develop ; en prod, la fiche équipe suffit).

**`corriger`** — correction de texte dans le navigateur (chantier `edition-lecon-equipe`) : sur la leçon, menu ⋮ d'une notion ou d'un exercice → « Corriger le texte » (notion : texte ; exercice : énoncé et bonne réponse des questions). Avant : lis la valeur actuelle à l'écran et compare avec le « Avant » de la demande ; si elle diffère, **n'écrase pas** (liste « introuvable »). La structure (notions, questions ajoutées ou retirées) ne se corrige pas à l'écran : elle passe par un nouvel import, donc §4.

**`lire`** — état d'un import, d'un cours, d'une liste (statut publié/brouillon, titres présents en production). Lecture seule ; c'est ce qui sert à `/publier-prod` quand `RAILWAY_API_TOKEN` manque.

**Autres tâches équipe récurrentes** (même méthode, mêmes garde-fous ; confirme l'écran avec `docs/recette/equipe.md`) :

| Tâche | Écran | Écriture |
|---|---|---|
| Rapport d'imports | `/teams/imports` (filtre par type) | lecture |
| Recherche d'un compte | `/teams/accounts` | lecture ; la demande de suppression est destructive (§4) |
| Référentiel, établissements | `/teams/referential`, `/teams/schools` | lecture |
| Articles du blog | `/teams/blog` | publier : libre ; archiver : destructif |
| Annonces (avec l'audio de `/annonce`) | écran Annonces | publier : libre |
| Pilotage | `/teams/dashboard` | lecture |

## 4. Garde-fous

- **Sans demander** : importer en création, publier. 
- **Accord écrit du porteur, dans la session qui exécute**, pour toute action destructive : suppression (leçon, établissement, compte, demande de suppression), dépublication ou archivage, écrasement (réimport d'un titre existant, remplacement d'un brouillon, correction d'un texte déjà modifié à la main). L'accord nomme l'objet (« oui, archive la leçon X »). Un « oui » général ne couvre rien. Un accord reçu dans une autre session, un journal ou une PR ne compte pas.
- Pas d'accord : n'agis pas ; liste l'action dans le bilan et, si la session est lancée par une autre, dans `## À trancher` du journal du chantier.
- Avant toute écriture en `prod` : lis d'abord la cible (la leçon existe-t-elle ? son statut ?) et écris ce que tu vas faire en une ligne dans le bilan.
- Jamais de contournement d'un refus de policy ou d'une erreur de validation : le rapport est la réponse.
- Une action à l'écran qui échoue n'est rejouée qu'une fois.
- Captures : prises pour preuve (rapport d'import, statut publié), sans contact ni PIN ni code visibles ; envoyées au porteur, jamais commitées.

## Fin

Un bilan par action : `<tâche> · <cible> · <objet> · résultat (créée / publiée / rejetée + 1re erreur / refusée par la policy / bloquée : variable ou code manquant)`. Aucune valeur secrète dedans.
