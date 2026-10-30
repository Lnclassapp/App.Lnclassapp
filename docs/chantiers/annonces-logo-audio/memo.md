# Memo — Annonces : le logo officiel, un audio de 10 secondes téléchargeable, plus de « Toutes les annonces »

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/annonces-logo-audio` |
| **Programme** | — |

---

## Le problème

Demande du porteur du 2026-10-30 : « Les annonces : utilise le logo officiel de Lnclass et ajoute un audio de 10 s max à chaque annonce (rends-le aussi téléchargeable pour être réutilisable), et supprime "Toutes les annonces". »

- Une annonce de l'équipe est signée d'un pictogramme qui n'est pas le logo officiel (le baobab sur bleu).
- L'audio d'une annonce n'a aucune borne de durée : seul son poids (10 Mo) l'est. Une annonce est une carte courte ; son audio doit l'être aussi.
- L'audio ne peut qu'être écouté dans la carte : personne ne peut le garder pour le partager ailleurs (WhatsApp, réunion de parents).
- Les accueils de l'enseignant et de la direction gardent sous leur bande un lien « Toutes les annonces » que le porteur ne veut plus.

## Pour qui

- **Équipe** : signe ses annonces du logo officiel ; joint un audio court.
- **Direction et enseignant** : joignent un audio court ; ne voient plus « Toutes les annonces » sous la bande de leur accueil.
- **Élève, enseignant, direction** (tout lecteur d'une carte) : écoutent l'audio et peuvent le télécharger.

## Pourquoi maintenant

L'équipe a publié sur `Develop` trois annonces nationales (« Nouvelles leçons de 3e », « 50 leçons de 3e pour vos classes », « Des figures à manipuler ») et veut leur joindre un audio lu en français, réutilisable ailleurs.

## Hors périmètre

- **Parent, personnel de l'établissement** : ils ne reçoivent aucune annonce aujourd'hui (aucun public ne les vise) ; rien ne change pour eux.
- Enregistrer l'audio dans le navigateur, ou le produire par synthèse vocale dans l'application : on joint un fichier.
- Couper ou réencoder un audio trop long : il est refusé, l'auteur le raccourcit.
- Vérifier les audios déjà joints : la borne s'applique au téléversement ; un audio déjà en ligne reste tel quel jusqu'à son remplacement.
- Accepter d'autres formats que MP3 et M4A (ADR-0081 §4.4 inchangé).
- La page « Reçues » et son adresse : elles restent (onglet des adultes, entrée de navigation). Seul le lien « Toutes les annonces » disparaît.
- Le logo comme image des annonces : il signe la carte, il ne remplace pas l'illustration (voir le grill).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le logo : signature de toute annonce de l'équipe, ou image jointe aux trois annonces ? | Signature. Le design system (§10) dit « Équipe : petit carré bleu avec le logo + Lnclass » ; joint comme image, il occuperait la place de l'illustration et se lirait deux fois sur la même carte. | Une seule modification de la carte, pour toutes les annonces de l'équipe, présentes et futures. Les trois annonces de `Develop` gardent leur illustration et reçoivent seulement l'audio. |
| Où se trouve « Toutes les annonces » ? Faut-il supprimer la page « Reçues » et sa route ? | Seulement sous la bande des accueils de l'enseignant et de la direction (l'élève l'a perdu le 2026-10-06). La même adresse sert l'onglet « Reçues » et l'entrée « Annonces » de la navigation. | Le lien et son libellé partent ; la route, la page et leurs tests restent. |
| Que vaut « 10 secondes » pour un MP3, dont l'encodeur ajoute du silence de début et de fin ? | Un enregistrement de 10,0 s encodé en MP3 mesure jusqu'à 10,1 s en trames. Refuser à 10,0 s exactement rejetterait un audio honnête. | Borne à 10 s, tolérance de 0,3 s ; le message annonce la durée lue. |
| Un fichier peut-il mentir sur sa durée ? | Oui : l'en-tête Xing d'un MP3 ou la durée globale d'un M4A s'écrivent à la main. | Le MP3 se mesure trame par trame ; le M4A par le maximum de ses trois durées (film, piste, table des échantillons). Menace écrite dans l'ADR. |
| Un audio de 10 secondes pèse au plus combien ? | 400 Ko à 320 kbit/s, le débit le plus haut d'un MP3. Le plafond de 10 Mo ne borne plus rien d'utile. | Plafond ramené à 1 Mo : le serveur ne lit jamais plus d'1 Mo pour mesurer la durée. |
| Que télécharge-t-on, sous quel nom ? Faut-il un droit de plus ? | Le fichier tel que joint, sous un nom fixé par l'application (`annonce-<identifiant>.mp3` ou `.m4a`), avec la même règle de lecture que l'écoute. | Pas de nouvelle policy ; un paramètre de téléchargement sur la route existante. |
| Le contrôle dans le navigateur suffit-il ? | Non : il se contourne et un navigateur peut ne pas lire la durée. | Le navigateur prévient tôt ; le serveur décide. Si le navigateur ne lit rien, il ne bloque pas. |

## Cas limites identifiés

- Audio de 10,2 s (padding d'encodeur) : accepté ; de 10,4 s : refusé.
- MP3 dont des octets inconnus séparent deux trames : refusé (« durée illisible »).
- M4A fragmenté (marque `dash`) : sa durée n'est pas dans l'en-tête ; refusé avec le même message.
- Modification d'une annonce dont l'audio, joint avant ce chantier, dure plus de 10 s : il reste tant qu'on ne le remplace pas.
- Téléchargement par un acteur qui ne peut pas lire l'annonce : 404, comme l'écoute.
- Carte sans audio : ni ▶ ni « Télécharger ».

## Questions encore ouvertes

- Aucune.
