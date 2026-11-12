# UDR-0160 : Les assistants du suivi (briefing, compte rendu dicté, brouillon WhatsApp, rapport pédagogique)
<!-- index
titre: Assistants du suivi
statut: Accepté
adr-lie: [0130](../adr/0130-modeles-de-langage-par-openrouter.md)
problematique: Comment présenter des générations de modèle qui prennent plusieurs secondes, peuvent échouer et ne doivent jamais agir sans validation humaine
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **ADR lié** | ADR-0130 |
| **Remplacé par** | — |

---

## 1. Contexte

Quatre assistants servent le membre `admin` ou `field` : préparer un appel, noter un échange en parlant, rédiger une relance WhatsApp, préparer un rapport pour la direction. Une génération prend de 2 à 30 secondes et peut échouer. Le modèle propose ; l'humain relit, corrige et décide. Le terrain, c'est souvent un téléphone et un réseau faible.

## 2. Décision

- Toute génération suit le **même cycle d'écran** : en cours (sondage) → prête → en échec avec « Réessayer ». Un seul partial le porte.
- Rien n'est enregistré ni envoyé par un assistant : le compte rendu dicté **pré-remplit** le formulaire « Noter un échange », le brouillon WhatsApp se **copie** ou s'**ouvre** dans WhatsApp.
- Sans clé configurée, les boutons laissent la place à un badge : l'outil ne promet rien qu'il ne peut faire.

## 3. Règles d'implémentation

**Carte « Assistants »** (`app/views/teams/crm/assistants/_card.html.erb`, cible `school_crm_assistants` de UDR-0162)

- `ui_card(title: "Assistants", icon: "sparkles", heading: :h3)`.
- Trois `ui_button(variant: :secondary, size: :md)`, pleine largeur, empilés : « Préparer l'appel » (`sparkles`), « Dicter un compte rendu » (`microphone`), « Rapport pédagogique » (`document-chart-bar`).
- Non configuré : à la place des boutons, `ui_badge("Assistant non configuré", tone: :neutral)` + `text-sm text-mute` « Demandez à un admin d'ajouter la clé OpenRouter. » (CA-23).
- Sous les boutons : `turbo-frame id="school_crm_briefing"` qui reçoit la fiche de briefing.

**Cycle d'une génération** (`app/views/teams/crm/generations/_generation.html.erb`, un `turbo-frame id="generation_<public_id>"`)

- En cours : `ui_loading_state(label: <libellé du type>, variant: :spinner)` ; le frame porte `data-controller="generation-poll"`, `data-generation-poll-url-value` (`GET /teams/generations/:public_id`), `data-generation-poll-interval-value="2000"`, `data-generation-poll-timeout-value="45000"`. Le contrôleur recharge le frame (`frame.reload()`) jusqu'à un état final ou l'échéance, puis affiche l'état d'erreur. `aria-busy="true"` pendant l'attente, `aria-live="polite"` sur le frame.
- Libellés d'attente : « Préparation de la fiche… », « Écoute du compte rendu… », « Rédaction du message… », « Rédaction de la synthèse… ».
- Échec : `ui_error_state(title: "L'assistant n'a pas répondu", message: <selon error_code>, retry_href:, retry_method: :post, retry_label: "Réessayer")` (CA-24). Les routes des assistants n'acceptent que POST : « Réessayer » est un lien `data-turbo-method="post"` (`ui_error_state(retry_method:)`, GET par défaut). Le contrôleur `generations#show` porte la table type → route de relance et type → partial de la fiche prête. `timeout` : « Il a mis trop de temps. » ; `provider_error`, `invalid_response` : « Réessayez dans un instant. »
- Prête : rendu propre au type (ci-dessous). Toute sortie du modèle est du **texte échappé**, affiché en `whitespace-pre-line`, jamais interprété comme HTML.

**Fiche de briefing** (prête) : `<ul role="list" class="space-y-2 text-sm">`, 5 lignes au plus ; sous la liste, `text-xs text-mute` « Préparée <il y a 2 min> » ; `ui_button("Régénérer", variant: :ghost, size: :sm, icon: "arrow-path")`. Un clic sans changement réaffiche la même fiche (CA-22).

**Compte rendu dicté** (`app/views/teams/crm/dictations/_recorder.html.erb`, dans une `ui_modal(title: "Dicter un compte rendu", size: :md)`)

- Contrôleur Stimulus `voice-recorder` (`app/javascript/controllers/voice_recorder_controller.js`), cibles : `start`, `stop`, `timer`, `preview`, `send`, `retry`, `fallback`, `error`.
- États :
  1. Prêt : `ui_button("Commencer", variant: :primary, icon: "microphone")`, texte `text-sm text-mute` « Parlez librement : qui, quoi, la suite, la date de relance. ».
  2. Enregistrement : point `bg-error` animé (`motion-safe:animate-pulse`), minuteur `mm:ss` en `font-display text-2xl` (`role="timer"`, `aria-live="off"`), `ui_button("Arrêter", variant: :danger, icon: "stop")`. Arrêt automatique à 3:00.
  3. Enregistré : `<audio controls>` (aperçu local), `ui_button("Envoyer", variant: :primary)`, `ui_button("Recommencer", variant: :ghost)`.
  4. Envoi : bouton « Envoyer » désactivé + `ui_spinner`, puis le partial de génération remplace la modale (« Écoute du compte rendu… »).
