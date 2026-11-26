# Journal — Connexion et inscription « numéro d'abord »

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-26 | Correction du porteur (relayée par l'orchestrateur) : pas de code d'établissement dans l'inscription enseignant | L'inscription enseignant n'en avait déjà pas : la voie « établissement choisi dans la liste » est la seule ; aucun droit ne change (ADR-0044 et ADR-0077 ne portent que sur la direction) | non |
| 2026-11-26 | Le numéro d'une invitation acceptée devient l'entrée gardée (30 min) et ouvre l'étape du code ; la clé d'invitation sert toujours une fois | L'étape du code a besoin du numéro côté serveur ; même durée que l'entrée élève (ADR-0141 §4.3) ; « Ce n'est pas mon numéro » l'efface | non |
| 2026-11-26 | Un envoi groupé (numéro + code) refusé réaffiche numéro et code ensemble (`@stage = :both`) | Coques et gestionnaires de mots de passe ; garde le message unique d'ADR-0050 | ADR-XXXX §4.5 |
| 2026-11-26 | `EnterAsStudent` devient `EnterByNumber`, utilisé par `/login` et `/student` | Un seul use case pour « le numéro décide de la suite » | ADR-XXXX §6 |
| 2026-11-26 | Lot C : le numéro repris de `/login` est relu dans l'entrée gardée par le serveur, jamais dans un champ caché ; l'inscription réussie l'efface | Le numéro ne voyage pas dans la page ; une entrée expirée rouvre l'étape 1 avec « Saisissez votre numéro » | UDR-XXXX §3.5 |
| 2026-11-26 | Lot C : seul un numéro **sans** compte est repris par l'inscription enseignant | Un numéro inscrit gardé par `/login` (étape du code) ne doit pas pré-remplir une inscription | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-26 · connexion-numero-d-abord · Inscription enseignant ouverte directement : le numéro de l'étape 1 est-il vérifié tout de suite ? — appliqué : non, un numéro déjà inscrit est refusé à l'envoi final (« Ce numéro est déjà utilisé », étape 1) ; autres : envoi du numéro au serveur dès l'étape 1, comme `/login` ; recommandé : appliqué (les enseignants arrivent surtout par `/login`, qui vérifie)
- [ ] 2026-11-26 · connexion-numero-d-abord · Libellé de l'étape 2 enseignant — appliqué : « Entrez votre code secret » (vouvoiement de l'enseignant) ; autres : « Entre ton code secret » mot pour mot ; recommandé : appliqué
- [ ] 2026-11-26 · connexion-numero-d-abord · Inscription enseignant sans JavaScript : la recherche d'établissement (formulaire GET à part) est maintenant à l'étape 3, après numéro et code, qu'elle ne garde pas — appliqué : on cherche d'abord (test sans JavaScript dans cet ordre), rien d'autre ne change ; autres : remonter la recherche en tête de la page sans JavaScript ; recommandé : appliqué (le parcours sans JavaScript est rare, aucun envoi n'est perdu, seuls les champs déjà tapés)
- [ ] 2026-11-26 · connexion-numero-d-abord · L'étape code de `/student` (numéro inscrit) utilise-t-elle le pavé ? — appliqué : non, champ simple comme `/login` (le pavé reste à la création) ; autres : le pavé partout ; recommandé : appliqué

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
