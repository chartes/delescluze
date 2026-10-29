<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="1.1"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:epub="http://www.idpf.org/2007/ops"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tf="urn:elec:tableau-filtrable"
  xmlns:dl="urn:delescluze:xsl"
  xmlns:bib="urn:elec:bibliographie"
  exclude-result-prefixes="tei epub xs tf dl bib">
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
  <xsl:import href="bibliographie.xsl"/><!-- bibliographies : module commun (2026-10-15) -->

  <xsl:output indent="no"/>

  <xsl:variable name="accents-from">àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ</xsl:variable>

  <xsl:variable name="accents-to">aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY</xsl:variable>

  <!-- Index des personnes en liste, sur le modèle des index des cartulaires (2026-10-27 ; remplace
       le tableau triable et filtrable du 2026-10-13) : une entrée par personne, @xml:id gardé en
       ancre (?refId=index-personnes#personX). Vedette en petites capitales (CSS), dates, fonction,
       formes du nom, notice, autorités, mentions (liens par carnet, lettre, passage). Styles :
       delescluze.customCss.css, bloc « INDEX DES PERSONNES EN LISTE ». -->
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

  <!-- Bibliographie : module générique bibliographie.xsl (2026-10-15). Écart Delescluze, repris de
       l'ancienne page : dans « Sources », les cotes d'archives sont rangées en « Sources
       manuscrites » par dépôt (préfixe de leur xml:id), puis viennent les « Sources imprimées ». -->
  <xsl:variable name="dl-depots" select="('nationalArchives', 'nationalLibraryFrance', 'institutFrance', 'municipalLibraryLille', 'departementArchivesMorbihan', 'departementArchivesRhone', 'rgaspiMoscou')"/>
  <xsl:variable name="dl-noms-depots" select="('Archives nationales', 'Bibliothèque nationale de France', 'Bibliothèque de l’Institut de France', 'Bibliothèque municipale de Lille', 'Archives départementales du Morbihan', 'Archives départementales du Rhône', 'Archives d’État russes d’histoire sociale et politique (RGASPI), Moscou')"/>

  <xsl:template match="tei:listBibl[tei:head][tei:bibl[replace(@xml:id, '\d+$', '') = $dl-depots]]" priority="10">
    <xsl:variable name="fonds" select="tei:bibl[replace(@xml:id, '\d+$', '') = $dl-depots]"/>
    <details class="biblio" open="open">
      <xsl:if test="@xml:id"><xsl:attribute name="id" select="@xml:id"/></xsl:if>
      <summary>
        <h2 class="head biblio-rubrique"><xsl:apply-templates select="tei:head[1]/node()"/><xsl:text> </xsl:text><span class="biblio-compte">(<xsl:value-of select="count(.//tei:bibl)"/>)</span></h2>
      </summary>
      <xsl:call-template name="dl-rubrique">
        <xsl:with-param name="titre">Sources manuscrites</xsl:with-param>
        <xsl:with-param name="niveau" select="3"/>
        <xsl:with-param name="bibl" select="$fonds"/>
        <xsl:with-param name="par-depot" select="true()"/>
      </xsl:call-template>
      <xsl:call-template name="dl-rubrique">
        <xsl:with-param name="titre">Sources imprimées</xsl:with-param>
        <xsl:with-param name="niveau" select="3"/>
        <xsl:with-param name="bibl" select="tei:bibl except $fonds"/>
      </xsl:call-template>
      <xsl:apply-templates select="* except (tei:head[1], tei:bibl)"/>
    </details>
  </xsl:template>

  <xsl:template name="dl-rubrique">
    <xsl:param name="titre"/>
    <xsl:param name="niveau"/>
    <xsl:param name="bibl"/>
    <xsl:param name="par-depot" select="false()"/>
    <xsl:param name="annees" select="true()"/>
    <xsl:if test="$bibl">
      <details class="biblio" open="open">
        <summary>
          <xsl:element name="h{$niveau}">
            <xsl:attribute name="class">head biblio-rubrique</xsl:attribute>
            <xsl:value-of select="$titre"/><xsl:text> </xsl:text><span class="biblio-compte">(<xsl:value-of select="count($bibl)"/>)</span>
          </xsl:element>
        </summary>
        <xsl:choose>
          <xsl:when test="$par-depot">
            <xsl:for-each-group select="$bibl" group-by="replace(@xml:id, '\d+$', '')">
              <xsl:call-template name="dl-rubrique">
                <xsl:with-param name="titre" select="$dl-noms-depots[index-of($dl-depots, current-grouping-key())[1]]"/>
                <xsl:with-param name="niveau" select="$niveau + 1"/>
                <xsl:with-param name="bibl" select="current-group()"/>
                <!-- pas d'année à droite d'une cote : « BB/18/1488 » n'est pas une date -->
                <xsl:with-param name="annees" select="false()"/>
              </xsl:call-template>
            </xsl:for-each-group>
          </xsl:when>
          <xsl:otherwise>
            <ul class="listBibl biblio-liste">
              <xsl:for-each select="$bibl">
                <li class="bibl">
                  <xsl:if test="@xml:id"><xsl:attribute name="id" select="@xml:id"/></xsl:if>
                  <span class="bibl-texte"><xsl:apply-templates select="." mode="biblio-texte"/></span>
                  <xsl:variable name="annee" select="if ($annees) then bib:annee(.) else ()"/>
                  <xsl:if test="$annee"><span class="bibl-annee"><xsl:value-of select="$annee"/></span></xsl:if>
                </li>
              </xsl:for-each>
            </ul>
          </xsl:otherwise>
        </xsl:choose>
      </details>
    </xsl:if>
  </xsl:template>

  <!-- Cote d'archives en tête de la notice (« 494AP/1 : Fonds… »), comme sur l'ancienne page. -->
  <xsl:template match="tei:bibl[replace(@xml:id, '\d+$', '') = $dl-depots]" mode="biblio-texte">
    <xsl:variable name="t" select="normalize-space(.)"/>
    <xsl:choose>
      <xsl:when test="matches($t, '^.+?[\s&#160;]:[\s&#160;]')">
        <span class="biblio-cote"><xsl:value-of select="replace($t, '^(.+?)[\s&#160;]+:[\s&#160;].*$', '$1', 's')"/></span>
        <xsl:text>&#160;: </xsl:text>
        <xsl:value-of select="replace($t, '^.+?[\s&#160;]+:[\s&#160;]+(.*)$', '$1', 's')"/>
      </xsl:when>
      <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="tei:p[contains(., 'apparat bibliographique encodé')]" priority="45"/>

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

  <!-- Renvois internes du texte : ref target="#carnet1-page001" corresp="#carnet1" (602 cas),
       ref target="#index-personnes-A" (361), ref target="#personDelescluzeCharles" (10).
       hteiml les rendait en <a> sans href — bleus et non cliquables, ce que la relecture du
       2026-10-29 a signalé sur introduction-partie-4-3 (« référence affichage bibliographie
       bizarre »). Lien réel quand la ressource visée est connue (@corresp, ou l'index des
       personnes, seule ressource dont les ancres ne portent pas le préfixe du document) ;
       simple texte sinon. -->
  <xsl:template match="tei:ref[starts-with(@target, '#')][not(@type = 'bibl')]" priority="24">
    <xsl:variable name="cible" select="substring-after(@target, '#')"/>
    <!-- Les ancres de l'ancien menu alphabétique de l'index (index-personnes-A, -B…) n'existent plus :
         « Index des personnes » est reconstruit par dl-index-complet. On renvoie alors à la page. -->
    <xsl:variable name="ancre" select="if (starts-with($cible, 'index-personnes-')) then 'index-personnes' else $cible"/>
    <xsl:variable name="ressource">
      <xsl:choose>
        <xsl:when test="@corresp"><xsl:value-of select="substring-after(@corresp, '#')"/></xsl:when>
        <xsl:when test="starts-with($cible, 'index-personnes') or starts-with($cible, 'person')">index-personnes</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="string($ressource) != ''">
        <a class="dl-renvoi" href="?refId={$ressource}#{$ancre}"><xsl:apply-templates/></a>
      </xsl:when>
      <xsl:otherwise>
        <span class="dl-renvoi"><xsl:apply-templates/></span>
      </xsl:otherwise>
    </xsl:choose>
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
    <div class="dl-index dl-index-complet">
      <ul class="dl-personnes">
        <xsl:for-each select="$personnes">
          <xsl:variable name="nom" select="normalize-space(tei:persName[1])"/>
          <xsl:variable name="vedette" select="replace($nom, '\s*\([^)]*\)\s*$', '')"/>
          <xsl:variable name="dates" select="if (matches($nom, '\([^)]*\)\s*$')) then replace($nom, '^.*\(([^)]*)\)\s*$', '$1') else ''"/>
          <xsl:variable name="fonction" select="normalize-space(string-join(tei:occupation, ' ; '))"/>
          <xsl:variable name="listes" select="tei:listRef[@type = 'linksToEdition']"/>
          <xsl:variable name="autorites" select="tei:idno[@type = ('BNF', 'ISNI', 'IDREF', 'url')][normalize-space(@corresp) or starts-with(normalize-space(.), 'http')]"/>
          <li id="{@xml:id}" class="dl-personne">
            <span class="dl-fiche-vedette"><xsl:value-of select="$vedette"/></span>
            <xsl:if test="$dates != ''"><span class="dl-fiche-dates"> (<xsl:value-of select="$dates"/>)</span></xsl:if>
            <xsl:if test="$fonction != ''"><span class="dl-fiche-fonction">, <xsl:value-of select="$fonction"/></span></xsl:if>
            <xsl:for-each select="tei:note[@type = 'localNames']">
              <span class="dl-fiche-formes"><span class="dl-etiquette">Formes du nom : </span><xsl:apply-templates/></span>
            </xsl:for-each>
            <xsl:if test="tei:note[@type = ('biography', 'seeAlso')] or $autorites">
              <div class="dl-fiche-corps">
                <xsl:for-each select="tei:note[@type = 'biography']">
                  <p class="dl-fiche-bio"><xsl:apply-templates/></p>
                </xsl:for-each>
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
              </div>
            </xsl:if>
            <xsl:if test="$listes">
              <div class="dl-personne-mentions">
                <xsl:call-template name="dl-mentions"><xsl:with-param name="listes" select="$listes"/></xsl:call-template>
              </div>
            </xsl:if>
          </li>
        </xsl:for-each>
      </ul>
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
