# PRD — Accueil élève : le QR en grand, avec le partage WhatsApp

Règles : [UDR-XXXX accueil-eleve-qr-agrandi](../../decisions/udr/0182-accueil-eleve-qr-agrandi.md). Un seul lot (vue, placement, CSS, I18n, tests).

## Critères d'acceptation

| CA | Critère | Test |
|---|---|---|
| CA-1 | Le cadre du QR est un bouton nommé « Agrandir le QR de <école> » qui ouvre la fenêtre du QR en grand | `test/controllers/classroom/student_home_class_card_qr_test.rb` |
| CA-2 | À 390 px la fenêtre occupe tout l'écran ; à 1440 px elle est centrée et ≤ 384 px ; Échap ou un clic sur le fond la ferme et le focus revient au QR | `test/system/classroom/student_home_test.rb` |
| CA-3 | « Partager sur WhatsApp » ouvre wa.me, dans un nouvel onglet, avec le message et l'adresse publique de l'établissement seulement (ni jeton de classe, ni identifiant d'élève) | `test/controllers/classroom/student_home_class_card_qr_test.rb` |
