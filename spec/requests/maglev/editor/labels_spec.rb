# frozen_string_literal: true

require 'rails_helper'

# Optional labels given by the editors to sections and blocks
describe 'Maglev::Editor labels', type: :request do
  let(:theme) { build(:theme, :predefined_pages) }
  let!(:site) { Maglev::GenerateSite.call(theme: theme) }
  let!(:home_page) { Maglev::Page.home.first }
  let(:main_store) { fetch_sections_store('main', home_page.id) }
  let(:jumbotron) { main_store.find_section_by_type('jumbotron') }
  let(:showcase) { main_store.find_section_by_type('showcase') }
  let(:context_path) { "/maglev/editor/en/#{home_page.id}" }

  before do
    allow(Maglev.local_themes).to receive(:first).and_return(theme)
  end

  def label_section(section, label)
    section['label'] = label
    main_store.sections_translations_will_change!
    main_store.save!
  end

  describe 'editing a section' do
    it 'renders an empty label field with the type name as placeholder' do
      get "#{context_path}/sections/#{jumbotron['id']}/edit"
      expect(response.body).to have_selector("input[name='custom_label'][placeholder='Jumbotron'][maxlength='60']")
      expect(response.body).not_to have_selector("input[name='custom_label'][value]")
      expect(response.body).to have_selector('h2[data-editor-page-layout-title]', text: 'Jumbotron')
    end

    it 'renders the label in the field and in the title, with the type name' do
      label_section(jumbotron, 'Homepage hero')
      get "#{context_path}/sections/#{jumbotron['id']}/edit"
      expect(response.body).to have_selector("input[name='custom_label'][value='Homepage hero']")
      expect(response.body).to have_selector('h2[data-editor-page-layout-title]', text: /Homepage hero\s+Jumbotron/)
    end

    it 'saves the label and refreshes the title and the preview toolbar' do
      put "#{context_path}/sections/#{jumbotron['id']}",
          as: :turbo_stream,
          params: { custom_label: 'Homepage hero', section: { title: 'Hello world!' } }
      expect(response).to be_successful
      expect(main_store.reload.find_section_by_type('jumbotron')['label']).to eq 'Homepage hero'
      expect(response.body).to include('targets="[data-editor-page-layout-title]"')
      expect(response.body).to include("target=\"section-toolbar-label-#{jumbotron['id']}\"")
      expect(response.body.scan('Homepage hero').size).to eq 2
    end

    it 'saves the label of a section without any setting submitted' do
      put "#{context_path}/sections/#{jumbotron['id']}", as: :turbo_stream, params: { custom_label: 'Hero' }
      expect(response).to be_successful
      expect(main_store.reload.find_section_by_type('jumbotron')['label']).to eq 'Hero'
    end

    it 'removes the label' do
      label_section(jumbotron, 'Homepage hero')
      put "#{context_path}/sections/#{jumbotron['id']}", as: :turbo_stream, params: { custom_label: '' }
      expect(main_store.reload.find_section_by_type('jumbotron')).not_to have_key('label')
    end

    it 'keeps the label when the form is submitted by an older editor (no label field)' do
      label_section(jumbotron, 'Homepage hero')
      put "#{context_path}/sections/#{jumbotron['id']}", as: :turbo_stream, params: { section: { title: 'Hi' } }
      expect(main_store.reload.find_section_by_type('jumbotron')['label']).to eq 'Homepage hero'
    end
  end

  describe 'listing the sections' do
    it 'displays the label first, then the type name' do
      label_section(jumbotron, 'Homepage hero')
      get "#{context_path}/sections"
      expect(response).to be_successful
      expect(response.body).to include('Homepage hero')
      # the preview toolbar of the section
      expect(response.body).to have_selector("#section-toolbar-label-#{jumbotron['id']}", text: 'Homepage hero')
    end

    it 'falls back to the type name in the preview toolbar' do
      get "#{context_path}/sections"
      expect(response.body).to have_selector("#section-toolbar-label-#{jumbotron['id']}", text: 'Jumbotron')
    end
  end

  describe 'blocks' do
    let(:block) { showcase['blocks'].first }

    it 'renders the label field of a block' do
      get "#{context_path}/sections/#{showcase['id']}/blocks/#{block['id']}/edit"
      expect(response.body).to have_selector("input[name='custom_label'][placeholder='Showcase item']")
    end

    it 'saves the label of a block' do
      put "#{context_path}/sections/#{showcase['id']}/blocks/#{block['id']}",
          as: :turbo_stream,
          params: { custom_label: 'Flagship project', section_block: { title: 'Project' } }
      expect(response).to be_successful
      expect(main_store.reload.find_section_block_by_id(showcase['id'], block['id'])['label']).to eq 'Flagship project'
      expect(response.body).to include('Flagship project')
    end

    it 'lists a labelled block with its type name' do
      block['label'] = 'Flagship project'
      label_section(showcase, 'Our work')
      get "#{context_path}/sections/#{showcase['id']}/blocks"
      expect(response.body).to include('Flagship project')
      expect(response.body).to include('Showcase item') # type name shown as secondary text
      expect(response.body).to include('Our work') # back link to the section
    end
  end

  describe 'picking a link to a section of a page' do
    it 'lists the sections by label' do
      label_section(jumbotron, 'Homepage hero')
      get '/maglev/editor/link/edit',
          params: { link: { link_type: 'page', link_id: home_page.id }, input_name: 'link' },
          headers: { "Turbo-Frame": 'modal' }
      expect(response).to be_successful
      expect(response.body).to have_selector("option[value='#{jumbotron['id']}']", text: 'Homepage hero (Jumbotron)')
      expect(response.body).to have_selector("option[value='#{showcase['id']}']", text: 'Showcase')
    end
  end
end

describe 'Maglev labels on the public site', type: :request do
  let(:theme) { build(:theme, :predefined_pages) }
  let!(:site) { Maglev::GenerateSite.call(theme: theme) }
  let(:main_store) { fetch_sections_store('main', Maglev::Page.home.first.id) }

  it "doesn't render the labels" do
    main_store.find_section_by_type('jumbotron')['label'] = 'Secret editor label'
    main_store.sections_translations_will_change!
    main_store.save!

    get '/maglev/preview'
    expect(response).to be_successful
    expect(response.body).not_to include('Secret editor label')
  end
end
