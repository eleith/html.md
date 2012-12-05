# [html.md](http://neocotic.com/html.md) 1.0.0  
# (c) 2012 Alasdair Mercer  
# Freely distributable under the MIT license.  
# Based on [Make.text](http://homepage.mac.com/tjim/) 1.5  
# (c) 2007 Trevor Jim  
# Licensed under the GPL Version 2 license.  
# For all details and documentation:  
# <http://neocotic.com/html.md>

# Private constants
# -----------------

# Default option values.
DEFAULT_OPTIONS = debug: off
# Save the previous value of the `md` variable.
PREVIOUS_MD = window.md
# Replacement strings for special Markdown characters.
REPLACEMENTS =
  '\\\\':              '\\\\'
  '\\[':               '\\['
  '\\]':               '\\]'
  '>':                 '\\>'
  '_':                 '\\_'
  '\\*':               '\\*'
  '`':                 '\\`'
  '#':                 '\\#'
  '([0-9])\\.(\\s|$)': '$1\\.$2'
  '\u00a9':            '(c)'
  '\u00ae':            '(r)'
  '\u2122':            '(tm)'
  '\u00a0':            ' '
  '\u00b7':            '\\*'
  '\u2002':            ' '
  '\u2003':            ' '
  '\u2009':            ' '
  '\u2018':            '\''
  '\u2019':            '\''
  '\u201c':            '"'
  '\u201d':            '"'
  '\u2026':            '...'
  '\u2013':            '--'
  '\u2014':            '---'
# Regular expression to identify elements to be generally ignored along with
# their children.
R_IGNORE_CHILDREN = /// ^ (
    APPLET
  | AREA
  | AUDIO
  | BUTTON
  | CANVAS
  | COMMAND
  | DATALIST
  | EMBED
  | HEAD
  | INPUT
  | KEYGEN
  | MAP
  | MENU
  | METER
  | NOFRAMES
  | NOSCRIPT
  | OBJECT
  | OPTION
  | PARAM
  | PROGRESS
  | SCRIPT
  | SELECT
  | SOURCE
  | STYLE
  | TEXTAREA
  | TRACK
  | VIDEO
) $ ///
# Regular expression to identify elements to be parsed simply as paragraphs.
R_PARAGRAPH_ONLY = /// ^ (
    ADDRESS
  | ARTICLE
  | ASIDE
  | DIV
  | FOOTER
  | HEADER
  | P
  | SECTION
) $ ///
# Create regular expressions for all of the special Markdown characters.
REGEX = (
  result = {}
  for own key, value of REPLACEMENTS
    result[key] = new RegExp key, 'g'
  result
)

# Try to ensure Node is available with the required constants.
Node = window.Node ? {}
Node.ELEMENT_NODE ?= 1
Node.TEXT_NODE ?= 3

