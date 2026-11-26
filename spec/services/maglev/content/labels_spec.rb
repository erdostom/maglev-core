# frozen_string_literal: true

require 'rails_helper'

# Optional editor labels of section / block instances (stored under the "label" key)
# rubocop:disable Style/StringHashKeys
describe 'Section and block labels' do
  let(:site) { create(:site) }
  let(:theme) { build(:theme) }
  let(:fetch_theme) { double('FetchTheme', call: theme) }
  let(:fetch_site) { double('FetchSite', call: site) }

  describe Maglev::Content::UpdateSectionService do
    let(:page) { create(:page) }
    let(:store) { fetch_sections_store('main', page.id) }
    let(:section_id) { store.sections.dig(0, 'id') }
    let(:service) { described_class.new(fetch_site: fetch_site, fetch_theme: fetch_theme) }

    def update(**args)
      service.call(store: store, section_id: section_id, content: { title: 'Hello!' }, **args)
    end

    it 'stores the label next to the settings' do
      update(label: '  Homepage   hero ')
      section = store.reload.sections.first
      expect(section['label']).to eq 'Homepage hero'
      expect(section.dig('settings', 0, 'value')).to eq 'Hello!'
    end

    it 'keeps the existing label when no label is submitted' do
      update(label: 'Homepage hero')
      update
      expect(store.reload.sections.first['label']).to eq 'Homepage hero'
    end

    it 'removes the key when the label is cleared' do
      update(label: 'Homepage hero')
      update(label: '')
      expect(store.reload.sections.first).not_to have_key('label')
    end

    it 'truncates a long label' do
      update(label: 'x' * 200)
      expect(store.reload.sections.first['label'].length).to eq Maglev::Content::Label::MAX_LENGTH
    end

    it 'leaves the content of unlabelled sections unchanged (no new key)' do
      before_keys = store.sections.map(&:keys)
      update
      expect(store.reload.sections.map(&:keys)).to eq before_keys
    end

    it 'stores the label per locale, like the rest of the content' do
      store.translate_in(:fr, :en)
      store.save!
      update(label: 'Hero EN')
      expect(store.reload.sections_translations.dig('en', 0, 'label')).to eq 'Hero EN'
      expect(store.sections_translations.dig('fr', 0)).not_to have_key('label')
    end

    context 'Given a site scoped section' do
      let(:page) { create(:page, sections: nil) }
      let(:store) { create(:sections_content_store, :header) }
      let!(:site_scoped_store) { create(:sections_content_store, :header, :site_scoped) }
      let(:section_id) { 'abc' }

      it 'stores the label in the site scoped store, shared by all the pages' do
        update(label: 'Main navigation')
        expect(fetch_sections_content('_site').first['label']).to eq 'Main navigation'
        expect(store.reload.sections.first).not_to have_key('label')
      end

      it 'exposes the label on every page using the section' do
        update(label: 'Main navigation')
        Maglev::I18n.with_locale(:en) do
          sections, = Maglev::FetchSectionsContentService.new(
            fetch_site: fetch_site, fetch_theme: fetch_theme, fetch_collection_items: double,
            fetch_static_pages: double(call: []), get_page_fullpath: double(call: '/')
          ).call(handle: 'header', page: nil)
          expect(sections.first['label']).to eq 'Main navigation'
        end
      end
    end
  end

  describe Maglev::Content::UpdateSectionBlockService do
    let(:page) { create(:page, sections: nil) }
    let(:store) { create(:sections_content_store, :with_navbar, page: page) }
    let(:service) { described_class.new(fetch_site: fetch_site, fetch_theme: fetch_theme) }

    before { theme.sections.find('navbar').site_scoped = false }

    def update(**args)
      # the menu item block has its own "label" setting: it must not be confused with the instance label
      service.call(store: store, section_id: 'abc', block_id: 'menu-item-0', content: { label: 'Home!' }, **args)
    end

    def block
      store.reload.find_section_block_by_id('abc', 'menu-item-0')
    end

    it 'stores the label of the block without touching a setting named "label"' do
      update(label: 'Main entry')
      expect(block['label']).to eq 'Main entry'
      expect(block['settings'].find { |setting| setting['id'] == 'label' }['value']).to eq 'Home!'
    end

    it 'removes the label when cleared' do
      update(label: 'Main entry')
      update(label: ' ')
      expect(block).not_to have_key('label')
    end

    it "doesn't add the key when no label is submitted" do
      update
      expect(block).not_to have_key('label')
    end
  end

  describe Maglev::CloneSection do
    let(:page) { create(:page, sections: nil, layout_id: 'sidebar') }
    let(:store) { create(:sections_content_store, :with_navbar, page: page, handle: 'main') }
    let(:definition) { theme.sections.find('navbar') }

    subject(:copy) { described_class.new.call(store: store, section_id: 'abc', theme: theme, layout_id: 'sidebar') }

    before do
      definition.site_scoped = false
      definition.singleton = false
    end

    it "doesn't add a label to an unlabelled section" do
      expect(copy).not_to have_key('label')
    end

    context 'Given labels on the section and its blocks' do
      before do
        store.sections.first['label'] = 'Main navigation'
        store.sections.first['blocks'].first['label'] = 'Home entry'
        store.save!
      end

      it 'marks the copy of the section label and keeps the block labels' do
        expect(copy['label']).to eq 'Main navigation (copy)'
        expect(copy['blocks'].first['label']).to eq 'Home entry'
        expect(store.reload.sections.first['label']).to eq 'Main navigation'
      end
    end
  end

  describe Maglev::ClonePage do
    let!(:page) { create(:page) }
    let(:service) { described_class.new(fetch_site: fetch_site) }

    before do
      store = fetch_sections_store('main', page.id)
      store.sections.first['label'] = 'Homepage hero'
      store.sections.last['blocks'] = [{ 'id' => 'b1', 'type' => 'item', 'label' => 'First', 'settings' => [] }]
      store.save!
    end

    it 'keeps the labels of the sections and blocks' do
      cloned_page = service.call(page: page)
      sections = fetch_sections_content('main', cloned_page.id)
      expect(sections.first['label']).to eq 'Homepage hero'
      expect(sections.last.dig('blocks', 0, 'label')).to eq 'First'
    end
  end

  describe Maglev::GetPageSectionNames do
    let(:page) { create(:page) }
    let(:service) { described_class.new(fetch_theme: fetch_theme) }

    subject { service.call(page: page) }

    it 'uses the type name when there is no label' do
      expect(subject.map { |item| item[:label] }).to eq %w[Jumbotron Showcase]
      expect(subject.map { |item| item[:custom_label] }).to eq [nil, nil]
    end

    context 'Given a labelled section' do
      before do
        store = fetch_sections_store('main', page.id)
        store.sections.first['label'] = 'Homepage hero'
        store.save!
      end

      it 'displays the label along with the type name' do
        expect(subject.first).to include(label: 'Homepage hero (Jumbotron)', custom_label: 'Homepage hero')
        expect(subject.last).to include(label: 'Showcase', custom_label: nil)
      end
    end

    context 'Given a labelled site scoped section' do
      # a site scoped section listed in a page scoped store
      let(:page) { create(:page, layout_id: 'sidebar', sections: [{ id: 'abc', type: 'navbar', settings: [] }]) }

      before do
        create(:sections_content_store, :header, :site_scoped).tap do |store|
          store.sections.first['label'] = 'Main navigation'
          store.save!
        end
      end

      it 'reads the label from the site scoped store' do
        expect(subject).to include(a_hash_including(id: 'abc', label: 'Main navigation (Navbar)'))
      end
    end

    context 'Given a mirrored section' do
      let(:source_page) { create(:page, path: 'source') }
      let(:source_store) { fetch_sections_store('main', source_page.id) }
      let(:page) { create(:page, sections: nil) }

      before do
        source_store.sections.first['label'] = 'Shared hero'
        source_store.save!
        create(:sections_content_store, :mirrored_section, page: page, section_id: source_store.sections.first['id'],
                                                           source_page: source_page, source_store: source_store)
      end

      it 'reads the label from the source section' do
        expect(subject).to include(a_hash_including(label: 'Shared hero (Jumbotron)'))
      end
    end
  end

  describe Maglev::PublishService do
    let(:page) { create(:page) }

    it 'publishes the labels with the content' do
      store = fetch_sections_store('main', page.id)
      store.sections.first['label'] = 'Homepage hero'
      store.save!

      described_class.call(theme: theme, site: site, page: page)

      published = Maglev::SectionsContentStore.published.find_by(handle: 'main', page: page)
      expect(published.sections.first['label']).to eq 'Homepage hero'
    end
  end
end
# rubocop:enable Style/StringHashKeys
