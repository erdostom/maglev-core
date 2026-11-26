# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Style/StringHashKeys
describe Maglev::Content::Label do
  describe '.normalize' do
    it 'squishes the value' do
      expect(described_class.normalize("  Hero \n of the   page ")).to eq 'Hero of the page'
    end

    it 'returns nil for blank values' do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize('   ')).to be_nil
    end

    it 'truncates long values' do
      expect(described_class.normalize('a' * 100).length).to eq described_class::MAX_LENGTH
    end
  end

  describe '.read' do
    it 'reads the label from a string keyed hash' do
      expect(described_class.read({ 'label' => ' Hero ' })).to eq 'Hero'
    end

    it 'reads the label from a symbol keyed hash' do
      expect(described_class.read({ label: 'Hero' })).to eq 'Hero'
    end

    it 'returns nil when there is no label' do
      expect(described_class.read({ 'id' => 'abc' })).to be_nil
      expect(described_class.read(nil)).to be_nil
    end
  end

  describe '.assign' do
    it 'stores the normalized label' do
      expect(described_class.assign({ 'id' => 'abc' }, ' Hero ')).to eq({ 'id' => 'abc', 'label' => 'Hero' })
    end

    it 'removes the key when the label is blank' do
      expect(described_class.assign({ 'id' => 'abc', 'label' => 'Hero' }, '')).to eq({ 'id' => 'abc' })
    end

    it "doesn't add any key to content without label" do
      expect(described_class.assign({ 'id' => 'abc' }, nil)).to eq({ 'id' => 'abc' })
    end
  end

  describe '.copy' do
    it 'copies the label of the source' do
      expect(described_class.copy({ 'label' => 'Old' }, { 'label' => 'New' })).to eq({ 'label' => 'New' })
    end

    it 'removes the label when the source has none' do
      expect(described_class.copy({ 'label' => 'Old' }, {})).to eq({})
    end
  end
end
# rubocop:enable Style/StringHashKeys