# Parses HTML code/elements into valid Markdown.
# Elements are parsed recursively, meaning their children are also parsed.
class HtmlParser

  # Creates a new `HtmlParser` for the arguments provided.
  constructor: (@html = '', @options = {}) ->
    @atLeft = @atNoWS = @atP = yes
    @buffer = ''
    @exceptions = @links = @linkTitles = []
    @inCode = @inPre = @inOrderedList = @parsed = no
    @last = null
    @left = '\n'
    @linkCache = @unhandled = {}
    @options = {} if typeof @options isnt 'object'
    for own key, defaultValue of DEFAULT_OPTIONS
      @options[key] = defaultValue unless @options.hasOwnProperty key

  # Append `str` to the buffer string.
  append: (str) ->
    @buffer += @last if @last?
    @last = str;

  # Append a Markdown line break to the buffer string.
  br: ->
    @append "  #{@left}"
    @atLeft = @atNoWS = yes

  # Prepare the parser for a `code` element.
  code: ->
    old = @inCode
    @inCode = yes
    => @inCode = old

  # Replace any special characters that can cause problems within code.
  inCodeProcess: (str) ->
    str.replace /`/g, '\\`'

  # Replace any special characters that can cause problems in normal Markdown.
  nonPreProcess: (str) ->
    str = str.replace /\n([ \t]*\n)+/g, '\n'
    str = str.replace /\n[ \t]+/g, '\n'
    str = str.replace /[ \t]+/g, ' '
    for own key, value of REPLACEMENTS
      str = str.replace REGEX[key], value
    str

  # Prepare the parser for an `ol` element.
  ol: ->
    old = @inOrderedList
    @inOrderedList = yes
    => @inOrderedList = old

  # Append `str` to the buffer string while keeping the parser in context.
  output: (str) ->
    return unless str
    unless @inPre
      if @atNoWS
        str = str.replace /^[ \t\n]+/, ''
      else if /^[ \t]*\n/.test str
        str = str.replace /^[ \t\n]+/, '\n'
      else
        str = str.replace /^[ \t]+/, ' '
    return if str is ''
    @atP = /\n\n$/.test str
    @atLeft = /\n$/.test str
    @atNoWS = /[ \t\n]$/.test str
    @append str.replace /\n/g, @left

  # Create a function that can be called later to append `str` to the buffer
  # string while keeping the parser in context.
  outputLater: (str) ->
    => @output str

  # Append a Markdown paragraph to the buffer string.
  p: ->
    return if @atP
    unless @atLeft
      @append @left
      @atLeft = yes
    @append @left
    @atNoWS = @atP = yes

  # Parse the HTML into valid Markdown.
  parse: ->
    return '' unless @html
    return @buffer if @parsed
    container = document.createElement 'div'
    if typeof @html is 'string'
      container.innerHTML = @html
    else
      container.appendChild @html
    @process container
    @append '\n\n'
    for link, i in @links
      do (link, i) =>
        title = if @linkTitles[i] then " \"#{@linkTitles[i]}\"\n" else '\n'
        @append "[#{i}]: #{link}#{title}" if link
    if @options.debug
      unhandledTags = (tag for own tag of @unhandled).sort()
      if unhandledTags.length
        console.log """
          Ignored tags;
          #{unhandledTags.join ', '}
        """
      else
        console.log 'No tags were ignored'
      console.log @exceptions.join '\n' if @exceptions.length
    @append ''
    @parsed = yes
    @buffer = @buffer.trim()

  # Prepare the parser for a `pre` element.
  pre: ->
    old = @inPre
    @inPre = yes
    => @inPre = old

  # Parse the specified element and append the generated Markdown to the buffer
  # string.
  process: (ele) ->
    if getComputedStyle?
      try
        style = getComputedStyle ele, null
        return if style?.getPropertyValue?('display') is 'none'
      catch err
        @thrown err, 'getComputedStyle'
    if ele.nodeType is Node.ELEMENT_NODE
      skipChildren = no
      try
        if R_IGNORE_CHILDREN.test ele.tagName
          skipChildren = yes
        else if /^H[1-6]$/.test ele.tagName
          level = parseInt ele.tagName.match(/([1-6])$/)[1]
          @p()
          @output "#{('#' for i in [1..level]).join ''} "
        else if R_PARAGRAPH_ONLY.test ele.tagName
          @p()
        else
          switch ele.tagName
            when 'BODY', 'FORM' then break
            when 'DETAILS'
              @p()
              unless ele.getAttribute('open')?
                skipChildren = yes
                summary = ele.getElementsByTagName('summary')[0]
                @process summary if summary
            when 'BR' then @br()
            when 'HR'
              @p()
              @output '--------------------------------'
              @p()
            when 'CITE', 'DFN', 'EM', 'I', 'U', 'VAR'
              @output '_'
              @atNoWS = yes
              after = @outputLater '_'
            when 'DT', 'B', 'STRONG'
              @p() if ele.tagName is 'DT'
              @output '**'
              @atNoWS = yes
              after = @outputLater '**'
            when 'Q'
              @output '"'
              @atNoWS = yes
              after = @outputLater '"'
            when 'OL', 'PRE', 'UL'
              after1 = @pushLeft '    '
              after2 = switch ele.tagName
                when 'OL' then @ol()
                when 'PRE' then @pre()
                when 'UL' then @ul()
              after = ->
                after1()
                after2()
            when 'LI'
              @replaceLeft if @inOrderedList then '1.  ' else '*   '
            when 'CODE', 'KBD', 'SAMP'
              unless @inPre
                @output '`'
                after1 = @code()
                after2 = @outputLater '`'
                after = ->
                  after1()
                  after2()
            when 'BLOCKQUOTE', 'DD' then after = @pushLeft '> '
            when 'A'
              break unless ele.href
              if @linkCache[ele.href]
                index = @linkCache[ele.href]
              else
                index = @links.length
                @links[index] = ele.href
                @linkCache[ele.href] = index
                @linkTitles[index] = ele.title if ele.title
              @output '['
              @atNoWS = yes
              after = @outputLater "][#{index}]"
            when 'IMG'
              skipChildren = yes
              break unless ele.src
              @output "![#{ele.alt}](#{ele.src})"
            when 'FRAME', 'IFRAME'
              skipChildren = yes
              try
                if ele.contentDocument?.documentElement
                  @process ele.contentDocument.documentElement
              catch err
                @thrown err, 'contentDocument'
            when 'TR'
              after = @p
            else
              @unhandled[ele.tagName] = null if @options.debug
      catch err
        @thrown err, ele.tagName
      unless skipChildren
        @process childNode for childNode in ele.childNodes
      after?()
    else if ele.nodeType is Node.TEXT_NODE
      if @inPre
        @output ele.nodeValue
      else if @inCode
        @output @inCodeProcess ele.nodeValue
      else
        @output @nonPreProcess ele.nodeValue

  # Attach `str` to the start of the current line.
  pushLeft: (str) ->
    old = @left
    @left += str
    if @atP
      @append str
    else
      @p()
    =>
      @left = old
      @atLeft = @atP = no
      @p()

  # Replace the left indent with `str`.
  replaceLeft: (str) ->
    unless @atLeft
      @append @left.replace /[ ]{4}$/, str
      @atLeft = @atNoWS = @atP = yes
    else if @last
      @last = @last.replace /[ ]{4}$/, str

  # Log the exception and the corresponding message if debug mode is enabled.
  thrown: (exception, message) ->
    @exceptions.push "#{message}: #{exception}" if @options.debug

  # Prepare the parser for a `ul` element.
  ul: ->
    old = @inOrderedList
    @inOrderedList = no
    => @inOrderedList = old

# html.md setup
# -------------

# Build the publicly exposed API.
md = window.md = (html, options) ->
  new HtmlParser(html, options).parse()

# Public constants
# ----------------

# Current version of html.md.
md.VERSION = '1.0.0'

# Public functions
# ----------------

# Run html.md in *noConflict* mode, returning the `md` variable to its
# previous owner.  
# Returns a reference to `md`.
md.noConflict = ->
  window.md = PREVIOUS_MD
  this