# Memo — Afficher le code PIN

| | |
|---|---|
| **Type de cycle** | feature (léger : une option du composant champ, un contrôleur Stimulus, aucun changement de domaine) |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/afficher-pin` |
| **Programme** | — |

---

## Le problème

Le PIN se tape à l'aveugle : quatre points, sans moyen de vérifier. Au téléphone, une faute de frappe sur un clavier numérique serré se voit seulement au 422 (« Numéro ou PIN incorrect. », « Les deux PIN ne sont pas identiques. »). À la connexion, chaque erreur compte pour le verrouillage (cinq tentatives, ADR-0050).

Le porteur, le 2026-09-28 : « ajoute l'option affichage du code PIN sur les champs des formulaires d'inscription, connexion et sur les profils ».

## Pour qui

Les quatre rôles, sur tous les écrans où l'on saisit un PIN, surtout au téléphone d'entrée de gamme (UDR-0041).

## Pourquoi maintenant

Demande du porteur du 2026-09-28, avant la mise en production de la V1.

## Périmètre

Les champs recensés par `grep -rn -E "password|:pin" app/views` : **13 champs PIN dans 7 vues**, tous `ui_field … as: :password`.

| Écran | Vue | Champs |
|---|---|---|
| Connexion | `identity/sessions/new` | PIN |
| Inscription sur invitation (équipe) | `identity/invitations/show` | PIN, confirmation |
| Inscription enseignant | `identity/teacher_registrations/_form` | PIN, confirmation |
| Inscription élève par code de classe | `classroom/joins/_signup_form` | PIN, confirmation |
| Profil — changer mon PIN | `identity/profile_pins/edit` | PIN actuel, nouveau PIN, confirmation |
| Profil — changer mon numéro | `identity/profile_contacts/edit` | PIN actuel |
| PIN oublié | `identity/pin_resets/new` | nouveau PIN, confirmation |

Plus la démonstration du champ mot de passe de `/design`.

## Hors périmètre

- Les codes à usage unique (second facteur, code de récupération) : ce sont déjà des champs texte, lisibles.
- Le domaine, les contrôleurs, les validations : rien ne change côté serveur.
- Remasquer au bout d'un délai ou à la perte du focus : non demandé ; le masquage au chargement et à l'envoi suffit (voir le grill).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une option du champ ou un nouveau composant ? | Le libellé, l'aide, l'erreur et l'`aria-describedby` de `ui_field` restent les mêmes ; seul le contrôle gagne un bouton. | Option `reveal: true` de `ui_field`, refusée (`ArgumentError`) hors `as: :password`. |
| Le re-rendu 422 de la connexion et des inscriptions est un **morphing** Turbo (page rafraîchie sur la même adresse). Que devient le bouton ? | Le morphing recopie les attributs du serveur : il remettrait `hidden` sur le bouton, alors que le contrôleur, resté connecté, ne repasse pas par `connect`. | Le contrôleur annule `turbo:before-morph-attribute` pour `hidden` sur son bouton. Le type, `aria-pressed` et les icônes, eux, reviennent à l'état masqué du serveur. |
| Le PIN reste-t-il visible au retour arrière (cache Turbo) ? | L'instantané garde l'attribut `type="text"`. | Le contrôleur remasque au `connect` et avant la mise en cache (`turbo:before-cache`). |
| Le navigateur proposera-t-il d'enregistrer un PIN en clair ? | Oui si le champ est en `text` à l'envoi. | Remasqué sur l'événement `submit` du formulaire, avant que Turbo n'envoie. |
| « Le focus reste dans le champ » : au clavier aussi ? | Au doigt et à la souris, le focus ne quitte pas le champ (le curseur garde sa place). Au clavier, on a quitté le champ par Tab pour atteindre le bouton : le focus reste sur le bouton, pour pouvoir le rebasculer (motif « toggle button » WAI-ARIA), Maj+Tab ramène au champ. | Règle écrite dans l'UDR-0051 et testée. |
| Edge affiche déjà son propre œil sur les champs mot de passe. | Deux yeux dans le même champ. | L'œil natif (`::-ms-reveal`) est masqué dès que le nôtre est affiché ; sans JavaScript, Edge garde le sien. |
| Deux boutons « Afficher le code » dans le même formulaire (PIN et confirmation) : lequel est lequel ? | `aria-controls` désigne le champ ; l'ordre de tabulation les place juste après leur champ. | Libellé fixé par la demande, identique pour chaque champ. |

## Cas limites identifiés

- Sans JavaScript : le bouton reste `hidden`, le champ fonctionne comme aujourd'hui.
- 422 : le PIN est vidé par le serveur (inchangé) et revient masqué, bouton visible.
- Téléphone (390 px) : le bouton de 48 px tient dans le champ, le texte ne passe pas dessous (`pr-14`).

## Questions encore ouvertes

- Aucune.
