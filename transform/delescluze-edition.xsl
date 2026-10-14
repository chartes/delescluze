<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:epub="http://www.idpf.org/2007/ops"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tf="urn:elec:tableau-filtrable"
  xmlns:dl="urn:delescluze:xsl"
  exclude-result-prefixes="tei epub xs tf dl">
  <!-- ==== 0. DÉCLARATIONS : imports, sortie, paramètres, variables, clés, fonctions ==== -->

  <!-- Delescluze : surcharge de hteiml, reconstruite le 13/10/2026 en partant du rendu
       hteiml nu.

       Une page de carnet, de passage ou de lettre reprend la mise en page du site ÉLEC
       (elec.enc.sorbonne.fr/delescluze, theme/delescluze.css) : le fac-similé à gauche
       (#facsimile), le texte à droite (#text), avec les deux états « Édition » et
       « Transcription » de l'ancien site (bascule JavaScript displaySection), rendus ici
       par deux boutons radio et la CSS : formes régularisées et ajouts de l'éditeur dans
       l'édition, formes originales et suppressions barrées dans la transcription.

       Repris tels quels de la feuille précédente (rien n'est retiré) : notes et apparat,
       renvois à l'index des personnes et à la bibliographie, menu « Aller au mois »,
       intervalle de dates de la page, index des personnes en fiches dépliables, page des
       sources et de la bibliographie, adresses et post-scriptum des lettres, vers,
       textes insérés, tableaux de comptes. -->
  <xsl:import href="../../renderers/hteiml/xsl/tei2html.xsl"/>

  <xsl:import href="tableau-filtrable.xsl"/>

  <xsl:output indent="no"/>

  <xsl:variable name="accents-from">àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ</xsl:variable>

  <xsl:variable name="accents-to">aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY</xsl:variable>

  <!-- Index des personnes en tableau triable et filtrable (2026-10-13 ; remplace les fiches
       repliables par lettre du 2026-10-07). Modèles tf-* de tableau-filtrable.xsl,
       comportement dans delescluze.customJs.js. Colonnes : Nom (et formes du nom), Dates
       (entre parenthèses dans persName), Fonction (occupation), Notice (biographie, voir
       aussi, autorités), Mentions (liens par carnet, lettre, passage ; filtre par source,
       tri sur le nombre de mentions hors passages rédigés, comme le compte des fiches).
       Chaque ligne garde l'@xml:id de la personne : les liens du texte vers
       ?refId=index-personnes#personX tombent sur elle. -->
  <xsl:function name="dl:source" as="xs:string" xmlns:dl="urn:delescluze:xsl" xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xsl:param name="liste" as="element()"/>
    <xsl:variable name="g" select="$liste/tei:ref[@type = 'groupe'][1]"/>
    <xsl:sequence select="if (starts-with($g/@target, '#lettre')) then 'Lettres'
                          else if (starts-with($g/@target, '#passage')) then 'Passages rédigés'
                          else normalize-space($g)"/>
  </xsl:function>

  <!-- ==== 1. HISTORIQUE : surcharge reprise de la feuille de l'ÉLEC (rendu du texte de l'édition) ==== -->

  <!-- Page à fac-similé : deux colonnes, comme l'ÉLEC (section#facsimile, section#text ;
       des classes ici, un carnet servi entier porte plusieurs pages). -->
  <xsl:template match="tei:div[@type = 'page'][tei:figure[@type = 'facsimile']]" priority="20">
    <section class="dl-page" id="{@xml:id}">
      <section class="dl-facsimile">
        <xsl:apply-templates select="tei:figure[@type = 'facsimile']"/>
      </section>
      <section class="dl-text">
        <xsl:apply-templates select="node() except tei:figure[@type = 'facsimile']"/>
      </section>
    </section>
  </xsl:template>

  <!-- ==== 2. BLOCS HTEIML GÉNÉRIQUES : enveloppe dts:wrapper, notes, apparat critique, bibliographie (listBibl) ==== -->

  <xsl:template match="*[local-name() = 'wrapper']" priority="20">
    <xsl:apply-templates/>
    <xsl:if test="not(tei:text) and .//tei:note[not(parent::tei:person)]">
      <xsl:call-template name="footnotes">
        <xsl:with-param name="cont" select="."/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:note[@type = 'apparatus']" priority="20">
    <span class="app" tabindex="0">
      <span class="noteAnchor">[<xsl:value-of select="@n"/>]</span>
      <span class="apparatusNote"><xsl:value-of select="@n"/>. <xsl:apply-templates/></span>
    </span>
  </xsl:template>

  <xsl:template name="note">
    <xsl:if test="not(@type = 'apparatus')">
    <xsl:variable name="id">
      <xsl:call-template name="id"/>
    </xsl:variable>
    <xsl:variable name="text">
      <xsl:for-each select="text()">
        <xsl:value-of select="normalize-space(.)"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="element">
      <xsl:choose>
        <xsl:when test="$format = $epub2">div</xsl:when>
        <xsl:otherwise>aside</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:element name="{$element}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:attribute name="class">
        <xsl:value-of select="normalize-space(concat(@rend, ' ', @resp, ' ', @type, ' ', @place, ' note'))"/>
      </xsl:attribute>
      <xsl:attribute name="id">
        <xsl:value-of select="$id"/>
      </xsl:attribute>
      <xsl:if test="$format = $epub3">
        <xsl:attribute name="epub:type">note</xsl:attribute>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$text='' and count(*)=1 and tei:p">
          <xsl:call-template name="noteback"/>
          <xsl:apply-templates select="*/node()"/>
        </xsl:when>
        <xsl:when test="$text='' and *[1][self::tei:p]">
          <p class="noindent">
            <xsl:call-template name="noteback"/>
            <xsl:apply-templates select="*[1]/node()"/>
          </p>
            <xsl:apply-templates select="*[position() &gt; 1]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="noteback"/>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'page'][@xml:id][.//tei:choice[tei:orig] or .//tei:del or .//tei:note[@type = 'apparatus']]/tei:pb[1]" priority="12">
    <xsl:variable name="p" select="../@xml:id"/>
    <input type="radio" class="dl-mode dl-mode-ed" name="dl-mode-{$p}" id="dl-ed-{$p}" checked="checked"/>
    <label for="dl-ed-{$p}">Édition</label>
    <input type="radio" class="dl-mode dl-mode-tr" name="dl-mode-{$p}" id="dl-tr-{$p}"/>
    <label for="dl-tr-{$p}">Transcription</label>
    <xsl:apply-imports/>
  </xsl:template>

  <xsl:template match="tei:bibl//tei:note" mode="fn"/>

  <xsl:template match="*[local-name() = 'wrapper'][tei:div[@type = 'index-lettre']] | tei:div[@xml:id = 'index-personnes'][tei:div[@type = 'index-lettre']]" priority="50">
    <section class="div rubrique level1" id="index-personnes">
      <h1 class="head rubrique"><xsl:apply-templates select="tei:head[1]/node()"/></h1>
      <xsl:call-template name="dl-index-complet"/>
    </section>
  </xsl:template>

  <xsl:template match="*[local-name() = 'wrapper'][normalize-space(tei:head[1]) = 'Sources et bibliographie'] | tei:div[@xml:id = 'sources-et-bibliographie']" priority="45">
    <xsl:call-template name="biblio-page">
      <xsl:with-param name="div" select="."/>
      <xsl:with-param name="depots" select="('nationalArchives', 'nationalLibraryFrance', 'institutFrance', 'municipalLibraryLille', 'departementArchivesMorbihan', 'departementArchivesRhone', 'rgaspiMoscou')"/>
      <xsl:with-param name="noms" select="('Archives nationales', 'Bibliothèque nationale de France', 'Bibliothèque de l’Institut de France', 'Bibliothèque municipale de Lille', 'Archives départementales du Morbihan', 'Archives départementales du Rhône', 'Archives d’État russes d’histoire sociale et politique (RGASPI), Moscou')"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:p[contains(., 'apparat bibliographique encodé')]" priority="45"/>

  <xsl:template name="biblio-page">
    <xsl:param name="div" as="element()" select="."/>
    <xsl:param name="depots" as="xs:string*" select="()"/>
    <xsl:param name="noms" as="xs:string*" select="()"/>
    <xsl:param name="lien-base" as="xs:string" select="''"/>
    <xsl:param name="titre-fonds" as="xs:string" select="'Sources manuscrites'"/>
    <xsl:param name="titre-imprimees" as="xs:string" select="'Sources imprimées'"/>
    <section class="biblio">
      <h1 class="biblio-titre"><xsl:apply-templates select="$div/tei:head[1]/node()"/></h1>
      <xsl:call-template name="biblio-contenu">
        <xsl:with-param name="noeuds" select="$div/node() except $div/tei:head[1]"/>
        <xsl:with-param name="depots" select="$depots"/>
        <xsl:with-param name="noms" select="$noms"/>
        <xsl:with-param name="lien-base" select="$lien-base"/>
        <xsl:with-param name="titre-fonds" select="$titre-fonds"/>
        <xsl:with-param name="titre-imprimees" select="$titre-imprimees"/>
      </xsl:call-template>
    </section>
  </xsl:template>

  <xsl:template name="biblio-contenu">
    <xsl:param name="noeuds" as="node()*"/>
    <xsl:param name="depots" as="xs:string*" select="()"/>
    <xsl:param name="noms" as="xs:string*" select="()"/>
    <xsl:param name="lien-base" as="xs:string" select="''"/>
    <xsl:param name="titre-fonds" as="xs:string" select="'Sources manuscrites'"/>
    <xsl:param name="titre-imprimees" as="xs:string" select="'Sources imprimées'"/>
      <xsl:for-each select="$noeuds">
        <xsl:choose>
          <xsl:when test="self::tei:div">
            <div class="biblio-groupe">
              <xsl:if test="@xml:id"><xsl:attribute name="id" select="@xml:id"/></xsl:if>
              <xsl:if test="tei:head"><h2 class="biblio-rubrique"><xsl:apply-templates select="tei:head[1]/node()"/></h2></xsl:if>
              <xsl:call-template name="biblio-contenu">
                <xsl:with-param name="noeuds" select="node() except tei:head[1]"/>
                <xsl:with-param name="depots" select="$depots"/>
                <xsl:with-param name="noms" select="$noms"/>
                <xsl:with-param name="lien-base" select="$lien-base"/>
                <xsl:with-param name="titre-fonds" select="$titre-fonds"/>
                <xsl:with-param name="titre-imprimees" select="$titre-imprimees"/>
              </xsl:call-template>
            </div>
          </xsl:when>
          <xsl:when test="self::tei:listBibl">
            <xsl:call-template name="biblio-groupe">
              <xsl:with-param name="liste" select="."/>
              <xsl:with-param name="depots" select="$depots"/>
              <xsl:with-param name="noms" select="$noms"/>
              <xsl:with-param name="lien-base" select="$lien-base"/>
              <xsl:with-param name="titre-fonds" select="$titre-fonds"/>
              <xsl:with-param name="titre-imprimees" select="$titre-imprimees"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="self::comment() or self::processing-instruction() or (self::text() and normalize-space(.) = '')"/>
          <xsl:otherwise>
            <xsl:apply-templates select="."/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
  </xsl:template>

  <xsl:template name="biblio-groupe">
    <xsl:param name="liste" as="element()"/>
    <xsl:param name="depots" as="xs:string*" select="()"/>
    <xsl:param name="noms" as="xs:string*" select="()"/>
    <xsl:param name="lien-base" as="xs:string" select="''"/>
    <xsl:param name="titre-fonds" as="xs:string" select="'Sources manuscrites'"/>
    <xsl:param name="titre-imprimees" as="xs:string" select="'Sources imprimées'"/>
    <xsl:variable name="fonds" select="$liste/tei:bibl[replace(@xml:id, '\d+$', '') = $depots]"/>
    <div class="biblio-groupe">
      <xsl:if test="$liste/tei:head">
        <h2 class="biblio-rubrique"><xsl:apply-templates select="$liste/tei:head[1]/node()"/></h2>
      </xsl:if>
      <xsl:if test="$fonds">
        <h3 class="biblio-sous-titre"><xsl:value-of select="$titre-fonds"/></h3>
        <xsl:for-each-group select="$fonds" group-by="replace(@xml:id, '\d+$', '')">
          <div class="biblio-fonds">
            <h4 class="biblio-depot"><xsl:value-of select="$noms[index-of($depots, current-grouping-key())[1]]"/></h4>
            <xsl:for-each select="current-group()">
              <xsl:call-template name="biblio-notice">
                <xsl:with-param name="cote" select="true()"/>
              </xsl:call-template>
            </xsl:for-each>
          </div>
        </xsl:for-each-group>
      </xsl:if>
      <xsl:if test="$liste/tei:bibl except $fonds">
        <xsl:if test="$fonds">
          <h3 class="biblio-sous-titre"><xsl:value-of select="$titre-imprimees"/></h3>
        </xsl:if>
        <xsl:for-each select="$liste/tei:bibl except $fonds">
          <xsl:call-template name="biblio-notice">
            <xsl:with-param name="lien-base" select="$lien-base"/>
          </xsl:call-template>
        </xsl:for-each>
      </xsl:if>
      <xsl:apply-templates select="$liste/*[not(self::tei:head or self::tei:bibl)]"/>
    </div>
  </xsl:template>

  <xsl:template name="biblio-notice">
    <xsl:param name="cote" as="xs:boolean" select="false()"/>
    <xsl:param name="lien-base" as="xs:string" select="''"/>
    <xsl:variable name="t" select="normalize-space(.)"/>
    <p class="biblio-notice">
      <xsl:if test="@xml:id">
        <xsl:attribute name="id" select="@xml:id"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$cote and matches($t, '^.+?[\s&#160;]:[\s&#160;]')">
          <span class="biblio-cote"><xsl:value-of select="replace($t, '^(.+?)[\s&#160;]+:[\s&#160;].*$', '$1', 's')"/></span>
          <xsl:text>&#160;: </xsl:text>
          <xsl:value-of select="replace($t, '^.+?[\s&#160;]+:[\s&#160;]+(.*)$', '$1', 's')"/>
        </xsl:when>
        <xsl:when test="@corresp and $lien-base != ''">
          <a class="biblio-lien bibl" href="{concat($lien-base, @corresp)}">
            <xsl:apply-templates select="node()" mode="biblio"/>
          </a>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()" mode="biblio"/>
        </xsl:otherwise>
      </xsl:choose>
    </p>
  </xsl:template>

  <xsl:template match="tei:author | tei:editor" mode="biblio">
    <span class="{local-name()}"><xsl:apply-templates select="node()" mode="biblio"/></span>
  </xsl:template>

  <xsl:template match="tei:surname | tei:forename" mode="biblio">
    <span class="{local-name()}"><xsl:apply-templates select="node()" mode="biblio"/></span>
  </xsl:template>

  <xsl:template match="tei:title[@level = 'a']" mode="biblio">
    <span class="biblio-titre-article">«&#160;<xsl:apply-templates select="node()" mode="biblio"/>&#160;»</span>
  </xsl:template>

  <xsl:template match="tei:title" mode="biblio">
    <cite class="title"><xsl:apply-templates select="node()" mode="biblio"/></cite>
  </xsl:template>

  <xsl:template match="node()" mode="biblio" priority="-1">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <xsl:template match="tei:ref/tei:bibl" priority="30"><xsl:apply-templates/></xsl:template>

  <!-- ==== 3. PROPRE AU PROJET ==== -->

  <!-- Ajout de l'éditeur (« février 1852 », « F ») : dans l'édition, sans marque ; absent de
       la transcription (CSS). -->
  <xsl:template match="tei:add" priority="20">
    <span class="add"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:choice[tei:orig][tei:reg]" priority="12">
    <span class="choice"><span class="reg"><xsl:apply-templates select="tei:reg/node()"/></span><span class="orig"><xsl:apply-templates select="tei:orig/node()"/></span></span>
  </xsl:template>

  <xsl:template match="tei:p//tei:lg" priority="20">
    <span class="lg"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:p//tei:l" priority="20">
    <span class="l"><xsl:apply-templates/></span>
  </xsl:template>

  <xsl:template match="tei:floatingText" priority="20">
    <div class="floatingText"><xsl:apply-templates select="tei:body/node()"/></div>
  </xsl:template>

  <xsl:template match="tei:floatingText/tei:body/tei:head" priority="20">
    <p class="floatingTextTitle"><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:title[@rend = 'underline'][not(@ref)]" priority="20">
    <cite class="title_underline"><xsl:apply-templates/></cite>
  </xsl:template>

  <xsl:template match="tei:gap[@reason = 'illegible']" priority="20">
    <span class="gapInDel">(illisible)</span>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'postscript']" priority="20">
    <div class="postscript"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'postscript']/tei:p[1][not(node()[1][self::tei:pb])]" priority="20">
    <p class="p"><span class="postscriptLabel">(P.S. : ) </span><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="tei:div[@type = 'address']" priority="20">
    <div class="address">
      <span class="addressLabel">
        <xsl:choose>
          <xsl:when test="@rend = 'perpendicular'">(Adresse perpendiculaire à la feuille : )</xsl:when>
          <xsl:otherwise>(Adresse : )</xsl:otherwise>
        </xsl:choose>
      </span>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="tei:figure[@type = 'facsimile']" priority="20">
    <xsl:variable name="pid" select="../@xml:id"/>
    <div class="facsimile">
      <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
      <xsl:apply-templates select="tei:graphic"/>
      <xsl:if test="not(tei:graphic)">
        <p class="facsimile-absent"><xsl:apply-templates select="tei:p/node()"/></p>
        <p class="facsimile-desc"><xsl:value-of select="normalize-space(tei:figDesc)"/></p>
      </xsl:if>
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

  <xsl:template match="tei:opener" priority="20">
    <div class="opener"><xsl:apply-templates/></div>
  </xsl:template>

  <xsl:template match="tei:graphic" priority="20">
    <xsl:variable name="id"><xsl:call-template name="id"/></xsl:variable>
    <a id="{$id}" href="#{$id}">
      <img alt="{normalize-space(.)}">
        <xsl:attribute name="src">
          <xsl:choose>
            <xsl:when test="starts-with(@url, 'http://') or starts-with(@url, 'https://')"><xsl:value-of select="@url"/></xsl:when>
            <xsl:when test="starts-with(@url, '/delescluze/img/')">
              <xsl:text>../../images/delescluze/img/</xsl:text>
              <xsl:value-of select="substring-after(@url, '/delescluze/img/')"/>
            </xsl:when>
            <xsl:when test="starts-with(@url, './img/')"><xsl:text>../../images/delescluze/img/</xsl:text><xsl:value-of select="substring-after(@url, './img/')"/></xsl:when>
            <xsl:when test="starts-with(@url, 'img/')">
              <xsl:text>../../images/delescluze/img/</xsl:text>
              <xsl:value-of select="substring-after(@url, 'img/')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>../../images/delescluze/img/</xsl:text>
              <xsl:value-of select="@url"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </img>
    </a>
  </xsl:template>

  <xsl:template match="tei:head/tei:date" priority="20"><xsl:apply-templates/></xsl:template>

  <xsl:template match="tei:head/tei:date" mode="title" priority="20"><xsl:apply-templates mode="title"/></xsl:template>

  <xsl:template match="tei:ab[@type = 'tableau']" priority="20"><xsl:apply-templates/></xsl:template>

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
          <a class="dl-mois-lien" href="?refId={$ancetre}#{$page}">
            <xsl:value-of select="$libelle"/>
          </a>
        </xsl:otherwise>
      </xsl:choose>
    </li>
  </xsl:template>

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
      <xsl:when test="substring($d, 9, 2) = '01'">1<sup>er</sup></xsl:when>
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

  <xsl:template match="tei:table[not(.//tei:cell[@role = 'label'] or .//tei:row[@role = 'label'])]/tei:row[count(tei:cell) = 1]/tei:cell[@cols = 2]"
                priority="30">
    <th colspan="2" scope="colgroup">
      <xsl:apply-templates/>
    </th>
  </xsl:template>

  <xsl:template match="tei:table[not(.//tei:cell[@role = 'label'] or .//tei:row[@role = 'label'])]/tei:row/tei:cell[1][following-sibling::tei:cell][starts-with(normalize-space(.), 'Total') or starts-with(normalize-space(.), '[Total]') or starts-with(normalize-space(.), 'Reste') or starts-with(normalize-space(.), '[Reste]') or starts-with(normalize-space(.), 'Restant') or starts-with(normalize-space(.), 'Avoir') or starts-with(normalize-space(.), '[Avoir]') or starts-with(normalize-space(.), 'Report')]"
                priority="30">
    <th scope="row">
      <xsl:apply-templates/>
    </th>
  </xsl:template>

  <!-- ==== 4. MÉCANISMES COMMUNS : tableau filtrable (tf-*), liens vers l'ancien site (D5), liens internes entre fragments ==== -->

  <xsl:template name="person-href">
    <xsl:param name="pid"/>
    <xsl:text>?refId=index-personnes</xsl:text>
    <xsl:if test="$pid != ''"><xsl:text>#</xsl:text><xsl:value-of select="$pid"/></xsl:if>
  </xsl:template>

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
        <xsl:text>?refId=sources-et-bibliographie#</xsl:text>
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
    <a href="?refId={substring-after(@target, '#')}"><xsl:apply-templates/></a>
  </xsl:template>

  <xsl:template name="dl-href">
    <xsl:text>?refId=</xsl:text>
    <xsl:choose>
      <xsl:when test="@corresp">
        <xsl:value-of select="substring-after(@corresp, '#')"/>
        <xsl:text>#</xsl:text>
        <xsl:value-of select="substring-after(@target, '#')"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="substring-after(@target, '#')"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="dl-index-complet" xmlns:dl="urn:delescluze:xsl">
    <xsl:param name="lettres" select="tei:div[@type = 'index-lettre']"/>
    <xsl:variable name="personnes" select="$lettres//tei:person"/>
    <xsl:variable name="uca" select="'http://www.w3.org/2013/collation/UCA?lang=fr;strength=primary'"/>
    <div class="dl-index dl-index-complet tf-cadre">
      <xsl:call-template name="tf-barre">
        <xsl:with-param name="total" select="count($personnes)"/>
        <xsl:with-param name="unite" select="'personnes'"/>
      </xsl:call-template>
      <table class="tf-tableau dl-tableau" data-csv-nom="delescluze-personnes" data-csv-entetes="Nom|Dates|Fonction|Notice|Mentions">
        <caption class="tf-legende">Cliquer sur un en-tête de colonne pour trier (un second clic inverse l’ordre).</caption>
        <thead>
          <tr>
            <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'dl-c-nom'"/><xsl:with-param name="libelle" select="'Nom'"/></xsl:call-template>
            <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'dl-c-dates'"/><xsl:with-param name="libelle" select="'Dates'"/><xsl:with-param name="numerique" select="true()"/></xsl:call-template>
            <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'dl-c-fonction'"/><xsl:with-param name="libelle" select="'Fonction'"/></xsl:call-template>
            <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'dl-c-notice'"/><xsl:with-param name="libelle" select="'Notice'"/></xsl:call-template>
            <xsl:call-template name="tf-th"><xsl:with-param name="classe" select="'dl-c-mentions'"/><xsl:with-param name="libelle" select="'Mentions'"/><xsl:with-param name="numerique" select="true()"/></xsl:call-template>
          </tr>
          <tr class="tf-filtres">
            <xsl:call-template name="tf-filtre"><xsl:with-param name="col" select="0"/><xsl:with-param name="libelle" select="'Nom'"/><xsl:with-param name="liste" select="'dl-personnes-noms'"/><xsl:with-param name="suggestions" select="sort(distinct-values($personnes/tei:persName[1] ! normalize-space(replace(., '\s*\([^)]*\)\s*$', ''))), $uca)"/></xsl:call-template>
            <xsl:call-template name="tf-filtre"><xsl:with-param name="col" select="1"/><xsl:with-param name="libelle" select="'Dates'"/></xsl:call-template>
            <xsl:call-template name="tf-filtre"><xsl:with-param name="col" select="2"/><xsl:with-param name="libelle" select="'Fonction'"/></xsl:call-template>
            <xsl:call-template name="tf-filtre"><xsl:with-param name="col" select="3"/><xsl:with-param name="libelle" select="'Notice'"/></xsl:call-template>
            <xsl:call-template name="tf-filtre"><xsl:with-param name="col" select="4"/><xsl:with-param name="libelle" select="'Mentions'"/><xsl:with-param name="type" select="'liste'"/><xsl:with-param name="options" select="('Carnet 1', 'Carnet 2', 'Introduction', 'Lettres', 'Passages rédigés')"/></xsl:call-template>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="$personnes">
            <xsl:variable name="nom" select="normalize-space(tei:persName[1])"/>
            <xsl:variable name="vedette" select="replace($nom, '\s*\([^)]*\)\s*$', '')"/>
            <xsl:variable name="dates" select="if (matches($nom, '\([^)]*\)\s*$')) then replace($nom, '^.*\(([^)]*)\)\s*$', '$1') else ''"/>
            <xsl:variable name="annee" select="if (matches($dates, '[0-9]{4}')) then replace($dates, '^[^0-9]*?([0-9]{4}).*$', '$1') else ''"/>
            <xsl:variable name="fonction" select="normalize-space(string-join(tei:occupation, ' ; '))"/>
            <xsl:variable name="listes" select="tei:listRef[@type = 'linksToEdition']"/>
            <xsl:variable name="mentions" select="$listes[not(starts-with(tei:ref[@type = 'groupe'][1]/@target, '#passage'))]/tei:ref[not(@type = 'groupe')]"/>
            <xsl:variable name="sources" select="distinct-values($listes ! dl:source(.))"/>
            <tr id="{@xml:id}" data-o="{position()}">
              <td class="dl-c-nom" data-sort="{$vedette}" data-f="{tf:plat(string-join(($vedette, tei:note[@type = 'localNames']), ' '))}" data-csv="{$vedette}">
                <span class="dl-fiche-vedette"><xsl:value-of select="$vedette"/></span>
                <xsl:for-each select="tei:note[@type = 'localNames']">
                  <span class="dl-fiche-formes"><span class="dl-etiquette">Formes du nom : </span><xsl:apply-templates/></span>
                </xsl:for-each>
              </td>
              <td class="dl-c-dates" data-sort="{$annee}" data-f="{tf:plat($dates)}">
                <xsl:choose>
                  <xsl:when test="$dates != ''"><xsl:value-of select="$dates"/></xsl:when>
                  <xsl:otherwise><span class="tf-vide">—</span></xsl:otherwise>
                </xsl:choose>
              </td>
              <td class="dl-c-fonction" data-sort="{$fonction}" data-f="{tf:plat($fonction)}">
                <xsl:choose>
                  <xsl:when test="$fonction != ''"><xsl:value-of select="$fonction"/></xsl:when>
                  <xsl:otherwise><span class="tf-vide">—</span></xsl:otherwise>
                </xsl:choose>
              </td>
              <xsl:variable name="autorites" select="tei:idno[@type = ('BNF', 'ISNI', 'IDREF', 'url')][normalize-space(@corresp) or starts-with(normalize-space(.), 'http')]"/>
              <td class="dl-c-notice" data-sort="{normalize-space(string-join(tei:note[@type = 'biography'], ' '))}" data-f="{tf:plat(string-join(tei:note[@type = ('biography', 'seeAlso')], ' '))}" data-csv="{normalize-space(string-join(tei:note[@type = 'biography'], ' '))}">
                <xsl:choose>
                  <xsl:when test="tei:note[@type = ('biography', 'seeAlso')] or $autorites">
                    <div class="dl-notice-texte">
                      <xsl:for-each select="tei:note[@type = 'biography']">
                        <p class="dl-fiche-bio"><xsl:apply-templates/></p>
                      </xsl:for-each>
                    </div>
                    <xsl:if test="string-length(normalize-space(string-join(tei:note[@type = 'biography'], ' '))) gt 300">
                      <details class="dl-suite"><summary><span class="dl-suite-plus">Lire la suite</span><span class="dl-suite-moins">Réduire</span></summary></details>
                    </xsl:if>
                    <xsl:apply-templates select="tei:note[@type = 'seeAlso']"/>
                    <xsl:if test="$autorites">
                      <p class="dl-fiche-autorites">
                        <span class="dl-etiquette">Autorités : </span>
                        <xsl:for-each select="$autorites">
                          <xsl:if test="position() gt 1"><span class="dl-sep"> · </span></xsl:if>
                          <a href="{if (normalize-space(@corresp)) then normalize-space(@corresp) else normalize-space(.)}" target="_blank" rel="noopener">
                            <xsl:value-of select="if (@type = 'BNF') then 'BnF' else if (@type = 'IDREF') then 'IdRef' else if (@type = 'url') then 'Lien' else @type"/>
                          </a>
                        </xsl:for-each>
                      </p>
                    </xsl:if>
                  </xsl:when>
                  <xsl:otherwise><span class="tf-vide">—</span></xsl:otherwise>
                </xsl:choose>
              </td>
              <td class="dl-c-mentions" data-sort="{count($mentions)}" data-f="{tf:plat(string-join($sources, ' ; '))}" data-csv="{string-join(for $l in $listes return concat(normalize-space($l/tei:ref[@type = 'groupe'][1]), ' : ', string-join($l/tei:ref[not(@type = 'groupe')] ! normalize-space(.), ', ')), ' ; ')}">
                <xsl:choose>
                  <xsl:when test="count($listes/tei:ref[not(@type = 'groupe')]) gt 5">
                    <details class="dl-mentions-replie">
                      <summary><xsl:value-of select="concat(count($mentions), if (count($mentions) = 1) then ' mention' else ' mentions', ' · ', string-join($sources, ', '))"/></summary>
                      <xsl:call-template name="dl-mentions"><xsl:with-param name="listes" select="$listes"/></xsl:call-template>
                    </details>
                  </xsl:when>
                  <xsl:when test="$listes"><xsl:call-template name="dl-mentions"><xsl:with-param name="listes" select="$listes"/></xsl:call-template></xsl:when>
                  <xsl:otherwise><span class="tf-vide">—</span></xsl:otherwise>
                </xsl:choose>
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <!-- Mentions d'une personne : par carnet (avec les passages rédigés qui citent ce carnet),
       puis lettres et autres sources ; repris des fiches du 2026-10-07. -->
  <xsl:template name="dl-mentions">
    <xsl:param name="listes"/>
    <dl class="dl-fiche-mentions">
      <xsl:for-each select="$listes[starts-with(tei:ref[@type = 'groupe'][1]/@target, '#carnet')]">
        <xsl:variable name="carnet" select="normalize-space(tei:ref[@type = 'groupe'][1])"/>
        <dt><xsl:value-of select="$carnet"/></dt>
        <dd>
          <xsl:for-each select="tei:ref[not(@type = 'groupe')]">
            <xsl:if test="position() gt 1"><span class="dl-sep">, </span></xsl:if>
            <a><xsl:attribute name="href"><xsl:call-template name="dl-href"/></xsl:attribute>
              <xsl:value-of select="replace(normalize-space(.), '^page ', 'p.&#160;')"/></a>
          </xsl:for-each>
          <xsl:variable name="passages" select="$listes[starts-with(tei:ref[@type = 'groupe'][1]/@target, '#passage')]
              [some $r in tei:ref[not(@type = 'groupe')] satisfies starts-with(normalize-space($r), concat($carnet, ','))]"/>
          <xsl:for-each select="$passages">
            <span class="dl-passage">
              <xsl:text> — </xsl:text>
              <a><xsl:attribute name="href"><xsl:for-each select="tei:ref[@type = 'groupe'][1]"><xsl:call-template name="dl-href"/></xsl:for-each></xsl:attribute>
                <xsl:value-of select="normalize-space(tei:ref[@type = 'groupe'][1])"/></a>
            </span>
          </xsl:for-each>
        </dd>
      </xsl:for-each>
      <xsl:for-each select="$listes[not(starts-with(tei:ref[@type = 'groupe'][1]/@target, '#carnet') or starts-with(tei:ref[@type = 'groupe'][1]/@target, '#passage'))]">
        <xsl:variable name="g" select="tei:ref[@type = 'groupe'][1]"/>
        <dt>
          <xsl:choose>
            <xsl:when test="starts-with($g/@target, '#lettre')">Lettre</xsl:when>
            <xsl:otherwise><xsl:value-of select="normalize-space($g)"/></xsl:otherwise>
          </xsl:choose>
        </dt>
        <dd>
          <xsl:if test="starts-with($g/@target, '#lettre')">
            <a><xsl:attribute name="href"><xsl:for-each select="$g"><xsl:call-template name="dl-href"/></xsl:for-each></xsl:attribute>
              <xsl:value-of select="normalize-space($g)"/></a>
            <xsl:text> : </xsl:text>
          </xsl:if>
          <xsl:for-each select="tei:ref[not(@type = 'groupe')]">
            <xsl:if test="position() gt 1"><span class="dl-sep">, </span></xsl:if>
            <a><xsl:attribute name="href"><xsl:call-template name="dl-href"/></xsl:attribute>
              <xsl:value-of select="replace(normalize-space(.), '^[Pp]age ', 'p.&#160;')"/></a>
          </xsl:for-each>
        </dd>
      </xsl:for-each>
    </dl>
  </xsl:template>

  <xsl:template match="tei:person/tei:note[@type = 'seeAlso']" priority="25">
    <xsl:variable name="see" select="tei:ref[starts-with(@target, '#person')]"/>
    <xsl:choose>
      <xsl:when test="$see">
        <p class="seeAlso crossReferences">
          <xsl:text>Voir aussi : </xsl:text>
          <xsl:for-each select="$see">
            <xsl:if test="position() &gt; 1"><xsl:text> ; </xsl:text></xsl:if>
            <!-- tf-voir : la ligne visée du tableau est placée sous l'en-tête collant et surlignée -->
            <a class="tf-voir">
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
</xsl:transform>
