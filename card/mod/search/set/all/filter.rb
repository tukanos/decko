format :html do
  # @param data [Hash] the filter categories. The hash needs for every category
  #   a hash with a label and a input_field entry.
  def filter_form data={}, sort_input_field=nil, form_args={}
    render_haml :filter_form, categories: data,
                              sort_input_field: sort_input_field,
                              form_args: form_args
  end

  def view_template_path view, set_path= __FILE__
    super(view, set_path)
  end
end

