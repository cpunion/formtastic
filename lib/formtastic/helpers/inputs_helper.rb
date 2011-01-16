module Formtastic
  module Helpers
    module InputsHelper

      # Returns a suitable form input for the given +method+, using the database column information
      # and other factors (like the method name) to figure out what you probably want.
      #
      # Options:
      #
      # * :as - override the input type (eg force a :string to render as a :password field)
      # * :label - use something other than the method name as the label text, when false no label is printed
      # * :required - specify if the column is required (true) or not (false)
      # * :hint - provide some text to hint or help the user provide the correct information for a field
      # * :input_html - provide options that will be passed down to the generated input
      # * :wrapper_html - provide options that will be passed down to the li wrapper
      #
      # Input Types:
      #
      # Most inputs map directly to one of ActiveRecord's column types by default (eg string_input),
      # but there are a few special cases and some simplification (:integer, :float and :decimal
      # columns all map to a single numeric_input, for example).
      #
      # * :select (a select menu for associations) - default to association names
      # * :check_boxes (a set of check_box inputs for associations) - alternative to :select has_many and has_and_belongs_to_many associations
      # * :radio (a set of radio inputs for associations) - alternative to :select belongs_to associations
      # * :time_zone (a select menu with time zones)
      # * :password (a password input) - default for :string column types with 'password' in the method name
      # * :text (a textarea) - default for :text column types
      # * :date (a date select) - default for :date column types
      # * :datetime (a date and time select) - default for :datetime and :timestamp column types
      # * :time (a time select) - default for :time column types
      # * :boolean (a checkbox) - default for :boolean column types (you can also have booleans as :select and :radio)
      # * :string (a text field) - default for :string column types
      # * :numeric (a text field, like string) - default for :integer, :float and :decimal column types
      # * :email (an email input) - default for :string column types with 'email' as the method name.
      # * :url (a url input) - default for :string column types with 'url' as the method name.
      # * :phone (a tel input) - default for :string column types with 'phone' or 'fax' in the method name.
      # * :search (a search input) - default for :string column types with 'search' as the method name.
      # * :country (a select menu of country names) - requires a country_select plugin to be installed
      # * :email (an email input) - New in HTML5 - needs to be explicitly provided with :as => :email
      # * :url (a url input) - New in HTML5 - needs to be explicitly provided with :as => :url
      # * :phone (a tel input) - New in HTML5 - needs to be explicitly provided with :as => :phone
      # * :search (a search input) - New in HTML5 - needs to be explicity provided with :as => :search
      # * :country (a select menu of country names) - requires a country_select plugin to be installed
      # * :hidden (a hidden field) - creates a hidden field (added for compatibility)
      #
      # Example:
      #
      #   <% semantic_form_for @employee do |form| %>
      #     <% form.inputs do -%>
      #       <%= form.input :name, :label => "Full Name" %>
      #       <%= form.input :manager, :as => :radio %>
      #       <%= form.input :secret, :as => :password, :input_html => { :value => "xxxx" } %>
      #       <%= form.input :hired_at, :as => :date, :label => "Date Hired" %>
      #       <%= form.input :phone, :required => false, :hint => "Eg: +1 555 1234" %>
      #       <%= form.input :email %>
      #       <%= form.input :website, :as => :url, :hint => "You may wish to omit the http://" %>
      #     <% end %>
      #   <% end %>
      #
      def input(method, options = {})
        options = options.dup # Allow options to be shared without being tainted by Formtastic
        
        options[:required] = method_required?(method) unless options.key?(:required)
        options[:as]     ||= default_input_type(method, options)
    
        html_class = [ options[:as], (options[:required] ? :required : :optional) ]
        html_class << 'error' if has_errors?(method, options)
    
        wrapper_html = options.delete(:wrapper_html) || {}
        wrapper_html[:id]  ||= generate_html_id(method)
        wrapper_html[:class] = (html_class << wrapper_html[:class]).flatten.compact.join(' ')
    
        if options[:input_html] && options[:input_html][:id]
          options[:label_html] ||= {}
          options[:label_html][:for] ||= options[:input_html][:id]
        end
    
        input_parts = (custom_inline_order[options[:as]] || inline_order).dup
        input_parts = input_parts - [:errors, :hints] if options[:as] == :hidden
    
        list_item_content = input_parts.map do |type|
          send(:"inline_#{type}_for", method, options)
        end.compact.join("\n")
    
        return template.content_tag(:li, Formtastic::Util.html_safe(list_item_content), wrapper_html)
      end
    
      # Creates an input fieldset and ol tag wrapping for use around a set of inputs.  It can be
      # called either with a block (in which you can do the usual Rails form stuff, HTML, ERB, etc),
      # or with a list of fields.  These two examples are functionally equivalent:
      #
      #   # With a block:
      #   <% semantic_form_for @post do |form| %>
      #     <% form.inputs do %>
      #       <%= form.input :title %>
      #       <%= form.input :body %>
      #     <% end %>
      #   <% end %>
      #
      #   # With a list of fields:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #   <% end %>
      #
      #   # Output:
      #   <form ...>
      #     <fieldset class="inputs">
      #       <ol>
      #         <li class="string">...</li>
      #         <li class="text">...</li>
      #       </ol>
      #     </fieldset>
      #   </form>
      #
      # === Quick Forms
      #
      # When called without a block or a field list, an input is rendered for each column in the
      # model's database table, just like Rails' scaffolding.  You'll obviously want more control
      # than this in a production application, but it's a great way to get started, then come back
      # later to customise the form with a field list or a block of inputs.  Example:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs %>
      #   <% end %>
      #
      #   With a few arguments:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs "Post details", :title, :body %>
      #   <% end %>
      #
      # === Options
      #
      # All options (with the exception of :name/:title) are passed down to the fieldset as HTML
      # attributes (id, class, style, etc).  If provided, the :name/:title option is passed into a
      # legend tag inside the fieldset.
      #
      #   # With a block:
      #   <% semantic_form_for @post do |form| %>
      #     <% form.inputs :name => "Create a new post", :style => "border:1px;" do %>
      #       ...
      #     <% end %>
      #   <% end %>
      #
      #   # With a list (the options must come after the field list):
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body, :name => "Create a new post", :style => "border:1px;" %>
      #   <% end %>
      #
      #   # ...or the equivalent:
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs "Create a new post", :title, :body, :style => "border:1px;" %>
      #   <% end %>
      #
      # === It's basically a fieldset!
      #
      # Instead of hard-coding fieldsets & legends into your form to logically group related fields,
      # use inputs:
      #
      #   <% semantic_form_for @post do |f| %>
      #     <% f.inputs do %>
      #       <%= f.input :title %>
      #       <%= f.input :body %>
      #     <% end %>
      #     <% f.inputs :name => "Advanced", :id => "advanced" do %>
      #       <%= f.input :created_at %>
      #       <%= f.input :user_id, :label => "Author" %>
      #     <% end %>
      #     <% f.inputs "Extra" do %>
      #       <%= f.input :update_at %>
      #     <% end %>
      #   <% end %>
      #
      #   # Output:
      #   <form ...>
      #     <fieldset class="inputs">
      #       <ol>
      #         <li class="string">...</li>
      #         <li class="text">...</li>
      #       </ol>
      #     </fieldset>
      #     <fieldset class="inputs" id="advanced">
      #       <legend><span>Advanced</span></legend>
      #       <ol>
      #         <li class="datetime">...</li>
      #         <li class="select">...</li>
      #       </ol>
      #     </fieldset>
      #     <fieldset class="inputs">
      #       <legend><span>Extra</span></legend>
      #       <ol>
      #         <li class="datetime">...</li>
      #       </ol>
      #     </fieldset>
      #   </form>
      #
      # === Nested attributes
      #
      # As in Rails, you can use semantic_fields_for to nest attributes:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #
      #     <% form.semantic_fields_for :author, @bob do |author_form| %>
      #       <% author_form.inputs do %>
      #         <%= author_form.input :first_name, :required => false %>
      #         <%= author_form.input :last_name %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      #
      # But this does not look formtastic! This is equivalent:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #     <% form.inputs :for => [ :author, @bob ] do |author_form| %>
      #       <%= author_form.input :first_name, :required => false %>
      #       <%= author_form.input :last_name %>
      #     <% end %>
      #   <% end %>
      #
      # And if you don't need to give options to your input call, you could do it
      # in just one line:
      #
      #   <% semantic_form_for @post do |form| %>
      #     <%= form.inputs :title, :body %>
      #     <%= form.inputs :first_name, :last_name, :for => @bob %>
      #   <% end %>
      #
      # Just remember that calling inputs generates a new fieldset to wrap your
      # inputs. If you have two separate models, but, semantically, on the page
      # they are part of the same fieldset, you should use semantic_fields_for
      # instead (just as you would do with Rails' form builder).
      #
      def inputs(*args, &block)
        title = field_set_title_from_args(*args)
        html_options = args.extract_options!
        html_options[:class] ||= "inputs"
        html_options[:name] = title
        
        if html_options[:for] # Nested form
          inputs_for_nested_attributes(*(args << html_options), &block)
        elsif block_given?
          field_set_and_list_wrapping(*(args << html_options), &block)
        else
          if @object && args.empty?
            args  = association_columns(:belongs_to)
            args += content_columns
            args -= Formtastic::Builder::Base::RESERVED_COLUMNS
            args.compact!
          end
          legend = args.shift if args.first.is_a?(::String)
          contents = args.collect { |method| input(method.to_sym) }
          args.unshift(legend) if legend.present?
    
          field_set_and_list_wrapping(*((args << html_options) << contents))
        end
      end
      
      protected
      
      # Collects association columns (relation columns) for the current form object class.
      #
      def association_columns(*by_associations) #:nodoc:
        if @object.present? && @object.class.respond_to?(:reflections)
          @object.class.reflections.collect do |name, association_reflection|
            if by_associations.present?
              name if by_associations.include?(association_reflection.macro)
            else
              name
            end
          end.compact
        else
          []
        end
      end
      
      # Collects content columns (non-relation columns) for the current form object class.
      #
      def content_columns #:nodoc:
        model_name.constantize.content_columns.collect { |c| c.name.to_sym }.compact rescue []
      end
      
    end
  end
end