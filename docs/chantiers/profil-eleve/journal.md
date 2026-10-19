# Journal — Profil de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | `ProfileQuery#school_name` existe déjà ; il est seulement rempli pour l'élève | Non |
| 2026-10-15 | « Se déconnecter » sans confirmation | Même action que le menu du compte, qui n'en demande pas | Non |
| 2026-10-15 | Option `placement: :phone_sheet` et taille `:form` (480 px) de `ui_modal` | `:sheet` (UDR-0061) bascule à 1 024 px, l'UDR-0089 à 700 px ; pas de nouveau composant | Non (UDR-0089 §3.4 précisée) |
| 2026-10-15 | Nom accessible des lignes : « %{action} %{libellé}, %{valeur} » | « Modifier » sur une ligne qui affiche « Changer » trahirait le texte visible (WCAG 2.5.3) | Non (UDR-0089 §3.7 précisée) |
| 2026-10-15 | Page de l'élève dans ses propres partiels (`_student*`) | Le profil des autres rôles reste octet pour octet ; `_information` perd ses branches élève | Non |
| 2026-10-15 | Le changement de nom remplace aussi la carte bleue | Le nom y est écrit ; sinon il resterait l'ancien jusqu'au rechargement | Non |

## Ce qui a dérapé

- Durée du test système : la machine de l'agent est environ deux fois plus lente que celle des durées enregistrées (`profile_pin_test` : 12,8 s contre 6,6 s). Mesurés sur la même machine, l'ancien et le nouveau `profile_test.rb` font environ 19 s et 24 s (+27 %) ; la durée enregistrée est donc 6,9 × 1,27 ≈ 8,8 s, et non les 17,0 s bruts, qui auraient fait déborder le budget de 15 s (ADR-0069 §9) avec la croissance déjà portée par `accueil-eleve`.
- Le sous-agent `pr-test-analyzer` n'a pas tourné : la session d'exécution n'avait pas d'outil pour lancer un sous-agent. À faire sur le diff final avant la PR (≈ 530 lignes, use case non touché).

## Ce qu'on a appris sur la codebase

- `ProfileQuery#school_name` n'était rempli que pour l'enseignant et la direction : un élève l'avait toujours à nil.
- Les quatre fenêtres du profil passent par le cadre `modal` du layout, avec `ui_modal ... open: true`.
- Sous 640 px, une `ui_card` de premier niveau va bord à bord (UDR-0005, amendement du 2026-10-06) : les cartes du profil perdent leurs coins au téléphone, comme celles de l'accueil ; la maquette les montre arrondies.
- `profile_names/update` remplace des cartes par leur id : toute carte qui affiche le nom doit y être ajoutée.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Profil de l'enseignant au même style | Hors périmètre | — |
| Fenêtre de la photo de la maquette (bouton « Choisir une photo », « Retirer ma photo » en lien rouge, boutons bleus empilés) | UDR-0089 §3.4 : contenu des fenêtres inchangé | — |
| Pastille appareil photo sur l'avatar de la carte bleue (maquette) | UDR-0089 §3.1 : pas de bouton dans la carte, le « + » d'UDR-0084 suffit | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15, fusionné dans `Develop` |
| **PR** | [#243](https://github.com/Lnclassapp/App.Lnclassapp/pull/243) |
| **ADR produits** | — |
| **UDR produits** | UDR-0089 |
| **CI locale** (`bin/ci-quiet`, 2026-10-15, sur `e5019bdc` + docs) | Rouge, sans échec dans le périmètre du chantier. Couverture 13 604 / 13 605 lignes : la ligne manquante est dans `daily_exercise_query.rb` (lot 0 d'`accueil-eleve`). Un test de durée (`image_header_test.rb:516`, 0,75 s pour 0,5 s) a échoué sous charge, vert relancé seul. Système : échecs connus de `Develop` (`sign_in_test.rb:114`, `team_invitation_test.rb:62`, `public_pages_test.rb:89/:100`, même famille : `staff_invitation_test.rb:50`, numéro non mis en forme à la connexion) ; six autres fichiers rouges sous charge, tous verts relancés seuls. Tous les tests du profil, des fenêtres et du menu du compte sont verts. |
