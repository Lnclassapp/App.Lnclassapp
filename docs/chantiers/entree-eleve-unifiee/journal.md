# Journal — Une seule entrée pour l'élève : numéro et code secret

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-20 | Débit de l'entrée 120/min (et non 60) et 600/h par adresse ; inscription qui suit : son compteur, 60/min | Un nouvel élève envoie deux fois à l'entrée ; 40 élèves sur un wifi en une minute = 80 envois | Oui, ADR-0141 §4.2 |
| 2026-11-20 | Numéro et code gardés en session chiffrée 30 min, plus de champ code dans l'inscription | Ni dans l'adresse, ni dans la page ; survit au repli GET sans JS | Oui, ADR-0141 §4.3 |
| 2026-11-21 | Code secret : exactement 4 chiffres, aussi dans le navigateur (`pattern`, `minlength`) | Demande du porteur en cours de session | Non (règle existante `Pin::FORMAT`) |
| 2026-11-21 | Compteur des codes faux à l'entrée, 10/min par adresse | Revue sécurité : 120/min sur tout rôle contournait le débit de /login | Oui, ADR-0141 §4.2 |
| 2026-11-21 | `data-turbo-prefetch="false"` sur les liens GET qui changent l'entrée | Turbo préchargeait « Ce n'est pas mon numéro » au survol et effaçait l'entrée | UDR §3.5, §3.6 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-21 · entree-eleve-unifiee · `/student-signup` direct (pages d'établissement) garde ses trois étapes et « Déjà un compte ? » — appliqué : inchangé ; autres : le faire passer aussi par l'entrée ; recommandé : le faire passer par l'entrée dans une retouche, après `recherche-etablissement` → tranché par l'orchestrateur, 2026-11-21 : inchangé
- [x] 2026-11-21 · entree-eleve-unifiee · Invitation enseignant `/i/<jeton>` et inscription direction sans la question « Êtes-vous bien enseignant(e) ? » — appliqué : sans question ; autres : la poser partout ; recommandé : sans question (le lien vise déjà un enseignant) → tranché par l'orchestrateur, 2026-11-21 : sans question
- [x] 2026-11-21 · entree-eleve-unifiee · « Je suis élève » sur l'accueil : un lien vers une page, plus une fenêtre — appliqué : page ; autres : formulaire dans la fenêtre ; recommandé : page (survit au 422 et au retour arrière) → tranché par l'orchestrateur, 2026-11-21 : page
- [x] 2026-11-21 · entree-eleve-unifiee · Question enseignant : « Oui » primaire en premier, « Non, je suis élève » secondaire dessous — appliqué : cet ordre ; autres : inverser ; recommandé : cet ordre → tranché par l'orchestrateur, 2026-11-21 : cet ordre
- [x] 2026-11-21 · entree-eleve-unifiee · Sur `/c/<jeton>`, pas de focus automatique sur le numéro (convention FU-19) — appliqué : pas de focus ; autres : focus sur le numéro ; recommandé : pas de focus (le clavier cacherait la classe) → tranché par l'orchestrateur, 2026-11-21 : pas de focus
- [x] 2026-11-21 · entree-eleve-unifiee · Plafond horaire 600 entrées/heure par adresse — appliqué : 600 ; autres : 1 200 ; recommandé : 600, à relever si la mesure montre une école bloquée → tranché par l'orchestrateur, 2026-11-21 : 600

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Ruby 3.4.9 absent du conteneur et `cache.ruby-lang.org` refusé (403) : compilé depuis l'étiquette `v3_4_9` du dépôt GitHub `ruby/ruby` (choix du porteur), avec Ruby 3.3.6 comme `baseruby`.
- Partager le compteur de l'entrée avec l'inscription aurait bloqué une classe (trois envois par nouvel élève) : compteurs séparés.
- « Ce n'est pas ta classe ? » en mode entrée bouclait vers le lien gardé : `other_classroom=1` oublie le lien.
- La première correction (form_input sans entry_mode) laissait le débit large de l'entrée : un envoi sans entry_mode échappait aux 5 par minute ; débit et fusion suivent désormais la même condition (entry_send? exige entry_mode).
- Un test système perdait l'entrée sans raison visible : préchargement Turbo au survol d'un lien GET qui la remet à zéro.
- Boucle de redirections : entrée confirmée par un lien, puis lien changé ou classe archivée. `/c/<jeton>` renvoyait à `/student-signup`, qui renvoyait à `/c/<jeton>` (jeton gardé dans l'entrée). Corrigé : un lien invalide pour un visiteur est oublié de l'entrée (numéro, code et confirmation gardés).
- Session coupée par la limite de 5 h ; reprise sur l'arbre de travail intact.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Turbo 8 précharge les liens au survol : tout GET qui modifie la session doit porter `data-turbo-prefetch="false"`.
- `start_session` appelle `reset_session` : l'entrée s'efface d'elle-même à la connexion et à la création du compte.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `/student-signup` direct encore en trois étapes | Fichiers partagés avec `recherche-etablissement` | À trancher (journal) |
| Mesure des 429 de l'entrée par école | Pas de tableau de bord des débits | `docs/workflows/mesure.md` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-21 |
| **PR** | |
| **ADR produits** | ADR-0141 |
| **UDR produits** | UDR-0176 |
