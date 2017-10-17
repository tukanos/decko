# ## What are Machines?
# {Machine} and {MachineInput} together implement a kind of observer pattern.
# {Machine} processes a collection of input cards to generate an output card
# (a {Set::Type::File} card by default). If one of the input cards is changed
# the output card will be updated.
#
# The classic example: A style card observes a collection of css and sccs card
# to generate a file card with a css file that contains the assembled
# compressed  css.
#
# ## Using Machines
# Include the Machine module in the card set that is supposed to produce the
# output card. If the output card should be automatically updated when a input
# card is changed the input card has to be in a set that includes the
# MachineInput module.
#
# The default machine:
#
#  -  uses its item cards as input cards or the card itself if there are no
# item cards;
#  -  can be changed by passing a block to collect_input_cards
#  -  takes the raw view of the input cards to generate the output;
#  -  can be changed by passing a block to machine_input (in the input card
# set)
#  -  stores the output as a .txt file in the '+machine output' card;
#  -  can be changed by passing a filetype and/or a block to
#     store_machine_output
#
#
# ## How does it work?
# Machine cards have a '+machine input' and a '+machine output' card. The
# '+machine input' card is a pointer to all input cards. Including the
# MachineInput module creates an 'on: save' event that runs the machines of
# all cards that are linked to that card via the +machine input pointer.
module MachineClassMethods
  attr_accessor :output_config

  def collect_input_cards &block
    define_method :engine_input, &block
  end

  def prepare_machine_input &block
    define_method :before_engine, &block
  end

  def machine_engine &block
    define_method :engine, &block
  end

  def store_machine_output args={}, &block
    output_config.merge!(args)
    return unless block_given?
    define_method :after_engine, &block
  end
end

class << self
  def included host_class
    host_class.extend(MachineClassMethods)
    host_class.output_config = { filetype: "txt" }

    # for compatibility with old migrations
    return unless  Codename[:machine_output]

    host_class.card_accessor :machine_output, type: :file
    host_class.card_accessor :machine_input, type: :pointer

    set_default_machine_behaviour host_class
    define_machine_views host_class
    define_machine_events host_class
  end

  def define_machine_events host_class
    event_suffix = host_class.name.tr ":", "_"
    event_name = "reset_machine_output_#{event_suffix}".to_sym
    host_class.event event_name, after: :expire_related, on: :save do
      reset_machine_output
    end
  end

  def define_machine_views host_class
    host_class.format do
      view :machine_output_url do |_args|
        machine_output_url
      end
    end
  end

  def set_default_machine_behaviour host_class
    set_default_input_collection_method host_class
    set_default_input_preparation_method host_class
    set_default_output_storage_method host_class
    host_class.machine_engine { |input| input }
  end

  def set_default_input_preparation_method host_class
    host_class.prepare_machine_input {}
  end

  def set_default_output_storage_method host_class
    host_class.store_machine_output do |output|
      filetype = host_class.output_config[:filetype]
      file = Tempfile.new [id.to_s, ".#{filetype}"]
      file.write output
      file.rewind
      Card::Auth.as_bot do
        p = machine_output_card
        p.file = file
        p.save!
      end
      file.close
      file.unlink
    end
  end

  def set_default_input_collection_method host_class
    host_class.collect_input_cards do
      # traverse through all levels of pointers and
      # collect all item cards as input
      items = [self]
      new_input = []
      already_extended = {} # avoid loops
      loop_limit = 5
      until items.empty?
        item = items.shift
        next if item.trash || already_extended[item.id].to_i > loop_limit
        if item.item_cards == [item] # no pointer card
          new_input << item
        else
          # item_cards instantiates non-existing cards
          # we don't want those
          items.insert(0, item.item_cards.reject(&:unknown?))
          items.flatten!

          new_input << item if item != self && item.known?
          already_extended[item] = already_extended[item].to_i + 1
        end
      end
      new_input
    end
  end
end

include_set Abstract::Lock

def run_machine joint="\n"
  before_engine
  output =
    input_item_cards.map do |input_card|
      run_engine input_card
    end.select(&:present?).join(joint)
  after_engine output
end

def run_engine input_card
  return if input_card.is_a? Card::Set::Type::Pointer
  if (cached = fetch_cache_card(input_card))
    return cached.content
  end

  output = engine input_from_card(input_card)
  cache_output_part input_card, output
  output
end

def input_from_card input_card
  if input_card.respond_to? :machine_input
    input_card.machine_input
  else
    input_card.format._render_raw
  end
end

def fetch_cache_card input_card, new=nil
  new &&= { type_id: PlainTextID }
  Card.fetch input_card.name, name, :machine_cache, new: new
end

def cache_output_part input_card, output
  Auth.as_bot do
    # save virtual cards first
    # otherwise the cache card will save it to get the left_id
    # and trigger the cache update again
    input_card.save! if input_card.new_card?

    cache_card = fetch_cache_card(input_card, true)
    cache_card.update_attributes! content: output
  end
end

def reset_machine_output
  Auth.as_bot do
    (moc = machine_output_card) && moc.real? && moc.delete!
    update_input_card
  end
end

def update_machine_output
  return unless ok?(:read)
  lock do
    update_input_card
    run_machine
  end
end

def make_machine_output_coded mod=:machines
  update_machine_output
  Auth.as_bot do
    output_codename =
      machine_output_card.name.parts.map do |part|
        Card[part].codename.to_s || Card[part].name.safe_key
      end.join "_"
    machine_output_card.update_attributes! codename: output_codename,
                                           storage_type: :coded,
                                           mod: mod
  end
end

def regenerate_machine_output
  return unless ok?(:read)
  lock do
    run_machine
  end
end

def update_input_card
  if Card::ActManager.running_act?
    input_card = attach_subcard! machine_input_card
    input_card.content = ""
    engine_input.each { |input| input_card << input }
  else
    machine_input_card.items = engine_input
  end
end

def input_item_cards
  machine_input_card.item_cards
end

def machine_output_url
  ensure_machine_output
  machine_output_card.file.url # (:default, timestamp: false)
  # to get rid of additional number in url
end

def machine_output_path
  ensure_machine_output
  machine_output_card.file.path
end

def ensure_machine_output
  output = fetch trait: :machine_output
  return if output && output.selected_content_action_id
  update_machine_output
end
