
module ClassMethods
  # translates marks (and other inputs) into a Card
  #
  # @param cardish [Card, Card::Name, String, Symbol, Integer]
  # @return Card
  def cardish cardish
    if cardish.is_a? Card
      cardish
    else
      fetch cardish, new: {}
    end
  end

  # translates various inputs into either an id or a name.
  # @param parts [Array<Symbol, Integer, String, Card::Name, Card>] a mark or mark parts
  # @return [Integer or Card::Name]
  def id_or_name parts
    mark = parts.flatten
    mark = mark.first if mark.size <= 1
    id_from_mark(mark) || name_from_mark(mark)
  end

  def id_from_mark mark
    case mark
    when Integer then mark
    when Symbol  then Card::Codename.id! mark
    when String  then id_from_string mark
    end
  end

  # translates string identifiers into an id:
  #   - string id notation (eg "~75")
  #   - string codename notation (eg ":options")
  #
  # @param mark [String]
  # @return [Integer or nil]
  def id_from_string mark
    case mark
    when /^\~(\d+)$/  then  Regexp.last_match[1].to_i
    when /^\:(\w+)$/  then  Card::Codename.id! Regexp.last_match[1]
    end
  end

  def name_from_mark mark
    Card::Name[mark]
  end
end
