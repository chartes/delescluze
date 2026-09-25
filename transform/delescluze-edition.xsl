<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:import href="../hteiml/xsl/tei2html.xsl"/>
  <xsl:output indent="no"/><!-- autopilote 2026-09-11 : sinon DoTS-vue colle les mots (condense) -->

  <!-- ================================================================
       Racine de la ressource : n'afficher que le PREMIER texte.

       Sans `ref`, DoTS Vue demande le document entier
       (`document?resource=delescluze-edition&amp;mediaType=html`) : la generique rend la page
       de garde issue du teiHeader PUIS tout le corps (1,9 Mo de HTML), soit
       l'edition complete empilee sous la page d'accueil.

       Sur ELEC, /delescluze/ n'affiche que la page « accueil » (la premiere page de
       la rubrique Paratextes) ; les carnets, passages et lettres passent par le
       sommaire.

       On neutralise donc, au seul rendu du document complet, tout ce qui suit
       la premiere unite citable. Les fragments sont servis dans un
       <dts:wrapper> SANS teiHeader ni <text> : les motifs ci-dessous, ancres
       sur `tei:TEI[tei:teiHeader]/tei:text`, ne les atteignent pas.
       Meme correctif que christofle.xsl et chroniqueslatines.xsl.
       ================================================================ -->
  <!-- Ne garder que la premiere rubrique, reduite a sa premiere page (accueil). -->
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text/tei:body/tei:div[position() &gt; 1]" priority="15"/>
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text/tei:body/tei:div[1]/tei:div[position() &gt; 1]" priority="15"/>
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text/tei:back" priority="15"/>



  <xsl:template match="*[local-name() = 'wrapper']" priority="20">
    <xsl:apply-templates/>
    <!-- 2026-09-11 (D3) : les notes des notices de l'index (biographie, « Voir aussi ») sont rendues
         dans la notice, comme sur l'ancien site ; pas d'apparat de notes pour elles. -->
    <xsl:if test="not(tei:text) and .//tei:note[not(parent::tei:person)]">
      <xsl:call-template name="footnotes">
        <xsl:with-param name="cont" select="."/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:person/tei:note" mode="fn"/>


  <!-- 2026-09-12 (D20) : chaque notice est devenue une UNITÉ citable (niveau « personne » du
       refsDecl, 139 unités), pour que les personnes figurent dans la table des matières. Un renvoi
       vise donc maintenant la notice elle-même, et non plus une ancre dans la page de sa lettre :
       depuis ce changement, DoTS-vue sert la page de lettre en mode `excludeFragments`, où les
       notices détaillées ne sont plus là — une ancre y mènerait à une page qui ne montre que la
       liste des noms. Le repli sur la lettre, puis sur la rubrique, reste pour un identifiant que
       le side-car ne connaît pas. -->
  <!-- 2026-09-25 : chaque notice etant une unite citable, la cible est l'identifiant de la
       personne lui-meme ; la lettre d'index ne servait plus de repli que pour un identifiant
       vide. Le compagnon delescluze-persons.xml disparait donc d'ici. -->
  <xsl:template name="person-href">
    <xsl:param name="pid"/>
    <xsl:text>/delescluze/document/delescluze-edition?refId=</xsl:text>
    <xsl:choose>
      <xsl:when test="$pid != ''"><xsl:value-of select="$pid"/></xsl:when>
      <xsl:otherwise>index-personnes</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 2026-09-14 (agent DEL3) : le retour de note pointait sur LUI-MEME.
       Cette surcharge recopie le `noteback` de la generique (hteiml/xsl/tei2html.xsl,
       template "noteback") mais avait perdu le `_` final de la cible : elle sortait
       <a class="noteback" href="#X"> A L'INTERIEUR de <aside id="X">, si bien que
       cliquer « 1. » ne ramenait pas a l'appel de note mais ne bougeait pas.
       La generique ancre l'APPEL sur `id="{$id}_"` (template "noteref", meme fichier)
       et le retour doit donc viser `#{$id}_`. Mesure avant correction : 1352 retours
       de note sur 175 unites citables servies, 1352 pointant sur eux-memes (aucun
       correct) — script scan_noteback.py, comptage sur les 498 unites de la
       navigation. Un `@target` explicite continue de primer, comme dans la generique. -->
  <xsl:template name="noteback">
    <xsl:param name="class">noteback</xsl:param>
    <xsl:variable name="id"><xsl:call-template name="id"/></xsl:variable>
    <a class="{$class}">
      <xsl:attribute name="href">
        <xsl:choose>
          <xsl:when test="@target"><xsl:value-of select="substring-before(concat(@target, ' '), ' ')"/></xsl:when>
          <xsl:otherwise>
            <xsl:text>#</xsl:text>
            <xsl:value-of select="$id"/>
            <xsl:text>_</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:call-template name="note-n"/>
      <xsl:if test="$class = 'noteback'">
        <xsl:text>. </xsl:text>
      </xsl:if>
    </a>
  </xsl:template>

  <!-- Libelles courts appeles par le mode="a" de la generique.
       Sans ces templates, le fallback imprime <facsimile mode="a">,
       <correspDesc mode="a">, etc. en rouge dans l'interface. -->
  <xsl:template match="tei:figure[@type = 'facsimile']" mode="a" priority="20">
    <xsl:choose>
      <xsl:when test=".//tei:ptr[@target]">
        <a class="facsimile" href="{(.//tei:ptr)[1]/@target}" target="_blank" rel="noopener">
          <xsl:value-of select="normalize-space((tei:graphic/tei:desc | tei:desc)[1])"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <span class="facsimile">
          <xsl:value-of select="normalize-space((tei:graphic/tei:desc | tei:desc | .)[1])"/>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- B6 (autopilote 2026-09-11) : états « Édition » / « Transcription » de l'ancien site, sans script.
       Ancien site : deux sections par page, #edition (formes régularisées, suppressions absentes) et
       #transcription (formes originales, 743 suppressions barrées), basculées en JavaScript.
       La générique ne rendait qu'un flux mêlé (reg + orig en info-bulle + del barrés).
       Ici : reg et orig sont émis tous deux ; deux boutons radio (premiers frères du contenu de la page,
       juste avant le lien de page) pilotent l'affichage en CSS (:checked ~). -->
  <xsl:template match="tei:choice[tei:orig][tei:reg]" priority="12">
    <span class="choice"><span class="reg"><xsl:apply-templates select="tei:reg/node()"/></span><span class="orig"><xsl:apply-templates select="tei:orig/node()"/></span></span>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'page'][@xml:id][.//tei:choice[tei:orig] or .//tei:del]/tei:pb[1]" priority="12">
    <xsl:variable name="p" select="../@xml:id"/>
    <input type="radio" class="dl-mode dl-mode-ed" name="dl-mode-{$p}" id="dl-ed-{$p}" checked="checked"/>
    <label for="dl-ed-{$p}">Édition</label>
    <input type="radio" class="dl-mode dl-mode-tr" name="dl-mode-{$p}" id="dl-tr-{$p}"/>
    <label for="dl-tr-{$p}">Transcription</label>
    <xsl:apply-imports/>
  </xsl:template>

  <xsl:template match="tei:figure[@type = 'facsimile']" priority="20">
    <!-- autopilote 2026-09-11 (B6) : id du facsimile, cible des liens de page « {p. 001} » (a.pb.facs, href="#facs-…") -->
    <xsl:variable name="pid" select="../@xml:id"/>
    <div class="facsimile">
      <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
      <xsl:apply-templates select="tei:graphic"/>
      <!-- D14d (autopilote 2026-09-12) : l'ancien site affichait la cote sous l'image
           (<figcaption>) ; DoTS ne la mettait que dans l'attribut alt. -->
      <xsl:if test="normalize-space((tei:graphic/tei:desc | tei:desc)[1]) != ''">
        <p class="facsimile-desc">
          <xsl:value-of select="normalize-space((tei:graphic/tei:desc | tei:desc)[1])"/>
        </p>
      </xsl:if>
      <xsl:if test=".//tei:ptr[@type = 'viewer'][@target]">
        <p class="viewer-link">
          <a href="{(.//tei:ptr[@type = 'viewer'])[1]/@target}" target="_blank" rel="noopener">
            <xsl:text>Voir dans la salle des inventaires virtuelle</xsl:text>
          </a>
        </p>
      </xsl:if>
    </div>
    <!-- D14d : menu « Aller au mois » des Ephemerides (nav#months-list de l'ancien site) et
         intervalle de dates de la page (nav#pages-list). Les pages de carnet sont sous le
         niveau editable de la collection : les liens prennent la forme
         ?refId=<carnet>#<page> (cf. D8). -->
    <!-- D14d (autopilote 2026-09-12), recalcule le 2026-09-25 : intervalle de dates de la page
         (nav#pages-list de l'ancien site) et menu « Aller au mois » (nav#months-list).
         Le compagnon delescluze-mois.xml est retire : l'intervalle et le mois courant se
         deduisent des <date when> des journees de la page elle-meme, qui sont dans le fragment
         servi. Le releve des 17 mois, lui, est un fait global de l'edition : aucune unite
         citable ne le porte, il est donc inscrit ici (voir le modele « dl-mois-liste »).
         Les pages de carnet sont celles dont l'identifiant commence par « carnet », comme
         ailleurs dans cette feuille (#person, #le-projet-, #index-personnes-). Les pages des
         lettres et des passages n'ont pas ce menu, elles ne l'avaient pas non plus sur l'ELEC. -->
    <xsl:if test="starts-with($pid, 'carnet')">
      <xsl:variable name="dates" select="../descendant::tei:div[@type = 'day']/tei:head/tei:date/@when"/>
      <div class="dl-page-nav">
        <xsl:if test="$dates">
          <p class="dl-page-dates">
            <xsl:call-template name="dl-intervalle">
              <xsl:with-param name="a" select="$dates[1]"/>
              <xsl:with-param name="b" select="$dates[last()]"/>
            </xsl:call-template>
          </p>
        </xsl:if>
        <details class="dl-mois">
          <summary>Aller au mois</summary>
          <ul class="dl-mois-liste">
            <xsl:call-template name="dl-mois-liste"/>
          </ul>
        </details>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:ab[@type = 'correspDesc']" mode="a" priority="20">
    <span class="correspDesc">
      <xsl:value-of select="normalize-space(tei:seg[@type='sent'])"/>
      <xsl:if test="tei:seg[@type='received']">
        <xsl:text> à </xsl:text>
        <xsl:value-of select="normalize-space(tei:seg[@type='received'])"/>
      </xsl:if>
      <xsl:if test="tei:date">
        <xsl:text>, </xsl:text>
        <xsl:value-of select="normalize-space(tei:date[1])"/>
      </xsl:if>
    </span>
  </xsl:template>

  <xsl:template match="tei:ab[@type = 'correspDesc']" priority="20">
    <p class="correspDesc">
      <xsl:value-of select="normalize-space(tei:seg[@type='sent'])"/>
      <xsl:if test="tei:seg[@type='received']">
        <xsl:text> à </xsl:text>
        <xsl:value-of select="normalize-space(tei:seg[@type='received'])"/>
      </xsl:if>
      <xsl:if test="tei:date">
        <xsl:text>, </xsl:text>
        <xsl:value-of select="normalize-space(tei:date[1])"/>
      </xsl:if>
    </p>
  </xsl:template>

  <xsl:template match="tei:ab[@type = 'correspDesc']/tei:seg" mode="a" priority="20">
    <span class="correspAction"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:ab[@type = 'correspDesc']/tei:seg" priority="20">
    <span class="correspAction"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:opener" mode="a" priority="20">
    <span class="opener"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:opener" priority="20">
    <div class="opener"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="tei:list[@type = 'sommaire']" priority="20">
    <ul class="sommaire"><xsl:apply-templates/></ul>
  </xsl:template>

  <!-- 2026-09-12, 20:30 (utilisateur, après avoir vu la colonne en place) : « en vrai enlève
       les lettre a b c d e c'est déjà dans la toc ». Vérifié avant de retirer : le sommaire de
       DoTS-vue liste bien les 19 unités « Index des personnes : lettre A » … « lettre V », donc
       toute liste de lettres rendue dans le texte en est un DOUBLON — qu'elle soit la barre
       horizontale de l'ancien site, le menu déroulant, ou la colonne de gauche. Les trois ont
       existé ici en une soirée ; il n'en reste aucune, la navigation entre lettres étant celle de
       l'application. La liste de l'ancien site (`tei:list[@type='lettres-index']`) n'est donc plus
       rendue du tout. Les versions précédentes sont dans
       delescluze-edition.xsl.bak_lettres_20260912 et .bak_sanslettres_20260912. -->
  <xsl:template match="tei:list[@type = 'lettres-index']" priority="20"/>

  <xsl:template match="tei:list[@type = 'lettres-index']/tei:item" priority="20">
    <xsl:apply-templates/>
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- 2026-09-12 (D18) : les notices de personnes ont reçu leurs variantes de nom et leurs
       identifiants d'autorité, relevés sur le site publié (34 et 37). Il faut donc les rendre,
       sinon la donnée est là sans être visible. Le libellé et la forme du lien reprennent ceux
       du site : « Autre(s) notice(s) relatives à la même personne : BnF : <url> ». L'URL est
       construite ICI, à partir du seul identifiant conservé dans le TEI. -->
  <xsl:template match="tei:note[@type = 'localNames']" priority="25">
    <p class="dl-noms-locaux"><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:idno[@type = 'BnF']" priority="25">
    <xsl:variable name="url" select="concat('http://catalogue.bnf.fr/', normalize-space(.), '/PUBLIC')"/>
    <p class="dl-autorite">
      <span class="dl-autorite-libelle">Autre(s) notice(s) relatives à la même personne : BnF : </span>
      <a class="dl-autorite-lien" href="{$url}" target="_blank" rel="noopener"><xsl:value-of select="$url"/></a>
    </p>
  </xsl:template>

  <xsl:template match="tei:list[@type = 'personnes-index']" priority="20">
    <ul class="personnes-index"><xsl:apply-templates/></ul>
  </xsl:template>

  <xsl:template match="tei:list[@type = 'sommaire']//tei:item | tei:list[@type = 'personnes-index']//tei:item" priority="20">
    <li><xsl:apply-templates/></li>
  </xsl:template>

  <xsl:template match="tei:ref[starts-with(@target, '#index-personnes-')]" priority="25">
    <a href="/delescluze/document/delescluze-edition?refId={substring-after(@target, '#')}"><xsl:apply-templates/></a>
  </xsl:template>

  <!-- 2026-09-12 (D20) : la liste des noms en tête d'une lettre vise désormais la notice-unité. -->
  <xsl:template match="tei:list[@type = 'personnes-index']//tei:ref[starts-with(@target, '#person')]" priority="30">
    <a href="/delescluze/document/delescluze-edition?refId={substring-after(@target, '#')}"><xsl:apply-templates/></a>
  </xsl:template>

  <!--
    Rubrique « Index des personnes » demandée seule : DoTS-vue la reçoit sans ses lettres
    (index-personnes-A…, passages DTS distincts), donc réduite à son titre. Elle a porté
    successivement la barre horizontale de l'ancien site, puis un menu déroulant, puis la colonne
    de gauche ; les trois sont retirées le 2026-09-12 à 20:30 — « en vrai enlève les lettre a b c
    d e c'est déjà dans la toc ». Le sommaire de l'application liste les 19 lettres (vérifié), il
    tient donc seul la navigation, et cette page ne garde que son titre, comme toute rubrique de
    ce déploiement.
  -->
  <!-- En mode excludeFragments, DoTS n'envoie même pas le <div> :
       <dts:wrapper><head>Index des personnes</head></dts:wrapper>. -->
  <xsl:template match="tei:head[parent::*[local-name() = 'wrapper']][not(preceding-sibling::* or following-sibling::*)][normalize-space() = 'Index des personnes']" priority="30">
    <section class="div rubrique level1" id="index-personnes">
      <h1 class="head rubrique"><xsl:apply-templates/></h1>
    </section>
  </xsl:template>

  <xsl:template match="tei:div[@xml:id = 'index-personnes'][not(tei:div)]" priority="30">
    <section class="div rubrique level1" id="index-personnes">
      <h1 class="head rubrique"><xsl:apply-templates select="tei:head[1]/node()"/></h1>
    </section>
  </xsl:template>

  <!-- 2026-09-11 (D3) : lien absolu vers la lettre d'index de la personne (un href « #id » seul
       ramène DoTS-vue à l'accueil ; la rubrique index-personnes seule ne contient pas les notices). -->
  <xsl:template match="tei:ref[starts-with(@target, '#person')]" priority="25">
    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="person-href">
          <xsl:with-param name="pid" select="substring-after(@target, '#')"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <!-- 2026-09-14 : quatre notices ont un @xml:id accentué (brabançon1-3, préveraud). Une ancre
       non-ASCII survit à l'ouverture à froid de l'URL, mais PAS à un clic dans l'application :
       Document.vue passe le href par `new URL(...)` (l. 327), qui pourcent-encode le fragment,
       puis `router.push` (l. 801) ré-encode le « % » — « #préveraud » arrive en
       « #pr%25C3%25A9veraud » et `getElementById` ne trouve plus rien (mesuré au navigateur).
       On ajoute donc à ces notices une ancre ASCII équivalente, que le side-car vise. Les autres
       notices sont rendues par la générique (`tei:listBibl/tei:bibl`, tei2html.xsl l. 2000). -->
  <xsl:variable name="accents-from">àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ</xsl:variable>
  <xsl:variable name="accents-to">aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY</xsl:variable>

  <!-- Les variables sont interdites dans un motif de correspondance en XSLT 1.0 : la table est
       donc réécrite en clair ici. -->
  <xsl:template match="tei:listBibl/tei:bibl[@xml:id]
                       [translate(@xml:id, 'àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ', 'aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY') != string(@xml:id)]"
                priority="25">
    <li>
      <xsl:call-template name="atts"/>
      <a class="bibl-ascii-anchor"
         id="bibl-{translate(@xml:id, $accents-from, $accents-to)}">&#x200c;</a>
      <xsl:apply-templates/>
    </li>
  </xsl:template>

  <!-- 2026-09-14 (agent DEL3) : « Version en ligne : http://… » ne doit PAS repartir en bas de la
       page de bibliographie. La rétro-conversion a encodé ces mentions en <note type="reference">
       dans le <bibl> ; la générique rend une note À LA FOIS en place ET dans l'apparat, si bien que
       « Sources et bibliographie » se terminait par 33 notes fantômes recopiant les 33 URL déjà
       visibles dans leur notice — et leur retour de note ne pouvait viser aucun appel, puisque la
       générique n'en émet pas pour elles (mesuré : 33 retours sans ancre, sur cette page seulement).
       Sur l'ÉLEC, la mention est inline dans la notice — <span class="ref">Version en ligne : <a …>
       — et la page ne porte AUCUN apparat de notes (pas de <article id="notes">, vérifié dans
       data/legacy/sources-et-bibliographie.html). On retire donc la copie d'apparat, on garde la
       mention en place. Même procédé que `tei:person/tei:note` plus haut (mode fn neutralisé).
       Portée : les 33 notes sont toutes sous tei:listBibl (29 enfants directs de <bibl>, 4 dans le
       <title> d'un <bibl> — « Autopacte. En ligne : … », que l'ÉLEC rendait lui aussi inline, dans
       le <cite>) ; il n'existe aucune note[@type='reference'] ailleurs dans le corps, et le seul
       autre <listBibl> du document est dans <text><back>, que la feuille ne rend pas (l. 32).
       Aucune autre page ne peut donc être touchée. -->
  <xsl:template match="tei:listBibl//tei:note" mode="fn"/>

  <!-- 2026-09-14 : appel de référence bibliographique dans une note (« lien dans les notes qui
       marchent pas »). Le modèle générique « @ref | @target » (hteiml/xsl/tei2html.xsl l. 3309)
       résout « #x » par key('id','x') DANS LE FRAGMENT SERVI ; la <bibl> visée est dans une autre
       unité (sources-et-bibliographie), la clé ne trouve rien, le xsl:for-each ne tourne pas et
       le <a> sortait SANS @href du tout — 39 appels inertes. On vise donc l'unité qui sert la
       notice, plus l'ancre, comme l'ancien site ÉLEC le faisait avec
       « ../sources-et-bibliographie.html#nougaretParinetClavaud ».
       La classe reste « bibl » : DoTS-vue ne garde que le PREMIER jeton de classe, et le CSS du
       corpus s'appuie dessus (#main #article .bibl). -->
  <!-- 2026-09-25 : l'ancre est CALCULEE, le compagnon delescluze-bibl.xml est retire.
       Les 370 <bibl xml:id> du document sont soit dans « sources-et-bibliographie »,
       soit dans le doublon de text/back/listBibl, qui n'appartient a aucune unite citable :
       ses identifiants « -bis » visent donc la notice identique de la page de bibliographie,
       comme le faisait l'ancien site ELEC. Les 38 renvois du corps visent tous une notice
       existante (verifie), il n'y a donc plus de repli sans ancre. Les quatre identifiants
       accentues prennent l'ancre ASCII posee par le modele « bibl-ascii-anchor » ci-dessus. -->
  <xsl:template match="tei:ref[@type = 'bibl'][starts-with(@target, '#')]" priority="25">
    <xsl:variable name="cible" select="substring-after(@target, '#')"/>
    <xsl:variable name="bid">
      <xsl:choose>
        <xsl:when test="substring($cible, string-length($cible) - 3) = '-bis'">
          <xsl:value-of select="substring($cible, 1, string-length($cible) - 4)"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$cible"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="ascii" select="translate($bid, $accents-from, $accents-to)"/>
    <a class="bibl">
      <xsl:attribute name="href">
        <xsl:text>/delescluze/document/delescluze-edition?refId=sources-et-bibliographie#</xsl:text>
        <xsl:choose>
          <xsl:when test="$ascii != $bid"><xsl:text>bibl-</xsl:text><xsl:value-of select="$ascii"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="$bid"/></xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="tei:persName[starts-with(@ref, '#person')] | tei:name[starts-with(@ref, '#person')] | tei:rs[starts-with(@ref, '#person')]" priority="25">
    <a class="linkToIndex">
      <xsl:attribute name="href">
        <xsl:call-template name="person-href">
          <xsl:with-param name="pid" select="substring-after(@ref, '#')"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:apply-templates/>
    </a>
  </xsl:template>

  <xsl:template match="tei:ref[starts-with(@target, '#le-projet-')]" priority="25">
    <a href="/delescluze/document/delescluze-edition?refId={substring-after(@target, '#')}"><xsl:apply-templates/></a>
  </xsl:template>

  <xsl:template match="tei:person" priority="20">
    <article class="person" id="{@xml:id}">
      <h2><xsl:apply-templates select="tei:persName[1]/node()"/></h2>
      <xsl:apply-templates select="node()[not(self::tei:persName[1])][not(self::tei:listRef[@type = 'linksToEdition'])]"/>
      <!-- 2026-09-11 (D3b) : « Personne citée dans », comme la section linksToEdition de l'ancien site.
           2026-09-25 : les occurrences sont portees par le TEI (un <listRef type="linksToEdition">
           par unite d'edition : un <ref type="groupe"> qui la nomme, puis un <ref> par unite citable
           ou le nom figure). Aucun fragment DTS ne voit le reste du document : la liste ne peut pas
           etre recalculee ici, elle appartient a l'index lui-meme. @corresp porte l'unite a ouvrir
           quand la cible est sous le niveau editable de DoTS-vue ; sans lui, la cible s'ouvre seule. -->
      <xsl:variable name="cited" select="tei:listRef[@type = 'linksToEdition']"/>
      <xsl:if test="$cited">
        <section class="linksToEdition">
          <p class="linksToEdition-head">Personne citée dans :</p>
          <ul>
            <xsl:for-each select="$cited">
              <li>
                <xsl:value-of select="tei:ref[@type = 'groupe'][1]"/>
                <xsl:text> : </xsl:text>
                <xsl:for-each select="tei:ref[not(@type = 'groupe')]">
                  <xsl:if test="position() &gt; 1"><xsl:text> ; </xsl:text></xsl:if>
                  <a>
                    <xsl:attribute name="href">
                      <xsl:text>/delescluze/document/delescluze-edition?refId=</xsl:text>
                      <xsl:choose>
                        <xsl:when test="@corresp">
                          <xsl:value-of select="substring-after(@corresp, '#')"/>
                          <xsl:text>#</xsl:text>
                          <xsl:value-of select="substring-after(@target, '#')"/>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="substring-after(@target, '#')"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:attribute>
                    <xsl:value-of select="."/>
                  </a>
                </xsl:for-each>
              </li>
            </xsl:for-each>
          </ul>
        </section>
      </xsl:if>
      <!-- autopilote 2026-09-11 (B6) : « #top » n'existe pas dans le fragment ; retour en tête de la lettre d'index
           (section index-personnes-X, barre A–Z), comme le « Top » de l'ancien site. -->
      <!-- 2026-09-11 (D3) : dans le fragment servi, la div de la lettre n'est pas ancêtre (href="#").
           2026-09-25 : la lettre d'index se deduit du nom lui-meme — l'index est alphabetique,
           et les 139 notices le verifient. -->
      <xsl:variable name="letter"><xsl:call-template name="dl-lettre-index"/></xsl:variable>
      <p><a class="back" href="/delescluze/document/delescluze-edition?refId={$letter}">Retour</a></p>
    </article>
  </xsl:template>

  <xsl:template match="tei:person/tei:note" priority="20">
    <p class="{@type}"><xsl:apply-templates/></p>
  </xsl:template>

  <!-- 2026-09-11 (D3) : « Voir aussi » cliquable, comme la section crossReferences de l'ancien site
       (libellés identiques au texte TEI, cibles relevées sur l'ancien site).
       2026-09-14 : le lien visait encore « page de la lettre + ancre » (?refId=index-personnes-X#personY),
       forme d'avant D20. Or la page d'une lettre est servie en excludeFragments : mesuré, elle ne
       contient aucun id person* — l'ancre ne pointait donc sur rien et le lecteur tombait sur la
       simple liste des noms. Passage au modèle person-href (D20), qui vise l'unité de la personne. -->
  <xsl:template match="tei:person/tei:note[@type = 'seeAlso']" priority="25">
    <!-- 2026-09-25 : les renvois « Voir aussi » sont des donnees editoriales relevees sur
         l'ancien site ; ils sont desormais dans le TEI, en <ref> vers la notice visee. -->
    <xsl:variable name="see" select="tei:ref[starts-with(@target, '#person')]"/>
    <xsl:choose>
      <xsl:when test="$see">
        <p class="seeAlso crossReferences">
          <xsl:text>Voir aussi : </xsl:text>
          <xsl:for-each select="$see">
            <xsl:if test="position() &gt; 1"><xsl:text> ; </xsl:text></xsl:if>
            <a>
              <xsl:attribute name="href">
                <xsl:call-template name="person-href">
                  <xsl:with-param name="pid" select="substring-after(@target, '#')"/>
                </xsl:call-template>
              </xsl:attribute>
              <xsl:value-of select="."/>
            </a>
          </xsl:for-each>
        </p>
      </xsl:when>
      <xsl:otherwise>
        <p class="seeAlso"><xsl:apply-templates/></p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:person/tei:occupation" priority="20">
    <p class="occupation"><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:graphic" priority="20"><!-- autopilote 2026-09-11 (B6) : src relatif à l'application, sans hôte en dur -->
    <xsl:variable name="id"><xsl:call-template name="id"/></xsl:variable>
    <a id="{$id}" href="#{$id}">
      <img alt="{normalize-space(.)}">
        <xsl:attribute name="src">
          <xsl:choose>
            <xsl:when test="starts-with(@url, 'http://') or starts-with(@url, 'https://')"><xsl:value-of select="@url"/></xsl:when>
            <xsl:when test="starts-with(@url, '/delescluze/img/')">
              <xsl:text>/images/delescluze/img/</xsl:text>
              <xsl:value-of select="substring-after(@url, '/delescluze/img/')"/>
            </xsl:when>
            <xsl:when test="starts-with(@url, './img/')"><xsl:text>/images/delescluze/img/</xsl:text><xsl:value-of select="substring-after(@url, './img/')"/></xsl:when>
            <xsl:when test="starts-with(@url, 'img/')">
              <xsl:text>/images/delescluze/img/</xsl:text>
              <xsl:value-of select="substring-after(@url, 'img/')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>/images/delescluze/img/</xsl:text>
              <xsl:value-of select="@url"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </img>
    </a>
  </xsl:template>


  <!--
    Apparat de notes a la racine.

    La generique appelle `footnotes` avec `cont` = le <text> entier : neutraliser
    les divisions ne suffit donc pas, les notes de toute l'edition restaient
    empilees sous le premier texte (les 587 notes de l'edition). On reprend le corps du template
    generique `tei:text` en restreignant `cont` a la page d'accueil.
  -->
  <xsl:template match="tei:TEI[tei:teiHeader]/tei:text" priority="15">
    <xsl:param name="level" select="count(ancestor::tei:group)"/>
    <article>
      <xsl:attribute name="id">
        <xsl:call-template name="id"/>
      </xsl:attribute>
      <xsl:call-template name="atts"/>
      <xsl:apply-templates select="*">
        <xsl:with-param name="level" select="$level +1"/>
      </xsl:apply-templates>
      <xsl:variable name="notes-cont" select="tei:body/tei:div[1]/tei:div[1]"/>
      <xsl:for-each select="/">
        <xsl:call-template name="footnotes">
          <xsl:with-param name="cont" select="$notes-cont"/>
        </xsl:call-template>
      </xsl:for-each>
    </article>
  </xsl:template>

  <!-- D5-DEBUT (autopilote 2026-09-12) : liens vers les anciens sites ELEC -->
  <!-- hteiml fait un lien de tout tei:idno commencant par « http » (tei2html.xsl l. 1805),
       du tei:title voisin d'un idno[@type='URI'] (l. 1796) et de tei:ref/@target (l. 1456).
       Les anciens sites ELEC ferment : le TEXTE affiche est conserve mot pour mot (c'est
       l'identifiant de la publication d'origine), seule la cible devient la route locale.
       Table et bloc produits par dots-autopilot/scripts/d5_legacy_links_fix.py. -->
  <!-- adresse ELEC de cette edition -->
  <xsl:template match="tei:idno[not(@type = 'URI' and ../tei:title)][normalize-space(.) = 'http://elec.enc.sorbonne.fr/delescluze/']" priority="14">
    <a class="idno d5-local" href="/delescluze"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- renvoi du sourceDesc -->
  <xsl:template match="tei:ref[@target = 'http://elec.enc.sorbonne.fr/delescluze/']" priority="14">
    <a class="ref d5-local" href="/delescluze"><xsl:apply-templates/></a>
  </xsl:template>
  <!-- D5-FIN -->

  <!-- D14d (autopilote 2026-09-12) : texte nu dans un div. hteiml (tei2html.xsl l. 367)
       termine son modele de div par <xsl:apply-templates select="*"/> : il ne traite QUE les
       elements, donc tout noeud de texte place directement dans un div est perdu. Quatre pages
       du TEI servi sont ecrites ainsi (introduction-partie-4-3, -4-4, -4-5 et credits ;
       26 406 caracteres pour la seule partie 4-4) : DoTS n'affichait que leur titre, alors que
       l'ancien site montrait tout le texte. On refait ici le modele pour ce seul cas, en
       traitant tous les noeuds ; le reste du modele de hteiml ne concerne que les sorties
       epub2/epub3, inutilisees ici. -->
  <xsl:template match="tei:div[text()[normalize-space() != ''] or tei:ab[@type = 'tableau']]" priority="12">
    <xsl:param name="level" select="count(ancestor::*) - 2"/>
    <section>
      <xsl:call-template name="atts">
        <xsl:with-param name="class">level<xsl:value-of select="$level + 1"/></xsl:with-param>
      </xsl:call-template>
      <xsl:apply-templates>
        <xsl:with-param name="level" select="$level + 1"/>
      </xsl:apply-templates>
    </section>
  </xsl:template>

  <!-- 2026-09-14 — DU TEXTE DISPARAISSAIT DANS LES NOMS.
       La feuille commune `hteiml/xsl/teiHeader2html.xsl` l. 463 déclare
       `<xsl:template match="*[tei:surname]">` : un modèle écrit pour le teiHeader, mais SANS
       mode, donc actif aussi dans le corps du texte, où il l'emporte sur le modèle de nom de
       `tei2html.xsl`. Il boucle sur `select="*"` : il ne garde que les ÉLÉMENTS enfants et
       jette tous les nœuds de texte propres à l'élément.
       Mesuré sur ce corpus le 2026-09-14 (`scripts/d38_persname_texte_perdu.py`) :
       **351 éléments, 702 mots perdus** — ici surtout les parenthèses de la vedette,
       « Nougaret (Christine) » sortant « Nougaret Christine ».
       Décision de l'utilisateur : corriger **corpus par corpus** plutôt que dans la feuille
       commune, que 23 corpus importent et dont deux copies servent. Même surcharge que celle
       posée le même jour dans testaments-poilus.
       Priorité 8 : elle reste sous le modèle de renvoi d'index (priorité 25) de cette feuille,
       qui continue donc de faire les liens vers les notices de personnes. -->
  <xsl:template priority="8"
      match="tei:persName[tei:surname] | tei:name[tei:surname]
           | tei:placeName[tei:surname] | tei:orgName[tei:surname]">
    <span class="{local-name()}"><xsl:apply-templates/></span>
  </xsl:template>

  <!-- 2026-09-25 : mise en conformite du TEI contre tei_all (1 780 erreurs, dont
       510 facsimile/ptr hors contexte). Les remplacements ci-dessous rendent EXACTEMENT
       le meme HTML qu'avant le remodelage ; voir le releve de la seance.

       - <facsimile> n'existe qu'entre <teiHeader> et <text> ; la, il serait hors du
         fragment DTS servi (<dts:wrapper> sans teiHeader) et l'image disparaitrait.
         Le bloc est donc devenu <figure type="facsimile">, admis dans la division de page,
         et le <ptr> du visualiseur, interdit dans <figure>, est porte par un <ab type="viewer">.
       - <head> n'admet pas @when : la date est portee par un <date> qui enveloppe le
         contenu du titre ; il est rendu de maniere transparente.
       - <person> n'existe que dans <listPerson> ; le conteneur est rendu transparent.
       - <ref> n'admet pas author/pubPlace/publisher/biblScope : ils sont dans un <bibl>,
         lui aussi transparent.
       - <idno> n'a pas de @target : l'URL est passee en @corresp, rendue comme @target
         l'etait (modele nomme "ref" de la generique). -->
  <xsl:template match="tei:ab[@type = 'viewer']" priority="20"/>
  <xsl:template match="tei:head/tei:date" priority="20"><xsl:apply-templates/></xsl:template>
  <!-- mode="title" (sommaire du document entier) : la generique y remplace une date par son
       texte brut (hteiml/xsl/common.xsl l. 940), ce qui aplatirait le <choice> et les <hi>
       des titres de journee. Le <date> y est donc transparent lui aussi. -->
  <xsl:template match="tei:head/tei:date" mode="title" priority="20"><xsl:apply-templates mode="title"/></xsl:template>
  <xsl:template match="tei:div[@type = 'index-lettre']/tei:listPerson" priority="20"><xsl:apply-templates/></xsl:template>
  <xsl:template match="tei:ref/tei:bibl" priority="30"><xsl:apply-templates/></xsl:template>
  <xsl:template match="tei:ab[@type = 'tableau']" priority="20"><xsl:apply-templates/></xsl:template>
  <xsl:template match="tei:idno/@corresp"><xsl:call-template name="ref"/></xsl:template>

  <!-- ================================================================
       Releve des 17 mois des ephemerides et mise en forme des dates.

       2026-09-25 : le depot ne doit contenir qu'un TEI et ses feuilles ; les trois
       compagnons charges par document() n'y etaient pas versionnes, et la feuille
       deployee seule cassait le corpus. Tout ce qui se deduit du fragment servi est
       desormais calcule ici. Le tableau ci-dessous est la seule exception : la liste des
       mois et la page ou chacun commence sont un fait de l'edition entiere, qu'aucun
       fragment ne porte. Il est verifie contre les <date when> du TEI (17 mois, du
       1851-11 au 1853-04) ; s'il fallait rouvrir les ephemerides, c'est ici qu'il faut
       le reprendre.
       ================================================================ -->
  <xsl:template name="dl-mois-liste">
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1851-11</xsl:with-param><xsl:with-param name="libelle">novembre 1851</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page001</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-01</xsl:with-param><xsl:with-param name="libelle">janvier 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page001</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-02</xsl:with-param><xsl:with-param name="libelle">février 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page001</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-03</xsl:with-param><xsl:with-param name="libelle">mars 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page006</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-04</xsl:with-param><xsl:with-param name="libelle">avril 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page009</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-05</xsl:with-param><xsl:with-param name="libelle">mai 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page031</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-06</xsl:with-param><xsl:with-param name="libelle">juin 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page037</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-07</xsl:with-param><xsl:with-param name="libelle">juillet 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page046</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-08</xsl:with-param><xsl:with-param name="libelle">août 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page051</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-09</xsl:with-param><xsl:with-param name="libelle">septembre 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page060</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-10</xsl:with-param><xsl:with-param name="libelle">octobre 1852</xsl:with-param><xsl:with-param name="ancetre">carnet1</xsl:with-param><xsl:with-param name="page">carnet1-page074</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-11</xsl:with-param><xsl:with-param name="libelle">novembre 1852</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page004</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1852-12</xsl:with-param><xsl:with-param name="libelle">décembre 1852</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page011</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1853-01</xsl:with-param><xsl:with-param name="libelle">janvier 1853</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page016</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1853-02</xsl:with-param><xsl:with-param name="libelle">février 1853</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page021</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1853-03</xsl:with-param><xsl:with-param name="libelle">mars 1853</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page025</xsl:with-param></xsl:call-template>
    <xsl:call-template name="dl-mois-item"><xsl:with-param name="id">1853-04</xsl:with-param><xsl:with-param name="libelle">avril 1853</xsl:with-param><xsl:with-param name="ancetre">carnet2</xsl:with-param><xsl:with-param name="page">carnet2-page030</xsl:with-param></xsl:call-template>
  </xsl:template>

  <!-- Le mois ou l'on se trouve est rendu comme un ELEMENT distinct : DoTS-vue ne garde que
       le premier jeton de classe des liens internes, et le mois courant n'a pas a etre un lien. -->
  <xsl:template name="dl-mois-item">
    <xsl:param name="id"/>
    <xsl:param name="libelle"/>
    <xsl:param name="ancetre"/>
    <xsl:param name="page"/>
    <li>
      <xsl:choose>
        <xsl:when test="../descendant::tei:div[@type = 'day']/tei:head/tei:date[substring(@when, 1, 7) = $id]">
          <strong class="dl-mois-courant" aria-current="page">
            <xsl:value-of select="$libelle"/>
          </strong>
        </xsl:when>
        <xsl:otherwise>
          <a class="dl-mois-lien" href="/delescluze/document/delescluze-edition?refId={$ancetre}#{$page}">
            <xsl:value-of select="$libelle"/>
          </a>
        </xsl:otherwise>
      </xsl:choose>
    </li>
  </xsl:template>

  <!-- Intervalle de dates d'une page, dans la forme de l'ancien site :
       « 26 avril 1852 », « 3-5 février 1852 », « 29 février-8 mars 1852 »,
       « 24 décembre 1852-1er janvier 1853 ». Verifie sur les 119 pages de carnet. -->
  <xsl:template name="dl-intervalle">
    <xsl:param name="a"/>
    <xsl:param name="b"/>
    <xsl:choose>
      <xsl:when test="string($a) = string($b)">
        <xsl:call-template name="dl-date"><xsl:with-param name="d" select="$a"/></xsl:call-template>
      </xsl:when>
      <xsl:when test="substring($a, 1, 7) = substring($b, 1, 7)">
        <xsl:call-template name="dl-jour"><xsl:with-param name="d" select="$a"/></xsl:call-template>
        <xsl:text>-</xsl:text>
        <xsl:call-template name="dl-date"><xsl:with-param name="d" select="$b"/></xsl:call-template>
      </xsl:when>
      <xsl:when test="substring($a, 1, 4) = substring($b, 1, 4)">
        <xsl:call-template name="dl-jour"><xsl:with-param name="d" select="$a"/></xsl:call-template>
        <xsl:text> </xsl:text>
        <xsl:call-template name="dl-nom-mois"><xsl:with-param name="d" select="$a"/></xsl:call-template>
        <xsl:text>-</xsl:text>
        <xsl:call-template name="dl-date"><xsl:with-param name="d" select="$b"/></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="dl-date"><xsl:with-param name="d" select="$a"/></xsl:call-template>
        <xsl:text>-</xsl:text>
        <xsl:call-template name="dl-date"><xsl:with-param name="d" select="$b"/></xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="dl-date">
    <xsl:param name="d"/>
    <xsl:call-template name="dl-jour"><xsl:with-param name="d" select="$d"/></xsl:call-template>
    <xsl:text> </xsl:text>
    <xsl:call-template name="dl-nom-mois"><xsl:with-param name="d" select="$d"/></xsl:call-template>
    <xsl:text> </xsl:text>
    <xsl:value-of select="substring($d, 1, 4)"/>
  </xsl:template>

  <xsl:template name="dl-jour">
    <xsl:param name="d"/>
    <xsl:choose>
      <xsl:when test="substring($d, 9, 2) = '01'">1er</xsl:when>
      <xsl:otherwise><xsl:value-of select="number(substring($d, 9, 2))"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="dl-nom-mois">
    <xsl:param name="d"/>
    <xsl:variable name="m" select="substring($d, 6, 2)"/>
    <xsl:choose>
      <xsl:when test="$m = '01'">janvier</xsl:when>
      <xsl:when test="$m = '02'">février</xsl:when>
      <xsl:when test="$m = '03'">mars</xsl:when>
      <xsl:when test="$m = '04'">avril</xsl:when>
      <xsl:when test="$m = '05'">mai</xsl:when>
      <xsl:when test="$m = '06'">juin</xsl:when>
      <xsl:when test="$m = '07'">juillet</xsl:when>
      <xsl:when test="$m = '08'">août</xsl:when>
      <xsl:when test="$m = '09'">septembre</xsl:when>
      <xsl:when test="$m = '10'">octobre</xsl:when>
      <xsl:when test="$m = '11'">novembre</xsl:when>
      <xsl:otherwise>décembre</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Lettre d'index d'une notice : premiere lettre du nom, sans accent, en capitale.
       Le fragment d'une notice ne contient pas la division de sa lettre ; le nom, lui, y est. -->
  <xsl:template name="dl-lettre-index">
    <xsl:text>index-personnes-</xsl:text>
    <xsl:value-of select="translate(
      substring(translate(normalize-space(tei:persName[1]), $accents-from, $accents-to), 1, 1),
      'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
  </xsl:template>

</xsl:transform>
