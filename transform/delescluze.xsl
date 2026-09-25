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
    <div class="facsimile">
      <xsl:if test="@xml:id"><xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute></xsl:if>
      <xsl:apply-templates select="tei:graphic"/>
      <xsl:if test=".//tei:ptr[@type = 'viewer'][@target]">
        <p class="viewer-link">
          <a href="{(.//tei:ptr[@type = 'viewer'])[1]/@target}" target="_blank" rel="noopener">
            <xsl:text>Voir dans la salle des inventaires virtuelle</xsl:text>
          </a>
        </p>
      </xsl:if>
    </div>
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

  <xsl:template match="tei:list[@type = 'lettres-index']" priority="20">
    <nav class="lettres-index">
      <xsl:apply-templates/>
    </nav>
  </xsl:template>

  <xsl:template match="tei:list[@type = 'lettres-index']/tei:item" priority="20">
    <xsl:apply-templates/>
    <xsl:text> </xsl:text>
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
       (libellés identiques au texte TEI, cibles relevées sur l'ancien site). -->
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

  <xsl:variable name="accents-from">àáâãäåçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ</xsl:variable>
  <xsl:variable name="accents-to">aaaaaaceeeeiiiinooooouuuuyAAAAAACEEEEIIIINOOOOOUUUUY</xsl:variable>


  <!-- Lettre d'index d'une notice : premiere lettre du nom, sans accent, en capitale.
       Le fragment d'une notice ne contient pas la division de sa lettre ; le nom, lui, y est. -->
  <xsl:template name="dl-lettre-index">
    <xsl:text>index-personnes-</xsl:text>
    <xsl:value-of select="translate(
      substring(translate(normalize-space(tei:persName[1]), $accents-from, $accents-to), 1, 1),
      'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
  </xsl:template>

</xsl:transform>
