# Plan d'exécution — Message prêt dans le lien WhatsApp de la carte d'aide

> Un seul lot : le changement tient dans un `href`, une lecture déjà faite, une locale et l'en-tête de la direction.

## Graphe

```
Lot A — message prêt (séquentiel, seul)
```

---

## Lot A — Le lien WhatsApp porte un message prêt

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/shell_user_query.rb`
                     `app/controllers/concerns/shell_layout.rb`
                     `app/helpers/navigation_helper.rb` · `app/helpers/support_helper.rb`
                     `app/views/shared/_help_sheet.html.erb` · `app/views/shared/navigation/_header.html.erb`
                     `config/locales/shared/help_sheet.fr.yml` · `config/support.yml` (commentaire)
                     `docs/decisions/udr/0128-…` · `docs/decisions/udr/0061-…`, `0006-…` (marques d'amendement)
- **Dépend de**    : —
- **Test associé** : `test/helpers/support_helper_test.rb` (textes par rôle, encodage)
                     `test/integration/communication/help_sheet_whatsapp_message_test.rb` (CA-1 à CA-4)
                     `test/infrastructure/queries/identity/shell_user_query_test.rb` (éléments séparés, nombre de requêtes)
                     `test/config/support_config_test.rb` (pas de 0 de tête)
                     `test/system/communication/help_sheet_test.rb` (lien mis à jour)
                     `test/system/communication/help_sheet_direction_test.rb` (direction, 390 px)
- **Done quand**   : depuis la carte d'aide, l'élève, l'enseignant et la direction ouvrent WhatsApp avec un message qui les présente, le visiteur avec le message simple

---

## Vérification de collision

Un seul lot : sans objet.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] Pas d'ADR : ni port, ni table, ni contrat nouveau
- [x] UDR-0128 écrite, indexée par `script/docs/build_index`
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL à jour sur chaque fichier touché dans `app/`
- [x] `bin/ci` local au vert (verdict dans la PR)
- [x] PR unique vers `Develop`
- [x] `journal.md` clos
