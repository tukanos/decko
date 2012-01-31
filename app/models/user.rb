require 'digest/sha1'

class User < ActiveRecord::Base
  #FIXME: THIS WHOLE MODEL SHOULD BE CALLED ACCOUNT

  # Virtual attribute for the unencrypted password
  attr_accessor :password, :name
  cattr_accessor :cache

  has_and_belongs_to_many :roles
  belongs_to :invite_sender, :class_name=>'Card', :foreign_key=>'invite_sender_id'
  has_many :invite_recipients, :class_name=>'Card', :foreign_key=>'invite_sender_id'

  validates_presence_of     :email, :if => :email_required?
  validates_format_of       :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i  , :if => :email_required?
  validates_length_of       :email, :within => 3..100,   :if => :email_required?
  validates_uniqueness_of   :email, :scope=>:login,      :if => :email_required?
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 5..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_presence_of     :invite_sender,              :if => :active?
#  validates_uniqueness_of   :salt, :allow_nil => true

  before_validation :downcase_email!
  before_save :encrypt_password
  after_save :reset_instance_cache

  class << self
    def admin() User.where(:card_id=>Card::WagbotID).first end

    # FIXME: args=params.  should be less coupled..
    def create_with_card(user_args, card_args, email_args={})
      #warn  "create with(#{user_args.inspect}, #{card_args.inspect}, #{email_args.inspect})"
      @card = (Hash===card_args ? Card.fetch_or_new(card_args[:name],{:type_id=>Card::UserID}.merge(card_args)) : card_args)
      #warn "create with >>>#{Card.user_card.name}"
      #warn "create with args= #{({:invite_sender=>Card.user_card, :status=>'active'}.merge(user_args)).inspect}"
      Card.as Card::WagbotID do
        @user = User.new({:invite_sender=>Card.user_card, :status=>'active'}.merge(user_args))
        #warn "user is #{@user.inspect}" unless @user.email
        @user.generate_password if @user.password.blank?
        @user.save_with_card(@card)
        @user.send_account_info(email_args) if @user.errors.empty? && !email_args.empty?
      end
      [@user, @card]
    end

    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    def authenticate(email, password)
      u = self.find_by_email(email.strip.downcase)
      u && u.authenticated?(password.strip) ? u : nil
    end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      Digest::SHA1.hexdigest("#{salt}--#{password}--")
    end

    def [](key)
      #warn (Rails.logger.info "Looking up USER[ #{key}]")

      key = case key
        when Integer
          card_id = key
          @card = Card[card_id]
          "##{key}"
        when Card;
          @card = key
          key.key
        else
          @card = (card_id = Wagn::Codename.code2id(key.to_s)) ?
                    Card[card_id] : @card = Card[key.to_s]
          key.to_s
        end

      usr = self.cache.read(key.to_s)
      return usr if usr

      
      card_id ||= @card && @card.id
      self.cache.write(key.to_s, usr)
      code = Wagn::Codename.codename(card_id.to_s) and self.cache.write(code, usr)
      usr
    end
  end

#~~~~~~~ Instance

  def reset_instance_cache
    self.class.cache.write(id.to_s, nil)
    self.class.cache.write(login, nil) if login
  end

  def save_with_card(card)
    #warn(Rails.logger.info "save with card #{card.inspect}, #{self.inspect}")
    User.transaction do
      card = card.refresh if card.frozen?
      card.save
      #warn "save with_card #{User.count}, #{card.id}, #{card.inspect}"
      self.card_id = card.id
      save
      #warn "save_with_card(#{card.name}) #{User.count}, #{inspect}, #{card.errors.empty?}, #{self.errors.empty?}"
      card.errors.each do |key,err|
        self.errors.add key,err
      end
      true
    end
  rescue
    Rails.logger.info "save with card failed.  #{card.inspect}"
  end

  def accept(card, email_args)
    #warn "\naccept user #{self.card_id}, #{card.inspect}, #{email_args.inspect}"
    Card.as(Card::WagbotID) do #what permissions does approver lack?  Should we check for them?
      card.type_id = Card::UserID # Invite Request -> User
      self.status='active'
      self.invite_sender = Card.user_card
      generate_password
      #warn "user accept #{inspect}, #{card.inspect}"
      r=save_with_card(card)
      #warn "accept save res: #{r.inspect}"; r
    end
    #card.save #hack to make it so last editor is current user.
    self.send_account_info(email_args) if self.errors.empty?
    #warn "errors? #{self.errors.empty?}"
  #rescue Exception => e
    #warn "exc: #{e.inspect}, #{e.backtrace*"\n"}"
  end

  def send_account_info(args)
    #return if args[:no_email]
    raise(Wagn::Oops, "subject is required") unless (args[:subject])
    raise(Wagn::Oops, "message is required") unless (args[:message])
    begin
      message = Mailer.account_info self, args[:subject], args[:message]
      message.deliver
    rescue Exception=>e
      warn "ACCOUNT INFO DELIVERY FAILED: \n #{args.inspect}\n   #{e.message}, #{e.backtrace*"\n"}"
    end
  end

  def active?()   status=='active'  end
  def blocked?()  status=='blocked' end
  def built_in?() status=='system'  end
  def pending?()  status=='pending' end
  def anonymous?() card_id == Card::AnonID end

  # blocked methods for legacy boolean status
  def blocked=(block)
    if block != '0'
      self.status = 'blocked'
    elsif !built_in?
      self.status = 'active'
    end
  end

  def authenticated?(password)
    crypted_password == encrypt(password) and active?
  end

  PW_CHARS = ['A'..'Z','a'..'z','0'..'9'].map(&:to_a).flatten

  def generate_password
    self.password_confirmation = self.password =
      9.times.map { PW_CHARS[rand*61] }*''
  end

  def to_s
    "#<#{self.class.name}:#{login.blank? ? email : login}}>"
  end

  def mocha_inspect
    to_s
  end

  #before validation
  def downcase_email!
    self.email=self.email.downcase if self.email
  end

  def card()
    @card && @card.id == card_id ? @card : @card = Card[card_id]
  end

  protected
  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  # before save
  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end

  def email_required?
    !built_in?
  end

  def password_required?
     !built_in? &&
     !pending?  &&
     #not_openid? &&
     (crypted_password.blank? or not password.blank?)
  end

end

