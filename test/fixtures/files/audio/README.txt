Enregistrements de test de Entities::Communication::AudioHeader (ADR-0081 §4.4, critère AV-12)
==========================================================================================

Un fichier réel par variante, 1 s de ton à 440 Hz, produit le 2026-10-05 avec ffmpeg 6.1.1 (Ubuntu).
Chaque fichier se décode en entier : `ffmpeg -v error -i <fichier> -f null -`.
L'extension ne compte pas : le format se lit dans les 4096 premiers octets.

Variables communes aux commandes ffmpeg ci-dessous :

  IN="-hide_banner -loglevel error -y -f lavfi -i sine=frequency=440:sample_rate=16000:duration=1"
  OUT="-map_metadata -1 -fflags +bitexact -flags +bitexact -ac 1"

Acceptés
--------

trame.mp3        MP3 sans étiquette ID3 : il commence par une trame (ff f3, MPEG-2 couche III, 16 kHz).
                 ffmpeg $IN $OUT -c:a libmp3lame -b:a 32k -id3v2_version 0 -f mp3 trame.mp3

remplissage.mp3  Le même, précédé de 512 octets nuls de remplissage.
                 { head -c 512 /dev/zero; cat trame.mp3; } > remplissage.mp3

marque-m4a.m4a   AAC dans une boîte ftyp de marque majeure « M4A  ».
marque-m4b.m4a   … « M4B  ».
marque-mp41.m4a  … « mp41 ».
marque-mp42.m4a  … « mp42 ».
marque-isom.m4a  … « isom ».
                 ffmpeg $IN $OUT -c:a aac -b:a 24k -f mp4 -brand "<marque>" marque-<marque>.m4a
                 (marque en minuscules et sans espace dans le nom du fichier)

marque-3gp4.m4a  AAC dans un conteneur 3GP de marque majeure « 3gp4 ».
marque-3gp5.m4a  … « 3gp5 ».
                 ffmpeg $IN $OUT -c:a aac -b:a 24k -f 3gp -brand <marque> marque-<marque>.m4a

Refusés
-------

enregistrement.amr  AMR-NB (« #!AMR\n »). Ce ffmpeg n'a pas d'encodeur AMR (pas de libopencore_amrnb) :
                    l'en-tête est suivi de 50 trames AMR-NB 4,75 kbit/s (octet 0x04 puis 12 octets nuls,
                    20 ms chacune), que ffmpeg décode.
                    { printf '#!AMR\n'; for _ in $(seq 50); do printf '\x04'; head -c 12 /dev/zero; done; } > enregistrement.amr

enregistrement.ogg  Opus dans un conteneur Ogg (« OggS »).
                    ffmpeg $IN $OUT -c:a libopus -b:a 16k -f ogg enregistrement.ogg

enregistrement.wav  WAV PCM 16 bits, 8 kHz (« RIFF…WAVE »).
                    ffmpeg -hide_banner -loglevel error -y -f lavfi -i sine=frequency=440:sample_rate=8000:duration=1 \
                      $OUT -c:a pcm_s16le -f wav enregistrement.wav
