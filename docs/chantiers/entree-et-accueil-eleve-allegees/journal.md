# Journal — Entrée et accueil de l'élève allégés

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | Le premier code n'est jamais dans la page : au 4e chiffre, envoi automatique, le serveur compare | 4 chiffres (ou leur empreinte) dans la page se retrouvent en 10 000 essais | UDR pavé §2.3 |
| 2026-11-21 | L'adresse du QR réutilise l'identifiant public de l'établissement et passe par l'entrée élève | Aucun identifiant nouveau ; la recherche publique liste déjà ces identifiants | ADR adresse-publique-etablissement |
| 2026-11-21 | La fenêtre du premier exercice est un cadre différé du shell, éteint par un drapeau de session | Ne pas payer la requête de l'accueil sur chaque écran | UDR accueil §2 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Arrivée sur `/student-signup` sans passer par l'entrée (accueil public, page d'un cours, `/join`) : le numéro n'y est pas connu — appliqué : on garde les trois étapes, numéro et code demandés ; autres : rediriger `/student-signup` vers `/student` (entrée unique) ; recommandé : rediriger vers l'entrée, dans un chantier suivant (tests système de l'inscription à reprendre)
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · « Fait son premier exercice », qui éteint la fenêtre : commencé, rendu, réussi ? — appliqué : une copie rendue, quelle que soit la note ; autres : réussie (10/20, ancienne règle de la carte) ; commencée ; recommandé : rendue
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Fréquence de la fenêtre après fermeture — appliqué : une fois par écran chargé (elle revient au chargement suivant, jamais deux fois sur le même) ; autres : une fois par session ; une fois par jour ; recommandé : une fois par écran chargé (précision du porteur)
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · La tuile « Inviter » et la bannière « Invite tes camarades » en bas d'accueil — appliqué : la tuile remplace la bannière (une porte par action) ; autres : garder les deux ; recommandé : la tuile seule
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · L'invitation à installer l'application et la fenêtre du premier exercice sur l'accueil — appliqué : l'invitation attend tant que la fenêtre peut s'ouvrir ; autres : les deux ; recommandé : l'invitation attend
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Le QR : simple image, ou agrandi au toucher — appliqué : image de 96 px, sans agrandissement ; autres : toucher pour l'agrandir en plein écran ; recommandé : image seule, agrandir si la recette montre que les téléphones peinent à le lire
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Les inscriptions par le QR de l'établissement comptent comme « standard » dans l'attribution (ADR-0143) — appliqué : « standard » ; autres : une étiquette `school_qr` ; recommandé : une étiquette, dans un chantier suivant

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot A) · Où montrer « Les deux codes sont différents. » quand le champ natif est caché — appliqué : un bloc `#student-entry-mismatch` (`role=alert`) rendu `hidden` au-dessus du champ, dévoilé par le contrôleur du pavé ; sans JavaScript, le message reste sous le champ (une seule occurrence visible dans chaque cas) ; autres : déplacer le message dans `base_errors` pour tous les cas ; recommandé : l'appliqué
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot A) · Fichiers hors fiche du Lot A modifiés pour ne pas casser des tests existants : `test/support/student_entry_helper.rb` (la confirmation se tape au pavé) et `test/system/identity/pin_reveal_test.rb` (plus de révélation du champ de confirmation) — appliqué : modification minimale de ces deux lignes ; le Lot B reprend la dernière ligne du helper (`#signup-entry-number`) : conflit de fusion à résoudre à la main ; recommandé : l'appliqué

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : les tests système (Chrome 153 installé, chromedriver 147 seul disponible, téléchargement d'un autre refusé) n'ont pas pu tourner dans l'environnement du lot ; ils sont écrits mais à jouer par le vérificateur (`test/system/student_entry_pin_pad_test.rb`, tous les tests système qui passent par `pass_student_entry`).

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
