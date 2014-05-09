#= require underscore.js
#= require jquery-1.11.1.js
#= require jquery-ui-1.10.4.custom.js
#= require jquery.qtip.js
#= require jquery_ujs

#= require_tree ./app

# TODO following is all old code ported from JS to CoffeeScript
# many of these should be rewritten and/or killed completely

window.custom_select_val = (select_elm, prompt_text) ->
  if val = prompt(prompt_text, "")
    option = $("<option/>")
    option.val val
    option.html val
    option.attr "selected", true
    option.appendTo select_elm
    true
  else
    false

window.shareSomething = (hash) ->
  $("#share").dialog "open"
  $("#share-something").hide()
  $("#map-container").hide()
  $("#group-details").hide()

$(document).on 'submit', '#share_picture_form', ->
  custom_select_val $("#album_id"), $("#share_picture_form").attr("data-album-prompt")  if $("#album_id").val() is "!"

unless location.hash is ""
  window.after_tab_setup = ->
    shareSomething location.hash.replace(/#/, "")

$ ->
  $('[data-qtip]').each ->
    $(this).qtip
      content:
        text: $(this).data('qtip')
