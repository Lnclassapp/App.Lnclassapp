# Journal — Connexion et inscription « numéro d'abord »

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-26 | Correction du porteur (relayée par l'orchestrateur) : pas de code d'établissement dans l'inscription enseignant | L'inscription enseignant n'en avait déjà pas : la voie « établissement choisi dans la liste » est la seule ; aucun droit ne change (ADR-0044 et ADR-0077 ne portent que sur la direction) | non |
| 2026-11-26 | Le numéro d'une invitation acceptée devient l'entrée gardée (30 min) et ouvre l'étape du code ; la clé d'invitation sert toujours une fois | L'étape du code a besoin du numéro côté serveur ; même durée que l'entrée élève (ADR-0141 §4.3) ; « Ce n'est pas mon numéro » l'efface | non |
| 2026-11-26 | Un envoi groupé (numéro + code) refusé réaffiche numéro et code ensemble (`@stage = :both`) | Coques et gestionnaires de mots de passe ; garde le message unique d'ADR-0050 | ADR-0148 §4.5 |
| 2026-11-26 | `EnterAsStudent` devient `EnterByNumber`, utilisé par `/login` et `/student` | Un seul use case pour « le numéro décide de la suite » | ADR-0148 §6 |
| 2026-11-26 | Lot C : le numéro repris de `/login` est relu dans l'entrée gardée par le serveur, jamais dans un champ caché ; l'inscription réussie l'efface | Le numéro ne voyage pas dans la page ; une entrée expirée rouvre l'étape 1 avec « Saisissez votre numéro » | UDR-0189 §3.5 |
| 2026-11-26 | Lot C : seul un numéro **sans** compte est repris par l'inscription enseignant | Un numéro inscrit gardé par `/login` (étape du code) ne doit pas pré-remplir une inscription | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-26 · connexion-numero-d-abord · Inscription enseignant ouverte directement : le numéro de l'étape 1 est-il vérifié tout de suite ? — appliqué : non, un numéro déjà inscrit est refusé à l'envoi final (« Ce numéro est déjà utilisé », étape 1) ; autres : envoi du numéro au serveur dès l'étape 1, comme `/login` ; recommandé : appliqué (les enseignants arrivent surtout par `/login`, qui vérifie) — porteur, 2026-11-27 : validé (option appliquée).
- [x] 2026-11-26 · connexion-numero-d-abord · Libellé de l'étape 2 enseignant — appliqué : « Entrez votre code secret » (vouvoiement de l'enseignant) ; autres : « Entre ton code secret » mot pour mot ; recommandé : appliqué — porteur, 2026-11-27 : validé (option appliquée).
- [x] 2026-11-26 · connexion-numero-d-abord · Inscription enseignant sans JavaScript : la recherche d'établissement (formulaire GET à part) est maintenant à l'étape 3, après numéro et code, qu'elle ne garde pas — appliqué : on cherche d'abord (test sans JavaScript dans cet ordre), rien d'autre ne change ; autres : remonter la recherche en tête de la page sans JavaScript ; recommandé : appliqué (le parcours sans JavaScript est rare, aucun envoi n'est perdu, seuls les champs déjà tapés) — porteur, 2026-11-27 : validé (option appliquée).
- [x] 2026-11-26 · connexion-numero-d-abord · L'étape code de `/student` (numéro inscrit) utilise-t-elle le pavé ? — appliqué : non, champ simple comme `/login` (le pavé reste à la création) ; autres : le pavé partout ; recommandé : appliqué — porteur, 2026-11-27 : validé (option appliquée). **Revu le 2026-11-27 par le porteur, après test sur Develop : le pavé de 4 cases partout où l'on tape un code (UDR-0189 §3.6).**
- [x] 2026-11-26 · connexion-numero-d-abord · Appareil partagé : le numéro tapé reste à l'étape du code 30 minutes (revue sécurité, gravité basse) — appliqué : gardé 30 minutes, écrit en coût consenti dans l'ADR (comme `/student`, ADR-0141 §4.3) ; autres : revenir à l'écran du numéro après quelques minutes sans code ; recommandé : appliqué — porteur, 2026-11-27 : validé (option appliquée).

- [ ] 2026-11-27 · entree-enseignant-chiffres · Les 4 cases s'étendent-elles aux formulaires à code + confirmation (inscription élève sans entrée, invitation enseignant ou direction, inscription direction), au code oublié et au changement de code ? — appliqué : non, ils gardent leurs deux champs (chiffres seuls, §3.7) ; autres : pavé partout, la confirmation retirée ; recommandé : appliqué tant qu'une règle de confirmation y vaut.
- [ ] 2026-11-27 · entree-enseignant-chiffres · La promesse « assigner des exercices » partait avec la fenêtre « Vous êtes enseignant ? » — appliqué : elle reste sur l'inscription enseignant (« Assignez un exercice… ») ; autres : une ligne sous le bouton « Enseignant(e) » de l'accueil ; recommandé : appliqué (l'accueil tient sur un écran).
- [ ] 2026-11-27 · entree-enseignant-chiffres · Avec le pavé, un gestionnaire de mots de passe ne remplit plus le code à la connexion (le champ natif est caché) — appliqué : accepté ; autres : garder le champ natif visible sous le pavé ; recommandé : appliqué (demande du porteur, public téléphone).

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- 2026-11-27 · retouche/entree-enseignant-chiffres · `/teacher` (numéro d'abord) remplace la fenêtre « Vous êtes enseignant ? » ; chiffres seuls dans les numéros et codes ; le code en 4 cases à la connexion, à l'entrée élève et à l'inscription enseignant (UDR-0189 §3.6 à §3.8).

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- `bin/ci-quiet` lancé au premier plan : coupé à 10 minutes (exit 143), une demi-heure perdue. Toujours en arrière-plan.
- `test/integration/pin_reveal_fields_test.rb` lisait l'ancien `/login` (code sur la première page) : vu seulement par la CI complète ; chercher `session[pin]` et `pin_confirmation` dans tout `test/` avant de retirer un champ.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Messages d'expiration imprécis : numéro enseignant échu pendant le profil (retour à l'étape 1, « obligatoire ») ; « expiré » sur un code envoyé après « pas de compte » dans un autre onglet | Revue silent-failure-hunter, gravité basse, l'échec reste visible | à ouvrir |
| `WrongPinLimit` (hors diff) : cache qui rend nil = plafond ouvert sans trace ; place non rendue après une exception | Hors périmètre du chantier | à ouvrir |
| Tests : doubles du domaine qui ignorent `contact`/`kind` (`enter_by_number_test.rb`), pas de test dédié de `NumberEntryInput`, CA-3 et CA-13 testés jusqu'à la redirection | Revue pr-test-analyzer, lacunes faibles | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
