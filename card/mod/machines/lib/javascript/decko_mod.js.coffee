
window.decko ||= {} #needed to run w/o *head.  eg. jasmine

# $.extend decko,
# Can't get this to work yet.  Intent was to tighten up head tag.
#  initGoogleAnalytics: (key) ->
#    window._gaq.push ['_setAccount', key]
#    window._gaq.push ['_trackPageview']
#
#    initfunc = ()->
#      ga = document.createElement 'script'
#      ga.type = 'text/javascript'
#      ga.async = true
#      ga.src = `('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js'`
#      s = document.getElementsByTagName('script')[0]
#      s.parentNode.insertBefore ga, s
#  initfunc()

$(window).ready ->
  $('body').on 'click', '._stop_propagation', (event)->
    event.stopPropagation()

  # POINTERS
  #
  # add pointer item when clicking on "add another" button
  $('body').on 'click', '.pointer-item-add', (event)->
    decko.addPointerItem this
    event.preventDefault() # Prevent link from following its href

  # add pointer item when you hit enter in an item
  $('body').on 'keydown', '.pointer-item-text', (event)->
    if event.key == 'Enter'
      decko.addPointerItem this
      event.preventDefault() # was triggering extra item in unrelated pointer

  $('body').on 'keyup', '.pointer-item-text', (_event)->
    decko.updateAddItemButton this

  $('body').on 'click', '.pointer-item-delete', ->
    item = $(this).closest 'li'
    if item.closest('ul').find('.pointer-li').length > 1
      item.remove()
    else
      item.find('input').val ''

  $('body').on 'show.bs.tab', 'a.load[data-toggle=tab][data-url]', (e) ->
    tab_id = $(e.target).attr('href')
    url    = $(e.target).data('url')
    $(e.target).removeClass('load')
    $(tab_id).load(url)


  # toolbar mod
  $('body').on 'click', '.toolbar-pin.active', (e) ->
    e.preventDefault()
    $(this).blur()
    $('.toolbar-pin').removeClass('active').addClass('inactive')
    $.ajax '/*toolbar_pinned',
      type : 'PUT'
      data : 'card[content]=false'

  $('body').on 'click', '.toolbar-pin.inactive', (e) ->
    e.preventDefault()
    $(this).blur()
    $('.toolbar-pin').removeClass('inactive').addClass('active')
    $.ajax '/*toolbar_pinned',
      type : 'PUT'
      data : 'card[content]=true'

  # following mod
  $('body').on 'click', '.btn-item-delete', ->
    $(this).find('.glyphicon').addClass("glyphicon-hourglass").removeClass("glyphicon-remove")
  $('body').on 'click', '.btn-item-add', ->
    $(this).find('.glyphicon').addClass("glyphicon-hourglass").removeClass("glyphicon-plus")

  $('body').on 'mouseenter', '.btn-item-delete', ->
    $(this).find('.glyphicon').addClass("glyphicon-remove").removeClass("glyphicon-ok")
    $(this).addClass("btn-danger").removeClass("btn-primary")
  $('body').on 'mouseleave', '.btn-item-delete', ->
    $(this).find('.glyphicon').addClass("glyphicon-ok").removeClass("glyphicon-remove")
    $(this).addClass("btn-primary").removeClass("btn-danger")


  # modal mod
  $('body').on 'hidden.bs.modal', (event) ->
    modal_content = $(event.target).find('.modal-dialog > .modal-content')
    if $(event.target).attr('id') != 'modal-main-slot'
      slot = $( event.target ).slot()
      menu_slot = slot.find '.menu-slot:first'
      url  = decko.rootPath + '/~' + slot.data('card-id')
      params = { view: 'menu' }
      params['is_main'] = true if slot.isMain()
      modal_content.empty()
      $.ajax url, {
        type : 'GET'
        data: params
        success : (data) ->
          menu_slot.replaceWith data
      }

  # permissions mod
  $('body').on 'click', '.perm-vals input', ->
    $(this).slot().find('#inherit').attr('checked',false)

  $('body').on 'click', '.perm-editor #inherit', ->
    slot = $(this).slot()
    slot.find('.perm-group input:checked').attr('checked', false)
    slot.find('.perm-indiv input').val('')

  # rstar mod
  $('body').on 'click', '.rule-submit-button', ->
    f = $(this).closest('form')
    checked = f.find('.set-editor input:checked')
    if checked.val()
      if checked.attr('warning')
        confirm checked.attr('warning')
      else
        true
    else
      f.find('.set-editor').addClass('attention')
      $(this).notify 'To what Set does this Rule apply?'
      false

