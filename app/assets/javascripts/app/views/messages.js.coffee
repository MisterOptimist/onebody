$(document).on 'keyup', 'form#message', (e) ->
  data = $('#message').serialize()
  $.post '/messages', data + '&preview=true'
