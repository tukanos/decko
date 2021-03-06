$.extend decko.editorContentFunctionMap,
    '.pointer-select': ->
      pointerContent @val()
    '.pointer-multiselect': ->
      pointerContent @val()
    '.pointer-radio-list': ->
      pointerContent @find('input:checked').val()
    '.pointer-list-ul': ->
      pointerContent @find('input').map( -> $(this).val() )
    '.pointer-checkbox-list': ->
      pointerContent @find('input:checked').map( -> $(this).val() )
    '.pointer-select-list': ->
      pointerContent @find('.pointer-select select').map( -> $(this).val() )
    '.pointer-mixed': ->
      element = '.pointer-checkbox-sublist input:checked,\
                .pointer-sublist-ul input'
      pointerContent @find(element).map( -> $(this).val() )
    # must happen after pointer-list-ul, I think
    '.perm-editor': -> permissionsContent this

decko.editorInitFunctionMap['.pointer-list-editor'] = ->
  @sortable({handle: '.handle', cancel: ''})
  decko.initPointerList @find('input')

$.extend decko,
  initPointerList: (input) ->
    optionsCard = input.closest('ul').data('options-card')
    optionsCard ||= input.closest('.pointer-list-editor').data('options-card')
    input.autocomplete {
      source: decko.prepUrl decko.rootPath + '/' + optionsCard +
          '.json?view=junction_name_complete'
    }

pointerContent = (vals) ->
  list = $.map $.makeArray(vals), (v) -> if v then '[[' + v + ']]'
  $.makeArray(list).join "\n"

permissionsContent = (ed) ->
  return '_left' if ed.find('#inherit').is(':checked')
  groups = ed.find('.perm-group input:checked').map( -> $(this).val() )
  indivs = ed.find('.perm-indiv input'        ).map( -> $(this).val() )
  pointerContent $.makeArray(groups).concat($.makeArray(indivs))
