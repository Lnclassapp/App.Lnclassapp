# Journal — Chercher son établissement en tapant son nom

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-20 | La DRENA n'est plus saisie : la livraison la déduit de l'établissement choisi avant le DTO ; DTO et use cases inchangés | Aucun contrat du domaine ne bouge ; un établissement actif d'une autre DRENA, refusé avant faute d'accord DRENA/école, est désormais accepté | oui (§4.4) |
| 2026-11-20 | Débit : 300 recherches par minute et par adresse, compteur à part de celui des DRENA | 40 élèves × 6 recherches sur un même wifi (CA-6) | oui (§4.3) |
| 2026-11-20 | Sans JavaScript, la saisie part dans un formulaire GET à part (enseignant, rattachement) ou par `formaction` (élève) | Le PIN ne doit jamais finir dans l'adresse | oui (§4.5) |
| 2026-11-20 | Le registre suit le formulaire : « tu » pour l'élève, « vous » pour l'enseignant et le rattachement | Les écrans enseignant vouvoient (UDR-0079) | non (UDR §3) |
| 2026-11-20 | Contrôleur Stimulus `school--drena-schools` supprimé : plus aucune vue ne l'utilise | Code mort | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-20 · recherche-etablissement · **Direction (droits, non réversible)** : l'inscription de la direction garde son code d'établissement ; la remplacer par la recherche ouvrirait la direction de n'importe quelle école à qui la trouve — appliqué : rien ne change pour la direction (hors périmètre) ; autres : recherche puis validation par l'équipe ; recommandé : garder le code
- [ ] 2026-11-20 · recherche-etablissement · Un établissement actif d'une autre DRENA que celle qu'on aurait choisie est accepté (la DRENA est déduite) — appliqué : accepté ; autres : aucun, la DRENA n'est plus saisie ; recommandé : accepté
- [ ] 2026-11-20 · recherche-etablissement · Le résumé replié « établissement + Changer » de « Choisis ta classe » disparaît : l'établissement de la dernière classe s'affiche coché, seul, sous le champ, et une nouvelle saisie le remplace — appliqué : coché sous le champ ; autres : garder le résumé et « Changer » ; recommandé : coché sous le champ (un seul composant)
- [ ] 2026-11-20 · recherche-etablissement · Côté enseignant, le libellé est « Votre établissement » (vouvoiement) au lieu de « Ton établissement » — appliqué : « Votre établissement » ; autres : tutoyer partout ; recommandé : « Votre établissement »

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

- Ruby 3.4.9 introuvable sur le miroir (403) : construit depuis le dépôt git. Une heure perdue avant le premier test.
- 33 tests contrôleur et une dizaine de tests système vérifiaient les deux listes : tous réécrits, aucun n'a été supprimé.
- Revues sur le diff final, trois constats corrigés dans la PR :
  - sécurité : sans JavaScript, « Chercher » de l'inscription élève renvoyait tout le formulaire en GET, code secret compris → formulaire GET distinct `student-signup-school` ;
  - échec silencieux : un établissement devenu inactif avant l'envoi rendait côté enseignant un 422 sans message (seule l'erreur de DRENA, sans champ) → la DRENA vient toujours de l'établissement (jamais du client), et son erreur s'affiche sous le champ avec le message neutre ;
  - Entrée ou erreur réseau après un choix laissaient niveaux et classes de l'ancien établissement → `release()` aussi dans `now()` et `missing()`.
- Les tests contrôleur envoyaient encore une DRENA valide : ils prouvaient le refus neutre dans un cas que le vrai formulaire ne produit plus. Les aides de test n'envoient plus de DRENA.
- L'aide promettait « ou ta ville » : la ville n'est pas dans les données. Remplacé par « ou de ta DRENA », que la recherche couvre.

## Ce qu'on a appris sur la codebase

- Les index pg_trgm de `schools.name` et `schools.sigle` portent sur `translate(lower(col), …)` : la recherche réutilise exactement cette expression, sinon l'index n'est pas pris.
- Nokogiri ne comprend pas `:not(:checked)` dans `assert_select` : écrire `:not([checked])`.
- Le DTO garde son erreur `drena_public_id: blank` quand l'établissement est vide ou inconnu ; aucun champ ne l'affiche, mais l'erreur de l'établissement l'accompagne toujours.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rendu HTML de `/drenas/:id/schools` (frames « schools » et « picker_schools ») plus utilisé par aucun écran | La route sert encore en JSON (API v1) ; retirer le HTML change un contrat public | à ouvrir (`/refactor`) |
| Clés I18n `drena_public_id` des DTO enseignant et rattachement, jamais affichées | Le domaine valide toujours la DRENA | même chantier |
| Sans JavaScript, le « Continuer » de la cascade élève (antérieur au chantier) renvoie tout le formulaire en GET, code secret compris s'il a été tapé | Défaut antérieur, hors du sélecteur ; le corriger touche l'entrée de l'inscription élève (`entree-eleve-unifiee`) | à ouvrir (`/bugfix`), proposé en tâche |
| Ville de l'établissement dans les résultats | Donnée absente de l'import des écoles | hors périmètre (memo) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-20 |
| **PR** | #665 |
| **ADR produits** | ADR-0142 |
| **UDR produits** | UDR-0177 |
