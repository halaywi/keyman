<?xml version="1.0" encoding="utf-16"?>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="base.xslt" />

  <xsl:output method="html" encoding="utf-16" />

  <xsl:template match="/">
    <html>
      <xsl:call-template name="head" />
      <body>
        <table>
          <thead>
            <tr>
              <th></th>
              <th>Filename</th>
              <th>Folder</th>
              <th>Company</th>
              <th>Product</th>
              <th>Version</th>
              <th>File Description</th>
            </tr>
          </thead>
          <tbody>
            <xsl:apply-templates select="//Process" />
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>

<xsl:template match="//Process">
  <tr class="Process">
    <td class="expand" onclick="ExpandModules(this)"><span>+</span></td>
    <td><xsl:value-of select="FileName"/></td>
    <td><xsl:value-of select="Folder"/></td>
    <td><xsl:value-of select="VersionCompanyName"/></td>
    <td><xsl:value-of select="VersionProductName"/></td>
    <td><xsl:value-of select="VersionProductVersion"/></td>
    <td><xsl:value-of select="VersionFileDescription"/></td>
  </tr>
  <xsl:apply-templates select="Module" />
</xsl:template>

<xsl:template match="Module">
  <tr class="Module">
    <td></td>
    <td><xsl:value-of select="FileName"/></td>
    <td><xsl:value-of select="Folder"/></td>
    <td><xsl:value-of select="VersionCompanyName"/></td>
    <td><xsl:value-of select="VersionProductName"/></td>
    <td><xsl:value-of select="VersionProductVersion"/></td>
    <td><xsl:value-of select="VersionFileDescription"/></td>
  </tr>
</xsl:template>

</xsl:stylesheet> 
