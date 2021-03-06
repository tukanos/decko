class CardSpecLoader
  class << self
    def init
      require "spork"
      ENV["RAILS_ENV"] = "test"
      require "timecop"
    end

    def prefork
      Spork.prefork do
        unless ENV["RAILS_ROOT"]
          raise Card::Error, "No RAILS_ROOT given. Can't load environment."
        end
        require File.join ENV["RAILS_ROOT"], "config/environment"
        load_shared_examples
        require File.expand_path("../simplecov_helper.rb", __FILE__)
        require File.expand_path("../../../db/seed/test/seed.rb", __FILE__)

        # Requires supporting ruby files with custom matchers and macros, etc,
        # in spec/support/ and its subdirectories.
        Dir[File.join(Cardio.gem_root, "spec/support/matchers/*.rb")].each do |f|
          require f
        end
        yield if block_given?
      end
    end

    def each_run
      # This code will be run each time you run your specs.
      yield if block_given?
    end

    def rspec_config
      require "rspec/rails"

      @@joe_user_id = Card["joe_user"].id
      RSpec.configure do |config|
        config.include RSpec::Rails::Matchers::RoutingMatchers,
                       file_path: %r{\bspec/controllers/}
        config.include RSpecHtmlMatchers
        # format_index = ARGV.find_index {|arg| arg =~ /--format|-f/ }
        # formatter = format_index ? ARGV[ format_index + 1 ] : 'documentation'
        # config.default_formatter=formatter

        config.infer_spec_type_from_file_location!
        # config.include CustomMatchers
        # config.include ControllerMacros, type: :controllers

        # == Mock Framework
        # If you prefer to mock with mocha, flexmock or RR,
        # uncomment the appropriate symbol:
        # :mocha, :flexmock, :rr

        config.use_transactional_fixtures = true
        config.use_instantiated_fixtures  = false

        config.before(:each) do |example|
          Delayed::Worker.delay_jobs = false
          unless example.metadata[:as_bot]
            user_id =
              case example.metadata[:with_user]
              when String
                Card.fetch_id example.metadata[:with_user]
              when Card
                Card.id
              when Integer
                example.metadata[:with_user]
              else
                @@joe_user_id
              end
            Card::Auth.current_id = user_id
          end
          Card::Cache.restore
          Card::Env.reset
        end

        config.around(:example, :as_bot) do |example|
          Card::Auth.current_id = @@joe_user_id
          Card::Auth.as_bot do
            example.run
          end
        end

        config.after(:each) do
          Timecop.return
        end
        yield config if block_given?

        # # only needed for < 3.5.0
        # [:controller, :view, :request].each do |type|
        #   config.include ::Rails::Controller::Testing::TestProcess, :type => type
        #   config.include ::Rails::Controller::Testing::TemplateAssertions, :type => type
        #   config.include ::Rails::Controller::Testing::Integration, :type => type
        # end
      end
    end

    def helper
      require File.expand_path "../card_spec_helper.rb", __FILE__
      RSpec::Core::ExampleGroup.send :include, Card::SpecHelper
      Card.send :include, Card::SpecHelper::CardHelper
      Card.send :include, Card::SpecHelper::SetHelper
      Card.send :extend, Card::SpecHelper::CardHelper::ClassMethods
    end

    def load_shared_examples
      Card::Mod.dirs.each "spec/shared_examples" do |shared_ex_dir|
        Dir["#{shared_ex_dir}/**/*.rb"].sort.each { |f| require f }
      end
    end
  end
end
