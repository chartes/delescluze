<?xml version="1.0" encoding="UTF-8"?>
<!-- Page de titre de Delescluze (route /api/dts/cover?id=delescluze), sur le modèle de celle de
     Christofle. Écarts marqués [delescluze]. -->
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="tei">

  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="yes"/>

  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" lang="fr">
      <div id="aside">to delete</div>
      <div id="center">
        <div id="main">
          <div id="article"><xsl:apply-templates select="//tei:fileDesc/tei:titleStmt"/></div>
        </div>
      </div>
    </html>
  </xsl:template>

  <xsl:template match="tei:titleStmt">
    <div class="titlestmt">
      <!-- Premier titre uniquement (le titre court type="short" n'est pas affiché) -->
      <h1 class="head">
        <xsl:value-of select="normalize-space(tei:title[not(@type)][1])"/>
      </h1>

      <!-- Éditeur : le <principal> (texte seul, sans persName dans ce TEI). -->
      <xsl:if test="tei:principal">
        <p class="editors">
          <span class="editors-label">Édité par </span>
          <xsl:for-each select="tei:principal">
            <span class="editor">
              <xsl:value-of select="normalize-space(.)"/>
            </span>
          </xsl:for-each>
        </p>
      </xsl:if>

      <!-- [delescluze] Édition électronique : le respStmt « encodage XML/TEI » (Natalia Pashkeeva,
           sous la direction et avec l'aide de Florence Clavaud). Le nom est repris tel quel du
           <name> : il contient la direction. -->
      <xsl:for-each select="tei:respStmt[matches(normalize-space(tei:resp), 'encodage XML/TEI')]/tei:name">
        <p class="editors">
          <span class="editors-label">Édition électronique par </span>
          <span class="editor">
            <xsl:value-of select="normalize-space(.)"/>
          </span>
        </p>
      </xsl:for-each>

      <!-- publicationStmt/date vaut « 2015 » : on n'affiche que l'année. -->
      <span class="date">
        <xsl:value-of select="replace(normalize-space(../tei:publicationStmt/tei:date[1]), '^\D*(\d{4}).*$', '$1')"/>
      </span>
    </div>
  </xsl:template>

</xsl:transform>
