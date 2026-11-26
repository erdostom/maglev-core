# frozen_string_literal: true

module Maglev
  module Content
    module EnhancedValueConcern
      # name displayed in the editor UI (lists, page titles, toolbars):
      # the label given by the editor if any, otherwise the first text setting value.
      def label
        @label ||= custom_label.presence || preview_label
      end

      # value of the first text setting (or any setting able to provide a content label)
      def preview_label
        @preview_label ||= extract_enhanced_value_if do |setting_definition, value|
          setting_definition.content_label(value)
        end
      end

      def custom_label?
        custom_label.present?
      end

      def label?
        label.present?
      end

      def image
        @image ||= extract_enhanced_value_if do |setting_definition, value|
          setting_definition.content_image(value)
        end
      end

      def image?
        image.present?
      end

      private

      def extract_enhanced_value_if
        definition.settings.each do |setting_definition|
          value = settings.value_of(setting_definition.id)
          next if value.blank?

          enhanced_value = yield(setting_definition, value)
          return enhanced_value if enhanced_value.present?
        end
        nil
      end
    end
  end
end
