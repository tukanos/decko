$.extend decko,
  editorContentFunctionMap: {}
  editorInitFunctionMap: {
    '.date-editor': -> @datepicker { dateFormat: 'yy-mm-dd' }
    'textarea': -> $(this).autosize()
    '.file-upload': -> decko.upload_file(this)
    '.etherpad-textarea': ->
      $(this).closest('form')
      .find('.edit-submit-button')
      .attr('class', 'etherpad-submit-button')
  }

  addEditor: (selector, init, get_content) ->
    decko.editorContentFunctionMap[selector] = get_content
    decko.editorInitFunctionMap[selector] = init

jQuery.fn.extend {
  setContentFieldsFromMap: (map) ->
    map = decko.editorContentFunctionMap unless map?
    this_form = $(this)
    $.each map, (selector, fn) ->
      this_form.setContentFields(selector, fn)
  setContentFields: (selector, fn) ->
    $.each @find(selector), ->
      $(this).setContentField(fn)
  setContentField: (fn) ->
    field = @closest('.card-editor').find('.d0-card-content')
    init_val = field.val() # tinymce-jquery overrides val();
    # that's why we're not using it.
    new_val = fn.call this
    field.val new_val
    field.change() if init_val != new_val
}
