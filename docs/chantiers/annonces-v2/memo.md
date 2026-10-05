# Memo — Annonces, deuxième version — saisie guidée, illustrations de l'équipe, trois annonces visibles, thèmes de couleur

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré en PR ([#182](https://github.com/Lnclassapp/App.Lnclassapp/pull/182), 2026-10-05) |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `feature/annonces-v2` |
| **Programme** | `refonte-application`, vague V6 (suite de [`annonces`](../annonces/memo.md), V6a) |

---

## Le problème

Le porteur a utilisé les annonces livrées le 2026-10-04 (PR #162) et en revient avec cinq constats sur la création d'une annonce :

1. **Le titre et le texte** s'arrêtent bien à 60 et 140 caractères, mais rien n'indique combien il en reste : l'auteur découvre la limite en tapant.
2. **Les illustrations** se limitent aux 8 dessins fournis par Lnclass. L'équipe ne peut pas en ajouter.
3. **L'audio** : un fichier `.mp3` enregistré au téléphone a été refusé avec « Ce fichier n'est pas accepté. ». Le fichier est perdu et le chantier de correction ([`annonce-audio-mp3`](../annonce-audio-mp3/memo.md)) a été arrêté, faute de reproduction. Il reste à décider quels enregistrements de téléphone accepter.
4. **La date de fin** (« Visible jusqu'au ») est une saisie de plus, que le porteur ne veut plus. À la place, **un auteur n'a jamais plus de 3 annonces visibles** : publier la 4ᵉ archive automatiquement la plus ancienne.
5. **L'apparence** : toutes les cartes ont la même couleur. Le porteur veut un **thème de couleur par annonce**, comme les cartes de Wave, avec **10 thèmes** au choix.

## Pour qui

- **Les auteurs** (équipe, direction, enseignant), quand ils rédigent une annonce : savoir ce qu'il reste à écrire, choisir une illustration et un thème, joindre un enregistrement fait au téléphone, sans gérer de date de fin.
- **L'équipe**, qui enrichit la bibliothèque d'illustrations.
- **Les lecteurs** (élève surtout), qui voient des cartes plus variées et moins d'annonces anciennes.

## Pourquoi maintenant

Les annonces viennent d'être livrées. Le porteur s'en sert et bute sur ces points dès la création : la saisie est trop lente et l'apparence trop uniforme pour qu'il les montre aux établissements.

## Hors périmètre

- Les autres remarques de la revue de la V6a restent en dette (journal d'`annonces`) :
  - plafond par auteur dans le carrousel ;
  - intitulé « Configuration » de la 2ᵉ carte de l'équipe ;
  - cercle de ▶ en mode sombre.
- Enregistrer sa voix directement dans le navigateur (dette d'`annonces`).
- Les formats audio AMR et OGG/Opus, et toute conversion côté serveur (grill, question 8).
- Des illustrations propres à un établissement : la bibliothèque est commune (grill, question 4).
- Un thème réservé aux annonces officielles (grill, question 7).
- Un thème personnalisé (couleur libre) : les 10 thèmes sont fixés par Lnclass.
- Le rôle `Parent` : il n'existe pas encore dans l'application.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Sans date de fin, une annonce oubliée resterait en ligne des mois : que faire ? | **Durée maximale automatique de 30 jours**, sans champ à saisir ; une 4ᵉ annonce du même auteur fait partir la plus ancienne plus tôt | Le champ « Visible jusqu'au » disparaît du formulaire, mais la date de fin reste enregistrée, calculée : publication + 30 jours. La règle de lecture ne change pas. Il faut amender l'ADR-0078, qui posait une date de fin choisie par l'auteur, 30 jours par défaut et 90 au plus |
| Qui compte comme « une personne » pour le plafond de 3 ? | **Chaque compte** : chaque enseignant, chaque direction, chaque membre de l'équipe | Le plafond se compte par auteur. Un établissement à 3 directions peut afficher 9 annonces de direction. Une annonce n'est jamais archivée par la publication d'un collègue. **Décision par défaut, à confirmer au PRD** : « visible » veut dire publiée et pas encore terminée. Une annonce programmée ne compte qu'à sa parution : c'est à ce moment, dans le job de publication, que la plus ancienne part |
| L'auteur doit-il être prévenu de l'archivage automatique ? | **Oui, dans le formulaire**, au-dessus du bouton : « Tu as déjà 3 annonces en ligne. En publiant, « … » sera archivée. » ; le toast le confirme ensuite | Le formulaire doit connaître l'annonce qui partirait (la plus ancienne en ligne de l'auteur). Il n'y a pas de confirmation en plus. Le toast de publication nomme l'annonce archivée |
| Qu'apportent les illustrations de l'équipe, face à l'image personnelle ? (question reposée à la demande du porteur, même réponse) | **Une bibliothèque partagée** : l'équipe ajoute des illustrations que tous les auteurs de tous les établissements choisissent comme les 8 de base ; l'image personnelle reste possible | La bibliothèque devient une donnée en base gérée par l'équipe, en plus des 8 dessins livrés avec l'application. Il faut une page de gestion pour l'équipe et un stockage des fichiers ajoutés. Une annonce désigne son illustration par une référence stable |
| Sous quelle forme l'équipe ajoute-t-elle une illustration ? | **Un dessin SVG**, qui suit le thème de la carte et le mode sombre comme les 8 de base | Le choix le plus risqué : un SVG peut contenir du code (script, liens externes, `foreignObject`). L'ADR doit fixer un nettoyage par liste blanche (éléments et attributs permis, aucune référence externe), un poids maximal, et un rendu qui n'exécute jamais rien. La façon de suivre le thème (couleur courante, masque) se décide à l'ADR. Une revue de sécurité est obligatoire sur ce lot |
| Que change le thème sur la carte ? | **Toute la carte** : le fond, la couleur du texte et celle de l'illustration, comme les cartes colorées de Wave ; 10 thèmes | L'annonce enregistre son thème. Les 10 thèmes sont des jeux de tokens (fond, texte, illustration), contrastés AA en clair **et** en sombre, et vérifiés par un test. La carte, le carrousel et les listes lisent le thème. Les SVG de l'équipe doivent prendre la couleur du thème |
| Une annonce officielle se distingue-t-elle par la couleur ? | **Non** : la direction choisit son thème comme les autres ; le badge, la signature et l'absence de croix suffisent | Aucun thème n'est réservé, et les 10 sont ouverts à tous les auteurs. Le badge officiel doit rester lisible sur les 10 fonds (contraste vérifié) |
| Quels enregistrements de téléphone l'audio accepte-t-il ? | **MP3 et M4A, toutes variantes** : un MP3 précédé d'octets de remplissage, et tout MP4/3GP en AAC quelle que soit la marque du téléphone. AMR et OGG restent refusés, avec un message qui dit quoi faire | La reconnaissance du format s'élargit, mais les types servis restent `audio/mpeg` et `audio/mp4`. Chaque variante a son fichier de test (un enregistrement réel par marque). Le message de refus change : il dit d'exporter en MP3 ou M4A. Cela reprend le chantier `annonce-audio-mp3`, arrêté faute de fichier |
| Que deviennent les annonces déjà en ligne quand la règle des 3 arrive ? | **Aucun auteur n'a d'annonce aujourd'hui** | Il n'y a pas de données à reprendre ni de migration de rattrapage. La règle s'écrit pour le cas général : à chaque parution, les plus anciennes en ligne de l'auteur partent jusqu'à ce qu'il en reste 3, nouvelle comprise |

## Cas limites identifiés

- Un auteur publie sa 4ᵉ annonce alors que l'une des 3 est **programmée** : seules les annonces en ligne comptent. La programmée ne compte qu'à sa parution, et c'est le job de publication qui fait partir la plus ancienne à ce moment-là.
- Deux publications **simultanées** du même auteur : le compte doit être fait sous verrou, sinon il pourrait garder 4 annonces en ligne.
- L'auteur **archive** lui-même une de ses 3 : il retombe à 2, et la suivante n'archive rien.
- Une annonce **retirée** par l'équipe ou la direction ne compte plus.
- Une annonce **modifiée** (déjà publiée) ne compte pas comme une nouvelle parution : elle n'archive rien.
- L'équipe **retire une illustration** de la bibliothèque alors que des annonces en ligne l'utilisent. Par défaut, à confirmer au PRD : elle disparaît du choix, et les annonces qui l'ont gardent son dessin jusqu'à leur fin.
- Un SVG piégé (script, lien externe, `foreignObject`, entité XML, poids énorme) téléversé par un compte équipe compromis.
- Un titre ou un texte collé de plus de 60 ou 140 caractères : la saisie le coupe, et le décompte doit le montrer à 0.
- Un enregistrement M4A d'une marque inconnue, ou un MP3 dont la première trame est loin du début.

## Questions encore ouvertes

- ~~Le compteur affiche-t-il « 12 / 60 » ou « 48 restants » ?~~ « 18 / 60 », comme le résumé d'article (UDR-0067), tranché par l'UDR-0075.
- ~~La durée maximale reste-t-elle de 30 jours pour toutes les annonces ?~~ Oui, pour tous les auteurs (PRD AV-02, ADR-0081 §4.1, accepté).
- ~~Les 10 thèmes : quelles couleurs ?~~ Proposés par l'UDR-0075 §3.1 (Ciel, Lagune, Menthe, Citron, Mangue, Corail, Hibiscus, Lavande, Indigo, Nuit), avec leurs contrastes mesurés : **validés par le porteur le 2026-10-05**.
- ~~Une illustration de l'équipe suit-elle le thème en une seule couleur ?~~ Oui : l'ADR-0081 §4.3 en fait un dessin d'une seule couleur, par sécurité. **Validé par le porteur le 2026-10-05.**
