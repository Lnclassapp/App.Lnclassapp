# 🧠 DOMAINE · Entities::Catalog::FigureCatalogs
# Rôle : listes fermées des identifiants (aires et lieux) de chaque fond de carte d'une figure `map` ; Ruby pur, lu par Figure et par le script de contenus
# ADR  : XXXX-figures-des-matieres-de-3eme (§4.2, §4.3) · UDR : XXXX-figures-des-matieres-de-3eme (§3)
module Entities
  module Catalog
    module FigureCatalogs
      COTE_D_IVOIRE_AREAS = %w[
        abidjan yamoussoukro bas_sassandra comoe denguele goh_djiboua lacs lagunes montagnes sassandra_marahoue savanes vallee_du_bandama woroba zanzan
        dense_forest savanna coastal_strip mountain_west
      ].freeze
      COTE_D_IVOIRE_PLACES = %w[
        abidjan yamoussoukro bouake daloa korhogo san_pedro man gagnoa abengourou bondoukou odienne divo sassandra grand_bassam bingerville assinie grand_lahou
        dabou agboville kong seguela ferkessedougou katiola dimbokro aboisso tabou soubre toumodi tiassale danane boundiali touba guiglo duekoue bouafle adzope
        issia kossou taabo buyo ayame
      ].freeze

      AFRICA_AREAS = %w[
        dza ago ben bwa bfa bdi cmr cpv caf tcd com cod cog civ dji egy gnq eri swz eth gab gmb gha gin gnb ken lso lbr lby mdg mwi mli mrt mus mar moz nam ner
        nga rwa stp sen syc sle som zaf ssd sdn tza tgo tun uga zmb zwe
      ].freeze
      AFRICA_PLACES = %w[
        algiers luanda porto_novo gaborone ouagadougou gitega yaounde praia bangui ndjamena moroni kinshasa brazzaville yamoussoukro djibouti cairo malabo asmara
        mbabane addis_ababa libreville banjul accra conakry bissau nairobi maseru monrovia tripoli antananarivo lilongwe bamako nouakchott port_louis rabat
        maputo windhoek niamey abuja kigali sao_tome dakar victoria freetown mogadishu pretoria juba khartoum dodoma lome tunis kampala lusaka harare
        abidjan lagos johannesburg casablanca alexandria mombasa douala suez
      ].freeze

      WORLD_AREAS = %w[
        afg ago alb are arg arm atf aus aut aze bdi bel ben bfa bgd bgr bhs bih blr blz bol bra brn btn bwa caf can che chl chn civ cmr cod cog col cri cub cyp cze
        deu dji dnk dom dza ecu egy eri esh esp est eth fin fji flk fra gab gbr geo gha gin gmb gnb gnq grc grl gtm guy hnd hrv hti hun idn ind irl irn irq isl isr
        ita jam jor jpn kaz ken kgz khm kor kos kwt lao lbn lbr lby lka lso ltu lux lva mar mda mdg mex mkd mli mmr mne mng moz mrt mwi mys nam ncl ner nga nic nld
        nor npl nzl omn pak pan per phl png pol pri prk prt pry pse qat rou rus rwa sau sdn sen slb sle slv som srb ssd sur svk svn swe swz syr tcd tgo tha tjk
        tkm tls tto tun tur twn tza uga ukr ury usa uzb ven vnm vut yem zaf zmb zwe
        africa asia europe north_america south_america oceania
      ].freeze
      WORLD_PLACES = %w[
        pearl_harbor hiroshima nagasaki stalingrad normandy berlin london paris moscow washington tokyo rome el_alamein midway warsaw yalta brazzaville new_york
        san_francisco geneva the_hague abidjan
      ].freeze

      MAP_BASES = {
        "cote_d_ivoire" => { areas: COTE_D_IVOIRE_AREAS, places: COTE_D_IVOIRE_PLACES }.freeze,
        "africa" => { areas: AFRICA_AREAS, places: AFRICA_PLACES }.freeze,
        "world" => { areas: WORLD_AREAS, places: WORLD_PLACES }.freeze
      }.freeze

      # → Array<String> ; vide pour un fond inconnu.
      def self.areas(base) = MAP_BASES.dig(base, :areas) || []
      def self.places(base) = MAP_BASES.dig(base, :places) || []
    end
  end
end
