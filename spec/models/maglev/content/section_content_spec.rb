# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Style/StringHashKeys
RSpec.describe Maglev::Content::SectionContent do
  let(:theme) { build(:theme) }
  let(:page) { build(:page) }
  let(:store) { build(:sections_content_store, page: page) }
  let(:raw_section_content) { store.sections.first }
  let(:section_content) do
    described_class.build(theme: theme, store_handle: 'main', raw_section_content: raw_section_content)
  end

  context '#label' do
    it 'takes the first text setting value' do
      expect(section_content.label).to eq 'Hello world'
    end

    it "doesn't have a custom label" do
      expect(section_content.custom_label?).to eq false
      expect(section_content.display_name).to eq 'Jumbotron'
    end

    context 'Given the editors labelled the section' do
      let(:raw_section_content) { store.sections.first.merge('label' => 'Homepage hero') }

      it 'takes the custom label first' do
        expect(section_content.custom_label).to eq 'Homepage hero'
        expect(section_content.custom_label?).to eq true
        expect(section_content.label).to eq 'Homepage hero'
        expect(section_content.preview_label).to eq 'Hello world'
        expect(section_content.display_name).to eq 'Homepage hero'
        expect(section_content.type_name).to eq 'Jumbotron'
      end
    end

    context 'Given a section without any text value' do
      let(:raw_section_content) { store.sections.first.merge('settings' => []) }

      it 'has no label' do
        expect(section_content.label?).to eq false
        expect(section_content.display_name).to eq 'Jumbotron'
      end
    end
  end

  context '#type_name' do
    it 'returns the type name' do
      expect(section_content.type_name).to eq 'Jumbotron'
    end

    context 'i18n' do
      it 'returns the translated type name' do
        I18n.with_locale(:fr) do
          expect(section_content.type_name).to eq 'Jumbotron [FR]'
        end
      end
    end
  end

  context '#blocks' do
    let(:store) { build(:sections_content_store, :with_navbar, page: page) }

    it 'builds all the blocks of the section' do
      expect(section_content.blocks.count).to eq 4
    end

    describe 'a block' do
      it 'returns the block type' do
        expect(section_content.blocks.first.type).to eq 'menu_item'
      end

      it 'returns the block settings' do
        expect(section_content.blocks.first.settings.count).to eq 2
      end

      it 'returns the block settings values' do
        expect(section_content.blocks.first.settings.first.value).to eq 'Home'
      end

      it 'falls back to the first text setting value and the type name' do
        block = section_content.blocks.first
        expect(block.custom_label?).to eq false
        expect(block.label).to eq 'Home'
        expect(block.display_name).to eq 'Menu item'
      end

      context 'Given the editors labelled the block' do
        before { store.sections.first['blocks'].first['label'] = 'Main entry' }

        it 'takes the custom label first' do
          block = section_content.blocks.first
          expect(block.custom_label).to eq 'Main entry'
          expect(block.label).to eq 'Main entry'
          expect(block.display_name).to eq 'Main entry'
          expect(block.name).to eq 'Menu item'
        end
      end
    end
  end

  context '#root_blocks' do
    let(:store) { build(:sections_content_store, :with_navbar, page: page) }

    it 'returns only the blocks without a parent' do
      # the menu_item type is both root-eligible and accepted as a child of itself:
      # nested menu items must not be returned here, otherwise the editor tree
      # would render them twice (at the root and under their parent)
      expect(section_content.root_blocks.map(&:id)).to eq %w[menu-item-0 menu-item-1]
    end
  end

  context '#child_blocks_of' do
    let(:store) { build(:sections_content_store, :with_navbar, page: page) }

    it 'returns the direct children of the given block' do
      expect(section_content.child_blocks_of('menu-item-1').map(&:id)).to eq %w[menu-item-1-1 menu-item-1-2]
    end

    it 'returns an empty list for a block without children' do
      expect(section_content.child_blocks_of('menu-item-0')).to eq []
    end
  end
end
# rubocop:enable Style/StringHashKeys
