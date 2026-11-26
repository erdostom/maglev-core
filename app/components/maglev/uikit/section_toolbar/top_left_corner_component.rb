# frozen_string_literal: true

module Maglev
  module Uikit
    module SectionToolbar
      class TopLeftCornerComponent < Maglev::Uikit::BaseComponent
        attr_reader :label, :section_id

        def initialize(label:, section_id: nil)
          @label = label
          @section_id = section_id
        end

        def label_dom_id
          "section-toolbar-label-#{section_id}" if section_id
        end
      end
    end
  end
end
