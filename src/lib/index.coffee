VERSION = '0.0.0'

fs = require('fs')
path = require('path')
exec = require('child_process').exec
program = require('commander')
#markdown = require( "markdown" ).markdown
marked = require('marked')
cheerio = require("cheerio")
mustache = require('mustache')
sqwish = require('sqwish')

marked.setOptions
  breaks: true # Use Github-flavored-markdown (GFM) which uses linebreaks differently

# Method to concatenate a bunch of CSS files
concatCss = (files) ->
  ret = ""

  for file in files
    contents = fs.readFileSync path.join('assets', 'css', file), 'utf8'
    ret += contents

  return ret

# Executable options
program
  .version(VERSION)
  .usage('[options] [source markdown file]')
  .option('--pdf', 'Include PDF output')
  .option('-t, --template <template>', 'Specify the template html file', )
  .parse(process.argv);

# Filename
sourceFile = program.args[0]

# Make sure the source file exists
if !sourceFile?
  console.log "No source file specified"
  process.exit()

# Load the template file
template = fs.readFileSync path.join('assets', 'templates', 'default.html'), 'utf8'

# Get the list of css asset files
cssFiles = fs.readdirSync path.join('assets', 'css')

# Load in all the stylesheets
rawstyle = concatCss(cssFiles)

# Minify the css
style = sqwish.minify(rawstyle)

# Read the file contents in 
input = fs.readFileSync sourceFile, 'utf8'

# Convert the file to HTML
resume = marked(input)

#console.log resume
#process.exit()

# Get the title of the document
$ = cheerio.load(resume)
title = $('h1').first().text() + ' | ' + $('h2').first().text()

# Use mustache to turn the generated html into a pretty document with Mustache
rendered = mustache.render template,
  title  : title
  style  : style
  resume : resume
  nopdf  : !program.pdf

#console.log rendered
#process.exit()

# Get the basename of the source file
sourceFileBasename = path.basename sourceFile, path.extname(sourceFile)

# Make the output filename
outputFileName = path.join('output', sourceFileBasename + '.html')

# Write the file contents
fs.writeFileSync outputFileName, rendered

console.log "Wrote html to: #{outputFileName}"

# Write the PDF if we're told to
if program.pdf
  pdfOutputFilename = path.join('output', sourceFileBasename + '.pdf')
  pdfRendered = rendered.replace('body class=""', 'body class="pdf"')
  pdfSource = path.join('output', sourceFileBasename + '-pdf.html')
  fs.writeFileSync pdfSource, pdfRendered

  exec 'wkhtmltopdf ' + pdfSource + ' ' + pdfOutputFilename, (err, stdout, stderr) ->
    if err?
      console.log "Error writing pdf: #{err}"
    else
      console.log "Wrote pdf to #{pdfOutputFilename}"

    fs.unlink pdfSource

    