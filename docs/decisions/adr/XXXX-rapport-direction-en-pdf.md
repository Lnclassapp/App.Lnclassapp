# ADR-XXXX : Le rapport pour la direction est un PDF produit par `prawn` à partir du texte relu, et sa version est gardée au journal de l'école
<!-- index
titre: Rapport pour la direction en PDF
statut: Proposé
problematique: comment remettre à la direction un rapport relu par l'équipe, en PDF, sans lui ouvrir l'application
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le rapport pédagogique est rédigé par l'IA, relu et corrigé par l'équipe, puis téléchargé en PDF et transmis par l'équipe elle-même (memo, réponse 10). La direction n'a pas accès au suivi. Le projet n'a aucune gem de PDF.

## 2. Moteurs de décision

1. Un vrai fichier PDF, que l'on envoie sur WhatsApp depuis le téléphone.
2. Aucun binaire externe en production (pas de Chromium côté serveur).
3. Le texte du PDF est exactement le texte relu : aucune régénération au téléchargement.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Page d'impression et « Enregistrer en PDF » du navigateur | Zéro dépendance | Plusieurs gestes sur téléphone, rendu variable ; ce n'est pas le « télécharger » demandé |
| B — `grover` / `wicked_pdf` (HTML vers PDF) | Rendu fidèle au HTML | Chromium ou wkhtmltopdf en production |
| C — `prawn`, Ruby pur (retenue) | Ruby pur, sans binaire, stable | Mise en page écrite en Ruby, sobre |

## 4. Décision

> **Nous ajoutons la gem `prawn` (et `prawn-table`). Le PDF est produit à la demande à partir du texte relu envoyé par le formulaire. Ce texte, la période, l'auteur et la date sont gardés dans une interaction `report_downloaded` du journal. Le PDF lui-même n'est pas stocké : un nouveau téléchargement se refait depuis le journal.**

- Contenu : en-tête (Lnclass, nom de l'école, DRENA, période), sections relues (synthèse, usage par classe en tableau, élèves à suivre, recommandations), pied (« Préparé par <nom>, le <date> »). Police embarquée : DejaVu Sans, pour les accents.
- Réponse : `send_data`, `disposition: attachment`, `Cache-Control: private, no-store`, nom `rapport-<sigle-ou-slug>-<AAAA-MM-JJ>.pdf`. Accès : `FollowSchoolPolicy` `:read_and_note`.
- Longueur : 20 000 caractères au plus pour le texte relu (422 au-delà).

## 5. Conséquences

### 🟢 Positives

- Un PDF réel, sans binaire en production.
- Le journal garde ce qui a été remis à la direction, mot pour mot.

### 🔴 Coûts consentis

- Une dépendance de plus (`prawn`, `prawn-table`, plus une police à embarquer dans `vendor/fonts/`), et `pdf-reader` dans le groupe de test.
- La mise en page est volontairement simple : ni graphiques ni logo d'école.
- Le texte gardé contient des noms d'élèves ; il vit dans `details` de l'interaction, chiffré (`encrypts`), et n'est lisible que par `admin` et `field`.

## 6. Notes d'implémentation

```ruby
# app/infrastructure/school/director_report_pdf.rb (lot rapport)
# Prawn::Document.new(page_size: "A4", margin: 48) { font_families.update("DejaVu" => …) }
```

## 7. Comment vérifier que la décision est respectée

- `test/controllers/teams/director_reports_controller_test.rb` : type `application/pdf`, `no-store`, 403 pour `content`, interaction `report_downloaded` créée avec le texte relu.
- `test/infrastructure/school/director_report_pdf_test.rb` : le texte extrait du PDF (`pdf-reader`, gem de test) contient les accents et la phrase corrigée.
