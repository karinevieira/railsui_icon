require "nokogiri"

module RailsuiIcon
  class Icon
    VALID_VARIANTS = %i[solid outline mini micro].freeze

    attr_reader :name, :variant, :options, :custom_path

    def initialize(name:, variant: RailsuiIcon.configuration.default_variant, options: {}, custom_path: nil)
      @name = name
      @variant = validate_variant(variant)
      @options = options
      @custom_path = custom_path
    end

    def render
      return warning unless file_exists?

      doc = parse_file
      svg = doc.at_css "svg"

      return warning unless svg

      update_svg_attributes(svg)
      apply_default_class(svg)

      doc.to_html
    rescue StandardError => e
      Rails.logger.error "Failed to render icon: #{e.message}"
      warning
    end

    private

    def file_path
      return custom_path if custom_path && File.exist?(custom_path)

      RailsuiIcon.configuration.custom_icon_paths.each do |custom_path|
        path = File.join(custom_path, "#{variant}/#{name}.svg")
        return path if File.exist?(path)
      end

      File.join(RailsuiIcon.root, "lib/railsui_icon/icons/#{variant}/#{name}.svg")
    end

    def file_exists?
      File.exist?(file_path)
    end

    def parse_file
      Nokogiri::HTML::DocumentFragment.parse(File.read(file_path).force_encoding("UTF-8"))
    end

    def update_svg_attributes(svg)
      update_svg_options(svg)
    end

    def update_svg_options(svg)
      options.each do |key, value|
        svg[key.to_s.dasherize] = value
      end
    end

    def apply_default_class(svg)
      return if disable_default_class?

      default_classes = combine_classes_with_default_class
      svg[:class] = default_classes if default_classes.present?
    end

    def combine_classes_with_default_class
      default_class_list.concat(additional_class_list).uniq.join(" ")
    end

    def default_class_list
      default_class.split.compact
    end

    def additional_class_list
      (options[:class] || "").split.compact
    end

    def default_class
      config_default_class = RailsuiIcon.configuration.default_class
      config_default_class.is_a?(Hash) ? config_default_class[variant] : config_default_class.to_s
    end

    def disable_default_class?
      options.delete(:disable_default_class)
    end

    def validate_variant(provided_variant)
      unless VALID_VARIANTS.include?(provided_variant.to_sym)
        raise ArgumentError, "Invalid variant: #{provided_variant}. Valid variants are: #{VALID_VARIANTS.join(', ')}"
      end

      provided_variant.to_sym
    end

    def warning
      return unless Rails.env.development?

      <<-HTML.strip
        <script type="text/javascript">
        //<![CDATA[
        console.warn("Failed to find icon: #{name}")
        //]]>
        </script>
      HTML
    end

    class << self
      def render(**kwargs)
        new(**kwargs).render
      end
    end
  end
end
