function stripPrompts(s) {
  // replace any leading '$' plus any whitespace (\s*) with the empty string
  // options: (g = global, m = multiline)
  return s.replace(/^\$\s*/gm, '')
}

const languageSelector = '.language-console, .language-json, .language-yaml'

function handleClick(e) {
  e.preventDefault()
  e.stopPropagation()
  // get the button's parent's child language-console code block
  var code = $(e.delegateTarget).parent().find(languageSelector)
  // process the text. TODO #3140: be more robust about when not to strip
  // leading $. OK for now, since leading $ are illegal in both yaml and json.
  var copyString = stripPrompts(code.text())
  // get the global copy input field and set its value to the processed string
  var input = $('.tbn-code-copy-input').val(copyString)
  // select the input field
  input.select()
  // tell the browser to copy the currently selected text
  try {
    document.execCommand('copy')
  } catch (e) {}
  // un-focus the input element so Firefox doesn't try to scroll to it.
  input.blur()
}

$(function() {
  // create the hidden input
  $('body').append('<textarea class="tbn-code-copy-input"></textarea>')
  // actually hide it by moving it off screen
  $('.tbn-code-copy-input').css('position', 'absolute').css('left', '-9999px')
  // get all the 'console' code blocks and add a copy button immediately after them
  // NOTE: Firefox choked on parsing prettier's formatting for the next block, so...
  // prettier-ignore
  $(languageSelector)
    .parent()
    .before('<button class="tbn-btn-code-copy"><img class="tbn-btn-icon-copy" width="16" height="16" alt="Copy" src="/assets/copy_icon.svg" /></button>')
  // add handlers to all the new copy buttons
  var buttons = $('.tbn-btn-code-copy').on('click', handleClick)
})