#  $('body').on 'click', '.rule-cancel-button', ->
#    $(this).closest('tr').find('.close-rule-link').click()


  $('body').on 'click', '.submit-modal', ->
    $(this).closest('.modal-content').find('form').submit()

  #decko_org mod (for now)
  $('body').on 'click', '.shade-view h1', ->
    toggleThis = $(this).slot().find('.shade-content').is ':hidden'
    decko.toggleShade $(this).closest('.pointer-list').find('.shade-content:visible').parent()
    if toggleThis
      decko.toggleShade $(this).slot()


  if firstShade = $('.shade-view h1')[0]
    $(firstShade).trigger 'click'


  # following not in use??

  $('body').on 'change', '.go-to-selected select', ->
    val = $(this).val()
    if val != ''
      window.location = decko.rootPath + escape( val )

  # performance log mod
  $('body').on 'click', '.open-slow-items', ->

    panel = $(this).closest('.panel-group')
    panel.find('.open-slow-items').removeClass('open-slow-items').addClass('close-slow-items')
    panel.find('.toggle-fast-items').text("show < 100ms")
    panel.find('.duration-ok').hide()
    panel.find('.panel-danger > .panel-collapse').collapse('show').find('a > span').addClass('show-fast-items')

  $('body').on 'click', '.close-slow-items', ->
    panel = $(this).closest('.panel-group')
    panel.find('.close-slow-items').removeClass('close-slow-items').addClass('open-slow-items')
    panel.find('.toggle-fast-items').text("hide < 100ms")
    panel.find('.panel-danger > .panel-collapse').collapse('hide').removeClass('show-fast-items')
    panel.find('.duration-ok').show()

  $('body').on 'click', '.toggle-fast-items', ->
    panel = $(this).closest('.panel-group')
    if $(this).text() == 'hide < 100ms'
      panel.find('.duration-ok').hide()
      $(this).text("show < 100ms")
    else
      panel.find('.duration-ok').show()
      $(this).text("hide < 100ms")

  $('body').on 'click', '.show-fast-items', (event) ->
    $(this).removeClass('show-fast-items')
    panel = $(this).closest('.panel-group')
    panel.find('.duration-ok').show()
    panel.find('.show-fast-items').removeClass('show-fast-items')
    panel.find('.panel-collapse').collapse('show')
    event.stopPropagation()

  $('.pointer-list-editor').each ->
    decko.updateAddItemButton this


$.extend decko,
  toggleShade: (shadeSlot) ->
    shadeSlot.find('.shade-content').slideToggle 1000
    shadeSlot.find('.glyphicon').toggleClass 'glyphicon-triangle-right glpyphicon-triangle-bottom'

  addPointerItem: (el) ->
    newInput = decko.nextPointerInput decko.lastPointerItem(el)
    newInput.val ''
    newInput.focus()
    decko.updateAddItemButton el
    decko.initPointerList newInput

  nextPointerInput: (lastItem)->
    lastInput = lastItem.find 'input'
    return lastInput if lastInput.val() == ''
    newItem = lastItem.clone()
    lastItem.after newItem
    newItem.find 'input'

  lastPointerItem: (el)->
    $(el).closest('.content-editor').find '.pointer-li:last'

  updateAddItemButton: (el)->
    button = $(el).closest('.content-editor').find '.pointer-item-add'
    disabled = decko.lastPointerItem(el).find('input').val() == ''
    button.prop 'disabled', disabled