- Format : `MediaRecorder` avec `audio/webm;codecs=opus`, sinon `audio/mp4` (Safari), sinon `audio/ogg`. Navigateur sans `MediaRecorder` : cible `fallback` visible, `<input type="file" accept="audio/*" capture>`.
- Micro refusé : cible `error` « Autorisez le micro dans votre navigateur, ou importez un enregistrement. » + le `fallback`.
- Refus serveur (CA-26) : 422, message dans la modale « Enregistrement trop long ou format non pris en charge (3 min, 10 Mo, webm/ogg/mp4). ».
- Prête : la modale affiche le formulaire « Noter un échange » de UDR-0162, pré-rempli, `source=dictation`, avec en tête un bandeau `bg-info-soft text-info rounded` « Pré-rempli par l'assistant : vérifiez avant d'enregistrer. ». Réponse inexploitable (CA-27) : bandeau `bg-warning-soft text-warning` « L'assistant n'a pas su structurer : la transcription est dans la note. ». Échec : `ui_error_state` + lien « Saisir à la main » (formulaire vide).

**Brouillon WhatsApp** (`app/views/teams/crm/whatsapp_drafts/_draft.html.erb`, dans une `ui_modal(title: "Message de relance")`)

- Prête : `textarea` modifiable (600 caractères, compteur `text-xs text-mute`, `aria-describedby` vers le compteur) ; `ui_copy_button(<texte>, label: "Copier", copied: "Copié")` ; si un contact de l'école a un numéro : `ui_field(as: :select)` « Destinataire » (contacts avec numéro) et `ui_button("Ouvrir dans WhatsApp", variant: :primary, href: "https://wa.me/225<numéro>?text=<texte encodé>", icon: "chat-bubble-left-right")` en `target="_blank" rel="noopener"`. Le contrôleur Stimulus `whatsapp-link` recalcule le `href` à chaque modification du texte ou du destinataire. Sans contact avec numéro : « Copier » seul + `text-sm text-mute` « Ajoutez un contact avec un numéro pour ouvrir WhatsApp. ».
- L'application n'envoie rien (CA-28).

**Rapport pédagogique** (`GET /teams/pedagogy-reports/:public_id`, `app/views/teams/crm/pedagogy_reports/show.html.erb`)

- Page à part (le bouton de la carte fait un `POST` puis redirige). `ui_page_header(title: "Rapport pédagogique", subtitle: "<école> · 30 derniers jours", back: fiche#school_crm)`.
- En-tête imprimable : nom de l'école, DRENA, période, date de préparation.
- Quatre chiffres (`grid grid-cols-2 lg:grid-cols-4 gap-4`, `ui_card(padding: :sm)`) : élèves actifs, devoirs donnés, taux de rendu, réussite moyenne.
- « Réussite par matière » : `<table>` (matière, sessions terminées, réussite moyenne) ; `ui_subject_badge` pour la matière.
- « Notions à retravailler » : 5 lacunes les plus fréquentes (notion, matière, nombre d'élèves).
- « Synthèse » : le partial de génération (« Rédaction de la synthèse… ») ; prête : texte de 250 mots au plus, `whitespace-pre-line`.
- Actions : `ui_button("Imprimer", variant: :secondary, icon: "printer")` (contrôleur Stimulus `print`, CSP stricte : pas de `onclick`), `ui_copy_button` « Copier le texte » (chiffres + synthèse en texte brut).
- Impression : navigation, actions et bandeaux en `print:hidden` ; fond blanc ; tableau sans coupure de ligne (`break-inside-avoid`).
- Sans activité sur 30 jours (CA-30) : `ui_empty_state(title: "Pas encore assez d'activité", description: "Le rapport se prépare dès que des élèves travaillent sur Lnclass.", icon: "chart-bar")`, aucun appel au modèle.

**Tokens** : couleurs du `@theme` (`bg-info-soft`, `text-info`, `bg-warning-soft`, `text-warning`, `bg-error`, `text-mute`) ; aucune valeur en dur ; icônes Heroicons du sprite existant.

**États obligatoires** : chacun des quatre assistants a son état en cours, prêt, échec, et l'état « non configuré » de la carte ; le rapport a son état vide.

**Accessibilité** : `aria-live="polite"` et `aria-busy` sur les frames de génération ; le minuteur n'est pas annoncé chaque seconde ; les boutons d'enregistrement ont un libellé texte, pas seulement une icône ; cibles ≥ 48 px ; le focus revient au déclencheur à la fermeture des modales ; `prefers-reduced-motion` respecté (`motion-safe:`).

## 4. Conséquences

- Tout futur assistant ou agent réutilise le partial de génération et le contrôleur `generation-poll` ; aucun écran n'attend un modèle dans la requête.
- Aucun assistant n'a de bouton « Enregistrer » ou « Envoyer » qui agirait sans relecture humaine.
- Les contrôleurs Stimulus `generation-poll`, `voice-recorder`, `whatsapp-link` et `print` sont génériques et réutilisables hors du suivi.
