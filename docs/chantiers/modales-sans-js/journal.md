# Journal — Une modale servie ouverte reste invisible sans JavaScript

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Rapport de root cause (2026-09-28)

1. **Chaîne d'appels** : `Identity::ProfileNamesController#edit` → `identity/profile_names/edit.html.erb` → `ui_modal(..., open: true)` (`app/helpers/components_helper.rb:204`) → `components/_modal.html.erb`, qui ne traduit `open` qu'en `data-modal-open-value` → `modal_controller.js#connect` appelle `showModal()`.
2. **Cause** : `app/views/components/_modal.html.erb:6` écrit le `<dialog>` sans jamais son attribut HTML `open`. L'état « ouvert » demandé par la vue n'existe que dans une donnée lue par JavaScript ; sans lui, le navigateur applique la règle `dialog:not([open]) { display: none }`.
3. **Pourquoi aucun test ne l'a vu** : tous les tests système tournent dans Chrome avec JavaScript (Selenium) ; le test du composant (`test/helpers/components_helper_test.rb`) vérifiait la valeur Stimulus, pas l'attribut `open` du `<dialog>`. Le test de reproduction va donc dans ce test de helper (rendu HTML, sans navigateur), au plus bas niveau qui voit le défaut.

Phrase de contrôle : l'ouverture de la boîte de dialogue dépendait entièrement du script ; le HTML serveur ne la portait pas.

Piège du correctif : un `<dialog open>` est ouvert **non modal** ; `showModal()` sur une boîte déjà ouverte lève `InvalidStateError`. Le contrôleur doit donc retirer `open` puis appeler `showModal()`, et `closed()` ne doit pas vider le frame pendant cette réouverture.

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
