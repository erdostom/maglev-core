# frozen_string_literal: true

module Maglev
  module Content
    # Optional, editor-facing label of a section or a block instance.
    #
    # It's stored in the raw content of the instance (next to its id, type and settings)
    # under the "label" key, so like the rest of the content, it is translated per locale.
    # A blank label is never stored: the key is removed instead, which means that
    # content without labels is persisted exactly as before.
    module Label
      KEY = 'label'
      MAX_LENGTH = 60

      module_function

      def normalize(value)
        value.to_s.squish.first(MAX_LENGTH).presence
      end

      def read(content)
        return if content.blank?

        normalize(content[KEY] || content[KEY.to_sym])
      end

      def assign(content, value)
        content.delete(KEY.to_sym) if content.respond_to?(:key?) && content.key?(KEY.to_sym)
        label = normalize(value)
        label ? content[KEY] = label : content.delete(KEY)
        content
      end

      def copy(target, source)
        assign(target, read(source))
      end
    end
  end
end
