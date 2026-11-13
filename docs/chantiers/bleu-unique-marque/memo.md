# Memo — Bleu unique de marque

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré *(PR vers `Develop`, fusion par le porteur)* |
| **Ouvert le** | 2026-11-13 |
| **Branche** | `feature/bleu-unique-marque` |
| **Programme** | — |

---

## Le problème

Le porteur : « je constate un écart entre le bleu d'origine sur le logo et le bleu sur les boutons, le bleu sur le layout n'est pas cohérent ». L'application porte quatre bleus : bleu ciel du logo et du bandeau, bleu soutenu des boutons et des liens, un second bouton bleu ciel à texte noir posé à côté du premier, un quatrième bleu sur l'icône. En sombre, le bouton principal change de couleur et de couleur de texte.

## Pour qui

Tous les acteurs : élève (bandeau, boutons, logo), enseignant (boutons, liens ; son orange reste), direction et équipe (boutons, liens, logo), et quiconque installe l'app (PWA, Android élèves) ou tombe sur une page d'erreur ou hors connexion.

## Pourquoi maintenant

Décision du porteur du 2026-11-13, prise après une revue à trois agents : « Bleu roi #0861E1 » devient le seul bleu de Lnclass.

## Hors périmètre

- Les couleurs de rôle (orange enseignant, violet équipe, bleu nuit direction) et le bandeau orange de l'enseignant.
- Les neuf thèmes d'annonce autres que « Ciel ».
- Les illustrations de matières (`subjects/*.svg`, teintes UDR-0069), qui ne sont pas la marque.
- Le dessin du logo : le baobab reste ; seul son fond change de bleu (voir « À trancher » du journal).
- Les icônes de l'app Android enseignants (orange).
- Les fiches imprimables (révision, préparation, examen), en noir et blanc.

## Ce que le grill a révélé

> Grill joué contre la décision transmise par l'orchestrateur (session enfant, contrat de session : pas de question en fin de session).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le texte du bouton et du bandeau reste-t-il noir sur le nouveau bleu ? | Non : noir sur #0861E1 = 2,91:1, blanc = 5,52:1 | Le texte sur bleu devient blanc ; nouveau jeton `on-brand` |
| `text-white` suffit-il pour ce blanc ? | Non : `white` est une surface, #171c24 en sombre | `on-brand` blanc dans les deux modes ; tous les `bg-brand… text-white/ink` migrés |
| Le bandeau enseignant partage `band-ink` avec le bandeau élève : le passer en blanc ? | Non : blanc sur l'orange #ff8a00 ≈ 2,2:1 | `band-ink` garde son rôle (orange) ; le bandeau choisit son encre par rôle (`role_ink_classes`) |
| `brand-strong` peut-il rester un fond en sombre ? | Non : un même jeton ne peut pas être fond à texte blanc et texte clair sur fond sombre | `brand-strong` devient texte et icône seulement ; tous ses fonds passent à `brand` ; un test l'interdit |
| `text-brand` (lien bleu) se lit-il en sombre ? | Non : 3,1:1 sur la carte sombre | Les liens `text-brand` passent à `text-brand-strong` |
| Le « SVG d'origine » est-il le baobab vectorisé ? | Non : c'est un « L » dans un rond (image intégrée) + « Lnclass » ; aucune variante enseignant | Le baobab reste, son fond est recoloré en #0861E1 ; l'affichage du « L » va dans « À trancher » |
| Faut-il garder deux boutons bleus ? | Non : `ui-button-brand` était posé sur les mêmes actions principales | Fusion dans `primary` ; `:brand` lève une erreur |
| Les icônes PNG peuvent-elles être refaites sans outil graphique ? | Oui : fond, baobab et fentes sont trois couleurs pures ; un mélange par pixel les recolore sans halo | Favicon, icônes PWA et Android élèves recolorées dans le chantier |

## Cas limites identifiés

- Bouton désactivé (`opacity-50`) : bleu pâle, texte blanc — inchangé dans son principe.
- Pastille cochée (`has-checked:bg-brand`) : seul le texte au même préfixe passe en `on-brand` ; le texte non coché reste `ink`.
- Rond blanc sur une carte bleue : devient sombre en mode sombre (surface `white`), icône bleu clair — acceptable, noté.
- La page hors connexion est en cache chez l'élève : le numéro de cache augmente pour qu'elle soit reprise.

## Questions encore ouvertes

- Afficher le « L » d'origine à la place du baobab ? → journal, « À trancher ».
