# Plan d'exécution — Copie refusée : la page ne répond plus

> Un seul lot. `plan.md` est gardé parce que `modal_controller.js` est partagé par toutes les boîtes `ui_modal`.

## Lot A — La boîte et le compteur se recalent après un re-rendu par morphing

- **Couche**       : ui (Stimulus)
- **Fichiers**     : `app/javascript/controllers/modal_controller.js` *(partagé)*
                     `app/javascript/lib/assessment/copy_sheet.js` · `app/javascript/controllers/assessment/copy_controller.js`
                     `test/system/assessment/exercise_copy_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/system/assessment/exercise_copy_test.rb`, nouveau test « copie refusée après la confirmation : la boîte se referme, l'élève corrige et rend, compteur juste »
- **Done quand**   : après un 422 venu de la confirmation, `dialog#copy-confirm` n'est plus modale, un toucher coche une réponse, le compteur compte les réponses réaffichées, et la copie corrigée se rend (303 → résultat).

### Contrat d'exécution (ordre strict)

1. Écrire le test système : copie avec une réponse rendue illisible (valeur d'indice hors bornes posée en JS, comme le jetable du journal), confirmation, 422 ; puis assert `dialog#copy-confirm` ni `[open]` ni `:modal`, `choose` une réponse de la question 5 réussit, `#copy-counter` affiche le bon nombre, et la copie corrigée se rend.
2. Le lancer : **rouge pour la bonne raison** (`ElementClickInterceptedError … <html>` ou compteur « 0/5 »). Un test vert d'emblée ne reproduit rien : le réécrire.
3. Corriger à la cause :
   - `modal_controller.js#connect` : un contrôleur (re)connecté appelle `syncOpen()` avant tout, pour refermer une boîte restée dans la couche supérieure sans `open` (vérifié en jetable : suffit à débloquer la page) ;
   - `copy_sheet` : se recaler sur `turbo:morph` (compteur), comme `phone_digits`, `pin_match`, `signup_steps`.
4. Relancer : vert. 5. Relancer `test/system/assessment/` et les tests système des modales (`test/system/error_paths_test.rb`, toute suite qui ouvre une `ui_modal`) : rien d'autre ne bouge.
